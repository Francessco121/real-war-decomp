import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:rw_decomp/rw_yaml.dart';
import 'package:x86_analyzer/functions.dart';

/// Disassembles a single function from the base executable
void main(List<String> args) {
  if (args.length != 1) {
    print('Usage: dump.dart <func symbol name>');
    return;
  }

  // Assume we're ran from the package dir
  final String projectDir = p.normalize(p.join(p.current, '../../'));

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Figure out symbol address
  final String symbolName = args[0];
  final int? virtualAddress = rw.symbols[symbolName];
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
    final capstoneDll = ffi.DynamicLibrary.open('../capstone.dll');

    // Disassemble
    final disassembler = FunctionDisassembler.init(capstoneDll);

    final DisassembledFunction func;

    try {
      func = disassembler.disassembleFunction(data, physicalAddress, address: virtualAddress);
    } finally {
      disassembler.dispose();
    }

    // Write to file
    final buffer = StringBuffer();
    buffer.writeln('$symbolName:');

    for (final inst in func.instructions) {
      if (func.branchTargetSet.contains(inst.address)) {
        buffer.write(makeBranchLabel(inst.address));
        buffer.writeln(':');
      }

      buffer.write('/* ${inst.address.toRadixString(16)} */'.padRight(14));
      buffer.write(inst.mnemonic.padRight(10));
      buffer.write(' ');
      if (inst.isLocalBranch) {
        // Replace branch target imm with label
        if (inst.operands.length == 1 && inst.operands[0].imm != null) {
          buffer.write(makeBranchLabel(inst.operands[0].imm!));
        } else {
          buffer.write(inst.opStr);
        }
      } else {
        buffer.write(inst.opStr);
      }
      buffer.writeln();
    }

    Directory(p.dirname(asmFilePath)).createSync(recursive: true);

    final asmFile = File(asmFilePath);
    asmFile.writeAsStringSync(buffer.toString());

    print('Wrote assembly to $asmFilePath');
  } finally {
    arena.releaseAll();
  }
}
