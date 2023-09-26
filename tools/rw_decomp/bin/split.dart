import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/dump_function.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:x86_analyzer/functions.dart';

/*
from rw.yaml, extract .bin and .asm files for each segment as necessary.
*/

class SplitException implements Exception {
  final String filePath;
  final String message;

  SplitException(this.filePath, this.message);
}

void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Init disassembler
  final capstoneDll = ffi.DynamicLibrary.open(p.join(projectDir, 'tools', 'capstone.dll'));
  final disassembler = FunctionDisassembler.init(capstoneDll);
  
  // Parse exe
  final String exeFilePath = p.join(projectDir, rw.config.exePath);
  final exeBytes = File(exeFilePath).readAsBytesSync();
  final exe = PeFile.fromList(exeBytes);

  // Setup
  final String srcDirPath = p.join(projectDir, rw.config.srcDir);
  final String asmDirPath = p.join(projectDir, rw.config.asmDir);
  final String binDirPath = p.join(projectDir, rw.config.binDir);
  Directory(binDirPath).createSync();
  Directory(p.join(binDirPath, '_funcs')).createSync();

  // Split
  try {
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

      if (segment.type == 'bss' || segment.type == 'data' || segment.type == 'rdata') {
        continue;
      }

      final segmentFilePointer = section == null
          ? segment.address - imageBase
          : (segment.address - imageBase - section.header.virtualAddress) + section.header.pointerToRawData;
      final segmentByteSize = i < (rw.segments.length - 1)
          ? rw.segments[i + 1].address - segment.address
          : null;
        
      final segmentBytes = Uint8ClampedList.sublistView(
          exeBytes, segmentFilePointer, segmentByteSize == null ? null : (segmentFilePointer + segmentByteSize));
      
      if (segment.type == 'bin') {
        // bin, dump full segment to file
        File(p.join(binDirPath, '${segment.name}.bin')).writeAsBytesSync(segmentBytes);
      } else if (segment.type == 'c') {
        // c, dump referenced ASM_FUNC functions
        final cFilePath = p.join(srcDirPath, '${segment.name}.c');
        _extractCSegment(
          cFilePath: cFilePath, 
          asmDirPath: asmDirPath,
          binDirPath: binDirPath, 
          rw: rw, 
          segmentAddress: segment.address, 
          bytes: segmentBytes, 
          disassembler: disassembler,
        );
      }
    }
  } on SplitException catch (ex) {
    stderr.write('${p.relative(ex.filePath, from: projectDir)}: ');
    stderr.writeln(ex.message);
    exit(1);
  }

  print('Done.');
}

final _pragmaAsmFuncRegex = RegExp(r'^#pragma(?:\s+)ASM_FUNC(?:\s+)(\S+)');

void _extractCSegment({
  required String cFilePath, 
  required String asmDirPath, 
  required String binDirPath, 
  required RealWarYaml rw, 
  required int segmentAddress, 
  required Uint8ClampedList bytes, 
  required FunctionDisassembler disassembler,
}) {
  final segmentEndAddress = segmentAddress + bytes.lengthInBytes;

  // Search for ASM_FUNC pragmas
  final asmFuncs = <String>[];

  for (final line in File(cFilePath).readAsLinesSync()) {
    final asmFunc = _pragmaAsmFuncRegex.firstMatch(line.trimLeft())?.group(1);
    if (asmFunc != null) {
      asmFuncs.add(asmFunc);
    }
  }

  // Dump function assembly to files
  if (asmFuncs.isEmpty) {
    return;
  }

  final segmentData = FileData.fromClampedList(bytes);
  for (final funcName in asmFuncs) {
    final symbolAddress = rw.symbols[funcName];
    if (symbolAddress == null) {
      throw SplitException(cFilePath, 'Could not find function \'$funcName\' for ASM_FUNC pragma.');
    }

    if (symbolAddress < segmentAddress || symbolAddress >= segmentEndAddress) {
      throw SplitException(cFilePath, 
        'Cannot split ASM_FUNC for function \'$funcName\' @ ${symbolAddress.toRadixString(16)} '
        'because it is outside of the segment (${segmentAddress.toRadixString(16)}-'
        '${segmentEndAddress.toRadixString(16)}).');
    }

    // Disassemble function
    final symbolSegmentOffset = symbolAddress - segmentAddress;
    final func = disassembler.disassembleFunction(
        segmentData, symbolSegmentOffset, address: symbolAddress, name: funcName);
    
    // Write human readable assembly file
    final asmFilePath = p.join(asmDirPath, '$funcName.s');
    File(asmFilePath).writeAsStringSync(dumpFunctionToString(func));

    // Write raw binary file for ASM_FUNC
    final binFilePath = p.join(binDirPath, '_funcs', '$funcName.bin');
    File(binFilePath).writeAsBytesSync(
          Uint8ClampedList.sublistView(bytes, symbolSegmentOffset, symbolSegmentOffset + func.size));
  }
}
