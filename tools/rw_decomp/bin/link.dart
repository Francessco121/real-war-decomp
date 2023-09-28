import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';

/*
- using rw.yaml segment mapping and files in bin/ and build/obj/, link an actual exe
*/

class LinkException implements Exception {
  final String message;

  LinkException(this.message);
}

void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root')
      ..addFlag('no-success-message', defaultsTo: false, 
          help: 'Don\'t write to stdout on success.')
      ..addFlag('non-matching', defaultsTo: false);

  final argResult = argParser.parse(args);
  final bool noSuccessMessage = argResult['no-success-message'];
  final bool nonMatching = argResult['non-matching'];
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Parse base exe
  final String baseExeFilePath = p.join(projectDir, rw.config.exePath);
  final baseExeBytes = File(baseExeFilePath).readAsBytesSync();
  final baseExe = PeFile.fromList(baseExeBytes);
  
  // Setup
  final String binDirPath = p.join(projectDir, rw.config.binDir);
  final String buildDirPath = p.join(projectDir, rw.config.buildDir);

  Directory(buildDirPath).createSync();

  // Link
  try {
    final segmentMapping = <(int, String)>[];
    final objCache = ObjectFileCache();

    final builder = BytesBuilder(copy: false);
    final imageBase = rw.exe.imageBase;

    final nonMatchingTextBuilder = BytesBuilder(copy: false);
    final nonMatchingBaseVA = _sectionAlign(_getLastSectionEndVA(baseExe), baseExe);

    Section? section; // start in header
    int nextSectionIndex = 0; 
    Section? nextSection = baseExe.sections[nextSectionIndex];
    for (int segIdx = 0; segIdx < rw.segments.length; segIdx++) {
      final segment = rw.segments[segIdx];

      if (segment.type == 'bss') {
        // uninitialized data doesn't have a physical form
        continue;
      }

      // Have we entered a new section?
      while (nextSection != null && segment.address >= (nextSection.header.virtualAddress + imageBase)) {
        section = nextSection;
        nextSectionIndex++;
        nextSection = (nextSectionIndex) == baseExe.sections.length ? null : baseExe.sections[nextSectionIndex];
      }

      final currentFilePointer = builder.length;

      // Determine where we *want* to put this segment, where it actually goes might differ
      // due to size differences from previous segments
      //
      // If the expected file position is behind where we are, then do nothing. The executable
      // was shifted up from a larger previous segment and was already warned.
      final expectedSegmentFilePointer = section == null
          ? segment.address - imageBase
          : (segment.address - imageBase - section.header.virtualAddress) + section.header.pointerToRawData;
      final expectedSegmentByteSize = segIdx < (rw.segments.length - 1)
          ? rw.segments[segIdx + 1].address - segment.address
          : null;

      if (currentFilePointer < expectedSegmentFilePointer) {
        // There's a gap between the last segment and where this segment should go,
        // pad with NOPs...
        final padding = expectedSegmentFilePointer - currentFilePointer;
        if (segIdx > 0) {
          print('WARN: $padding byte gap between "${rw.segments[segIdx - 1].name}" and "${segment.name}".');
        } else {
          print('WARN: $padding byte gap between start of image and "${segment.name}".');
        }
        for (int i = 0; i < padding; i++) {
          builder.addByte(0x90); // 0x90 = x86 1-byte NOP
        }
      }

      // Handle segment
      final String segmentFilePath;

      switch (segment.type) {
        case 'bin':
        case 'thunks':
        case 'extfuncs':
          // .bin
          segmentFilePath = p.join(binDirPath, '${segment.name}.bin');

          // Link bin files as is
          final binFile = File(segmentFilePath);
          if (!binFile.existsSync()) {
            throw LinkException('File doesn\'t exist: ${binFile.path}');
          }

          builder.add(binFile.readAsBytesSync());
        case 'c':
        case 'data':
        case 'rdata':
          // .obj (.text, .data, .rdata)
          // Load object file
          final objFilePath = p.join(buildDirPath, 'obj', '${segment.name}.obj');
          final (coff, objBytes) = objCache.get(objFilePath);

          final sectionName = switch (segment.type) {
            'c' => '.text',
            'data' => '.data',
            'rdata' => '.rdata',
            _ => throw UnimplementedError()
          };

          // If we're linking non-matching COMDATs, then calculate the expected size of each function first
          //
          // Any functions that are too big will be moved into the non-matching .text section
          final functionVAs = <int>[];
          final functionSizes = <int>[];
          final functionNames = <String>[];
          if (nonMatching && sectionName == '.text') {
            for (final (i, coffSection) in coff.sections.indexed) {
              if (coffSection.header.name != '.text') {
                continue;
              }

              if (!coffSection.header.flags.lnkComdat) {
                throw LinkException(
                    'All .text sections must be COMDATs to link a non-matching executable. '
                    'Section number ${i + 1} in $objFilePath is not a .text COMDAT.');
              }

              final funcName = _findFunctionComDatSymbolName(coff, i + 1);
              if (funcName == null) {
                throw LinkException(
                    'Could not find function name for .text COMDAT (section number ${i + 1}) in $objFilePath.');
              }

              functionNames.add(funcName);

              final funcVA = rw.symbols[unmangle(funcName)];
              if (funcVA == null) {
                throw LinkException(
                    'Could not find function address for .text COMDAT (section number ${i + 1}) in $objFilePath.');
              }

              functionVAs.add(funcVA);
            }

            for (int i = 0; i < functionVAs.length; i++) {
              final funcEnd = i < (functionVAs.length - 1)
                  ? functionVAs[i + 1]
                  : segment.address + expectedSegmentByteSize!;
              
              functionSizes.add(funcEnd - functionVAs[i]);
            }
          }

          // Relocate sections and concatenate bytes (link each section in order as they appear)
          try {
            int sectionVirtualAddress = segment.address;
            for (final (funcIdx, (coffSection, secBytes)) in _iterateSections(coff, objBytes, sectionName).indexed) {
              if (nonMatching && coffSection.header.name == '.text') {
                // Non-matching build for .text segment
                final expectedFuncVA = functionVAs[funcIdx];
                final expectedFuncSize = functionSizes[funcIdx];

                if (sectionVirtualAddress != expectedFuncVA) {
                  throw LinkException(
                      'Couldn\'t link function ${functionNames[funcIdx]} at expected address 0x${expectedFuncVA.toRadixString(16)}. '
                      'Functions in the segment $objFilePath may be out of order. Non-matching builds require functions to be '
                      'in the same order as they appear in the base executable.');
                }

                if (secBytes.lengthInBytes > expectedFuncSize) {
                  // Function is too big, move it into the non-matching .text section
                  final movedVA = nonMatchingBaseVA + imageBase + nonMatchingTextBuilder.length;
                  relocateSection(coff, coffSection, secBytes, 
                      targetVirtualAddress: movedVA, 
                      symbolLookup: (sym) => rw.lookupSymbolOrString(unmangle(sym)));
                  
                  nonMatchingTextBuilder.add(secBytes);

                  // Patch in jump to the moved function + nop padding in its place
                  final jumpInst = ByteData(5);
                  final operand = movedVA - sectionVirtualAddress - 5;
                  jumpInst.setUint8(0, 0xE9);
                  jumpInst.setUint32(1, operand, Endian.little);

                  builder.add(jumpInst.buffer.asUint8List());
                  builder.addByte(0xC3); // unreachable RET to help disassemblers detect the function end
                  for (int i = 0; i < (expectedFuncSize - 6); i++) {
                    builder.addByte(0x90); // 0x90 = x86 1-byte NOP
                  }
                } else {
                  relocateSection(coff, coffSection, secBytes, 
                      targetVirtualAddress: sectionVirtualAddress, 
                      symbolLookup: (sym) => rw.lookupSymbolOrString(unmangle(sym)));
                  
                  builder.add(secBytes);

                  if (secBytes.lengthInBytes < expectedFuncSize) {
                    // Function is too small, pad with nops
                    for (int i = 0; i < (expectedFuncSize - secBytes.lengthInBytes); i++) {
                      builder.addByte(0x90); // 0x90 = x86 1-byte NOP
                    }
                  }
                }

                sectionVirtualAddress += expectedFuncSize;
              } else {
                // Normal build or not a .text segment
                relocateSection(coff, coffSection, secBytes, 
                    targetVirtualAddress: sectionVirtualAddress, 
                    symbolLookup: (sym) => rw.lookupSymbolOrString(unmangle(sym)));

                builder.add(secBytes);
                
                sectionVirtualAddress += coffSection.header.sizeOfRawData;
              }
            }
          } on RelocationException catch (ex) {
            throw LinkException('${p.relative(objFilePath, from: projectDir)}: ${ex.message}');
          }

          segmentFilePath = objFilePath;
        default:
          throw UnimplementedError('Unknown segment type: ${segment.type}');
      }

      // Verify segment size was as expected
      final bytesWritten = builder.length - currentFilePointer;

      if (expectedSegmentByteSize != null && bytesWritten != expectedSegmentByteSize) {
        print('WARN: Segment "${segment.name}" byte size ($bytesWritten) doesn\'t match expected size ($expectedSegmentByteSize).');
      }

      // Add mapping entry
      segmentMapping.add((currentFilePointer, p.relative(p.normalize(segmentFilePath), from: projectDir)));
    }

    // Build exe bytes
    final nonMatchingTextSize = nonMatchingTextBuilder.length;
    if (nonMatching) {
      builder.add(nonMatchingTextBuilder.takeBytes());

      final expectedTextEnd = _fileAlign(builder.length, baseExe);
      final padding = expectedTextEnd - builder.length;
      builder.add(Uint8List(padding));
    }

    final exeBytes = builder.takeBytes();

    if (nonMatching && nonMatchingTextSize > 0) {
      // If we have a non-matching .text section, add the section header and patch the
      // section count and image size
      final textHeader = SectionHeader(
        name: '.text',
        virtualSize: nonMatchingTextSize,
        virtualAddress: nonMatchingBaseVA,
        sizeOfRawData: nonMatchingTextSize,
        pointerToRawData: baseExeBytes.lengthInBytes,
        pointerToRelocations: 0,
        pointerToLineNumbers: 0,
        numberOfRelocations: 0,
        numberOfLineNumbers: 0,
        flags: SectionFlags(
          SectionFlagValues.cntCode | 
          SectionFlagValues.memExecute | 
          SectionFlagValues.memRead),
      );

      exeBytes.setRange(
          0x00000278, 
          0x00000278 + SectionHeader.byteSize, 
          textHeader.toBytes());
      
      final newDataLength = nonMatchingTextSize;
      final exeData = ByteData.sublistView(exeBytes);
      exeData
        ..setUint16(0x000000E6, baseExe.coffHeader.numberOfSections + 1, Endian.little)
        ..setUint32(0x00000130, 
            baseExe.optionalHeader!.windows!.sizeOfImage + _sectionAlign(newDataLength, baseExe), 
            Endian.little);
    }

    // Write exe file
    final String outExeFilePath = p.join(projectDir, rw.config.buildDir, 
        nonMatching ? 'RealWarNonMatching.exe' : 'RealWar.exe');
    File(outExeFilePath).writeAsBytesSync(exeBytes);

    // Write mapping file
    final String outMapFilePath = p.join(projectDir, rw.config.buildDir, 
        nonMatching ? 'RealWarNonMatching.map' : 'RealWar.map');
    final strBuffer = StringBuffer();
    segmentMapping.sort((a, b) => a.$1.compareTo(b.$1));
    for (final entry in segmentMapping) {
      strBuffer.write('0x${entry.$1.toRadixString(16)}:'.padLeft(10));
      strBuffer.writeln(' ${entry.$2}');
    }
    File(outMapFilePath).writeAsStringSync(strBuffer.toString());

    if (!noSuccessMessage) {
      print('Linked: ${p.relative(outExeFilePath, from: projectDir)}.');
    }
  } on LinkException catch (ex) {
    print('ERR: ${ex.message}');
    exit(-1);
  }
}

