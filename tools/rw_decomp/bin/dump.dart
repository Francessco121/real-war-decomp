import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:args/args.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:rw_decomp/dump_function.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:x86_analyzer/functions.dart';

/// Disassembles a single function from the base executable
void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  if (argResult.rest.length != 1) {
    print('Usage: dump.dart <func symbol name>');
    return;
  }

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Figure out symbol address
  final String symbolName = argResult.rest[0];
  final int? virtualAddress = rw.symbols[symbolName]?.address;
  if (virtualAddress == null) {
    print('Cannot locate symbol address: $symbolName');
    return;
  }

  // Compute paths
  final String exeFilePath = p.join(projectDir, rw.config.exePath);
  final String asmFilePath =
      p.join(projectDir, rw.config.asmDir, '$symbolName.s');

  // Compute physical (file) address of the symbol in the base exe
  final int physicalAddress =
      virtualAddress - (rw.exe.imageBase + rw.exe.textVirtualAddress);

  // Load exe
  final arena = Arena();

  try {
    final FileData data; // load .text
    final file = File(exeFilePath).openSync();

    try {
      data = FileData.read(file, rw.exe.textFileOffset, rw.exe.textPhysicalSize);
    } finally {
      file.closeSync();
    }

    // Init capstone
    final capstoneDll = ffi.DynamicLibrary.open(p.join(projectDir, 'tools', 'capstone.dll'));

    // Disassemble
    final disassembler = FunctionDisassembler.init(capstoneDll);

    final DisassembledFunction func;

    try {
      func = disassembler.disassembleFunction(data, physicalAddress,
          address: virtualAddress, name: symbolName);
    } finally {
      disassembler.dispose();
    }

    // Write to file
    final dumpString = dumpFunctionToString(func);

    Directory(p.dirname(asmFilePath)).createSync(recursive: true);

    final asmFile = File(asmFilePath);
    asmFile.writeAsStringSync(dumpString);

    print('Wrote assembly to $asmFilePath');
  } finally {
    arena.releaseAll();
  }
}
