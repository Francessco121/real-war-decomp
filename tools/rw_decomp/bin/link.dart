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
          help: 'Don\'t write to stdout on success.');

  final argResult = argParser.parse(args);
  final bool noSuccessMessage = argResult['no-success-message'];
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Parse base exe
  final String baseExeFilePath = p.join(projectDir, rw.config.exePath);
  final baseExe = PeFile.fromList(File(baseExeFilePath).readAsBytesSync());
  
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

    Section? section; // start in header
    int nextSectionIndex = 0; 
    Section? nextSection = baseExe.sections[nextSectionIndex];
    for (int i = 0; i < rw.segments.length; i++) {
      final segment = rw.segments[i];

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
      final expectedSegmentByteSize = i < (rw.segments.length - 1)
          ? rw.segments[i + 1].address - segment.address
          : null;

      if (currentFilePointer < expectedSegmentFilePointer) {
        // There's a gap between the last segment and where this segment should go,
        // pad with NOPs...
        final padding = expectedSegmentFilePointer - currentFilePointer;
        if (i > 0) {
          print('WARN: $padding byte gap between "${rw.segments[i - 1].name}" and "${segment.name}".');
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

          // Relocate sections and concatenate bytes (link each section in order as they appear)
          final sectionName = switch (segment.type) {
            'c' => '.text',
            'data' => '.data',
            'rdata' => '.rdata',
            _ => throw UnimplementedError()
          };

          try {
            int sectionVirtualAddress = segment.address;
            for (final (section, secBytes) in _iterateSections(coff, objBytes, sectionName)) {
              relocateSection(coff, section, secBytes, 
                  targetVirtualAddress: sectionVirtualAddress, 
                  symbolLookup: (sym) => rw.lookupSymbolOrString(unmangle(sym)));
              
              builder.add(secBytes);
              
              sectionVirtualAddress += section.header.sizeOfRawData;
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

    // Write exe file
    final String outExeFilePath = p.join(projectDir, rw.config.buildDir, 'RealWar.exe');
    File(outExeFilePath).writeAsBytesSync(builder.takeBytes());

    // Write mapping file
    final String outMapFilePath = p.join(projectDir, rw.config.buildDir, 'RealWar.map');
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