class ObjectFileCache {
  final Map<String, (CoffFile, Uint8List)> _cache = {};

  /// Gets or loads and caches the object file at the given [path].
  /// 
  /// Returns the COFF descriptor and raw file bytes.
  (CoffFile, Uint8List) get(String path) {
    final cached = _cache[path];
    if (cached != null) {
      return cached;
    }

    final objFile = File(path);
    if (!objFile.existsSync()) {
      throw LinkException('File doesn\'t exist: ${objFile.path}');
    }

    final objBytes = objFile.readAsBytesSync();
    final coff = CoffFile.fromList(objBytes);

    _cache[path] = (coff, objBytes);
    
    return (coff, objBytes);
  }
}

Iterable<(Section section, Uint8List)> _iterateSections(CoffFile coff, Uint8List objBytes, String sectionName) sync* {
  for (final section in coff.sections) {
    if (section.header.name == sectionName) {
      final filePtr = section.header.pointerToRawData;
      final bytes = Uint8List.sublistView(objBytes, filePtr, filePtr + section.header.sizeOfRawData);

      yield (section, bytes);
    }
  }
}

String? _findFunctionComDatSymbolName(CoffFile coff, int sectionNumber) {
  for (final symbol in coff.symbolTable!.values) {
    // Type 0x20 == function
    if (symbol.sectionNumber == sectionNumber && symbol.type == 0x20 && symbol.value == 0) {
      return symbol.name.shortName ?? coff.stringTable!.strings[symbol.name.offset!];
    }
  }

  return null;
}

int _getLastSectionEndVA(PeFile exe) {
  final lastSec = exe.sections.last.header;

  return lastSec.virtualAddress + lastSec.virtualSize;
}

int _sectionAlign(int value, PeFile exe) {
  final sectionAlignment = exe.optionalHeader!.windows!.sectionAlignment;
  
  return (value / sectionAlignment).ceil() * sectionAlignment;
}

int _fileAlign(int value, PeFile exe) {
  final fileAlignment = exe.optionalHeader!.windows!.fileAlignment;
  
  return (value / fileAlignment).ceil() * fileAlignment;
}
