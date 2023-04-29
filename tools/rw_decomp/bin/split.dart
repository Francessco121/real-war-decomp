import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/rw_yaml.dart';

/*
from rw.yaml, extract .bin and .asm files for each segment as necessary.
*/

void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);
  
  // Parse exe
  final String exeFilePath = p.join(projectDir, rw.config.exePath);
  final exeBytes = File(exeFilePath).readAsBytesSync();
  final exe = PeFile.fromList(exeBytes);

  // Setup
  final String binDirPath = p.join(projectDir, rw.config.binDir);
  Directory(binDirPath).createSync();

  // Split
  final imageBase = exe.optionalHeader!.windows!.imageBase;

  Section? section; // start in header
  int nextSectionIndex = 0; 
  Section? nextSection = exe.sections[nextSectionIndex];
  for (int i = 0; i < rw.segments.length; i++) {
    final segment = rw.segments[i];

    // Have we entered a new section?
    while (nextSection != null && segment.address >= (nextSection.header.virtualAddress + imageBase)) {
      section = nextSection;
      nextSectionIndex++;
      nextSection = (nextSectionIndex) == exe.sections.length ? null : exe.sections[nextSectionIndex];
    }

    final segmentFilePointer = section == null
        ? segment.address - imageBase
        : (segment.address - imageBase - section.header.virtualAddress) + section.header.pointerToRawData;
    final segmentByteSize = i < (rw.segments.length - 1)
        ? rw.segments[i + 1].address - segment.address
        : null;
    
    if (segment.type == 'bin') {
      File(p.join(binDirPath, '${segment.name}.bin'))
          .writeAsBytesSync(Uint8ClampedList.sublistView(
              exeBytes, segmentFilePointer, segmentByteSize == null ? null : (segmentFilePointer + segmentByteSize)));
    }

    // TODO: asm extraction
  }
}
