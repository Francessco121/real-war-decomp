import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';

void main(List<String> args) {
  final argParser = ArgParser()..addOption('root');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  final buildDir = p.join(rw.dir, rw.config.buildDir);

  // Load base exe
  final String baseExeFilePath = p.join(projectDir, rw.config.exePath);
  final baseExeBytes = File(baseExeFilePath).readAsBytesSync();
  final baseExe = PeFile.fromList(baseExeBytes);

  // Load built exe
  final String builtExeFilePath = p.join(buildDir, 'RealWar.exe');
  final builtExeBytes = File(builtExeFilePath).readAsBytesSync();

  // Read mapping file
  final mapFile = File(p.join(buildDir, 'RealWar.map'));
  final mappingEntries = mapFile
      .readAsLinesSync()
      .skip(1)
      .map((l) => MappingEntry.fromLine(l))
      .toList();

  // Figure out first segment that's too big (if any)
  //
  // We can't do a meaningful diff for stuff that got shifted
  final segmentIdxsByName = {for (final (i, s) in rw.segments.indexed) s.name: i};
  final firstBigSegment = mappingEntries.firstWhereOrNull((e) {
    final segIdx = segmentIdxsByName[e.segmentName]!;
    
    if (segIdx >= rw.segments.length - 1) {
      return false;
    }

    final segSize = rw.segments[segIdx + 1].address - rw.segments[segIdx].address;

    return e.size > segSize;
  });

  var endOffset = firstBigSegment == null 
      ? baseExeBytes.length 
      : firstBigSegment.physicalAddress + firstBigSegment.size;
  endOffset = min(endOffset, min(baseExeBytes.length, builtExeBytes.length));
  
  // Diff!
  final nonMatchingEntries = <MappingEntry>{};
  int currentMapIdx = 0;
  MappingEntry currentEntry = mappingEntries.first;
  bool addedSeg = false;
  for (int i = 0; i < endOffset; i++) {
    if (baseExeBytes[i] != builtExeBytes[i]) {
      if (i > currentEntry.physicalAddress) {
        currentMapIdx = mappingEntries
            .indexWhere((e) => i < e.physicalAddress + e.size, currentMapIdx);
        currentEntry = mappingEntries[currentMapIdx];
        addedSeg = false;
      }

      if (!addedSeg) {
        addedSeg = true;
        nonMatchingEntries.add(currentEntry);
      }
    }
  }

  // Display
  if (nonMatchingEntries.isEmpty && 
      firstBigSegment == null && 
      baseExeBytes.length == builtExeBytes.length) {
    print('All bytes match!');
    return;
  }

  if (firstBigSegment != null) {
    print(
      'WARN: Segment ${firstBigSegment.segmentName} is too big! '
      'Bytes after this segment are shifted and won\'t be diffed.');
  }

  print('Differing segments:');
  for (final entry in nonMatchingEntries) {
    print('${entry.segmentName} (${entry.segmentType})');

    if (entry.segmentType == 'c') {
      final differingFuncs = _findDifferingFunctions(
          File(p.join(rw.dir, entry.srcName)),
          baseExe,
          baseExeBytes,
          rw,
          rw.segments[segmentIdxsByName[entry.segmentName]!].address);
      
      for (final func in differingFuncs) {
        print('  $func');
      }
    }
  }
}

class MappingEntry {
  final int physicalAddress;
  final int size;
  final String segmentName;
  final String segmentType;
  final String srcName;

  MappingEntry(this.physicalAddress, this.size, this.segmentName,
      this.segmentType, this.srcName);

  factory MappingEntry.fromLine(String line) {
    final parts = line
        .split(' ')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return MappingEntry(
        int.parse(parts[0]), int.parse(parts[1]), parts[3], parts[2], parts[4]);
  }
}

List<String> _findDifferingFunctions(File objFile, PeFile baseExe, Uint8List baseExeBytes, RealWarYaml rw, int segmentVA) {
  final funcs = <String>[];
  
  final objBytes = objFile.readAsBytesSync();
  final coff = CoffFile.fromList(objBytes);
  final imageBase = baseExe.optionalHeader!.windows!.imageBase;

  int sectionVA = segmentVA;
  for (final (i, section) in coff.sections.indexed) {
    if (section.header.name != '.text' || !section.header.flags.lnkComdat) {
      continue;
    }

    relocateSection(
        coff, 
        section, 
        Uint8List.sublistView(
          objBytes, 
          section.header.pointerToRawData, 
          section.header.pointerToRawData + section.header.sizeOfRawData), 
        targetVirtualAddress: sectionVA, 
        symbolLookup: (s) => rw.lookupSymbolOrString(unmangle(s)));

    final funcSymbol = coff.symbolTable!.values
        .firstWhere((s) => s.type == 0x20 && s.value == 0 && s.sectionNumber == (i + 1));
    final funcName = unmangle(funcSymbol.name.shortName
        ?? coff.stringTable!.strings[funcSymbol.name.offset!]!);
    
    final funcVA = rw.symbols[funcName]!;
    final funcPA = (funcVA - imageBase - rw.exe.textVirtualAddress) + rw.exe.textFileOffset;
    final funcObjPA = section.header.pointerToRawData;

    final sectionSize = section.header.sizeOfRawData;
    final remainingSize = baseExeBytes.length - funcPA;

    if (remainingSize < sectionSize) {
      funcs.add(funcName);
    } else {
      for (int j = 0; j < sectionSize; j++) {
        if (objBytes[funcObjPA + j] != baseExeBytes[funcPA + j]) {
          funcs.add(funcName);
          break;
        }
      }
    }

    sectionVA += sectionSize;
  }

  return funcs;
}
