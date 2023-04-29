import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/rw_yaml.dart';

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
      ..addFlag('dump-relocated-code', defaultsTo: false, 
          help: 'Write relocated code to .relocated files next to object files.');

  final argResult = argParser.parse(args);
  final bool noSuccessMessage = argResult['no-success-message'];
  final bool dumpRelocatedCode = argResult['dump-relocated-code'];
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
    // This lint is just wrong???
    // ignore: prefer_collection_literals
    final mapping = LinkedHashMap<int, String>();
    final builder = BytesBuilder();
    final imageBase = rw.exe.imageBase;

    int currentFilePointer = 0;
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

      // Determine where we *want* to put this segment, where it actually goes might differ
      // due to size differences from previous segments
      final segmentFilePointer = section == null
          ? segment.address - imageBase
          : (segment.address - imageBase - section.header.virtualAddress) + section.header.pointerToRawData;
      final segmentByteSize = i < (rw.segments.length - 1)
          ? rw.segments[i + 1].address - segment.address
          : null;

      if (currentFilePointer < segmentFilePointer) {
        // There's a gap between the last segment and where this segment should go,
        // pad with NOPs...
        final padding = segmentFilePointer - currentFilePointer;
        if (i > 0) {
          print('WARN: $padding byte gap between "${rw.segments[i - 1].name}" and "${segment.name}".');
        } else {
          print('WARN: $padding byte gap between start of image and "${segment.name}".');
        }
        for (int i = 0; i < padding; i++) {
          builder.addByte(0x90); // 0x90 = x86 1-byte NOP
        }
      }

      // Get bytes to write
      final String segmentFilePath;
      final Uint8List bytes;
      if (segment.type == 'bin') {
        // .bin
        final binFile = File(p.join(binDirPath, '${segment.name}.bin'));
        if (!binFile.existsSync()) {
          throw LinkException('File doesn\'t exist: ${binFile.path}');
        }
        bytes = binFile.readAsBytesSync();
        segmentFilePath = binFile.path;
      } else if (segment.type == 'c') {
        // .obj (.text)
        final objFile = File(p.join(buildDirPath, 'obj', '${segment.name}.obj'));
        if (!objFile.existsSync()) {
          throw LinkException('File doesn\'t exist: ${objFile.path}');
        }
        try {
          bytes = _getRelocatedTextFromObject(objFile.readAsBytesSync(), rw, segment.address);
        } on RelocationException catch (ex) {
          throw LinkException('${p.relative(objFile.path, from: projectDir)}: ${ex.message}');
        }
        segmentFilePath = objFile.path;

        if (dumpRelocatedCode) {
          File(p.join(buildDirPath, 'obj', '${segment.name}.obj.relocated')).writeAsBytesSync(bytes);
        }
      } else {
        throw UnimplementedError('Unknown segment type: ${segment.type}');
      }

      if (segmentByteSize != null && bytes.lengthInBytes != segmentByteSize) {
        print('WARN: Segment "${segment.name}" byte size (${bytes.lengthInBytes}) doesn\'t match expected size ($segmentByteSize).');
      }

      // Add to file
      mapping[segmentFilePointer] = p.relative(p.normalize(segmentFilePath), from: projectDir);
      builder.add(bytes);
      currentFilePointer = segmentFilePointer + bytes.lengthInBytes;
    }

    // Write exe file
    final String outExeFilePath = p.join(projectDir, rw.config.buildDir, 'RealWar.exe');
    File(outExeFilePath).writeAsBytesSync(builder.takeBytes());

    // Write mapping file
    final String outMapFilePath = p.join(projectDir, rw.config.buildDir, 'RealWar.map');
    final strBuffer = StringBuffer();
    for (final entry in mapping.entries) {
      strBuffer.write('0x${entry.key.toRadixString(16)}:'.padLeft(10));
      strBuffer.writeln(' ${entry.value}');
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

Uint8List _getRelocatedTextFromObject(Uint8List objBytes, RealWarYaml rw, int segmentVirtualAddress) {
  final coff = CoffFile.fromList(objBytes);
  relocateObject(objBytes, coff, rw, segmentVirtualAddress);

  final builder = BytesBuilder();

  for (final section in coff.sections) {
    if (section.header.name == '.text') {
      final filePtr = section.header.pointerToRawData;
      builder.add(Uint8List.sublistView(objBytes, filePtr, filePtr + section.header.sizeOfRawData));
    }
  }

  return builder.takeBytes();
}
