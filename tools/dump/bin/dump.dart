import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:capstone/capstone.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:rw_yaml/rw_yaml.dart';

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
  final String asmFilePath = p.join(projectDir, rw.config.asmDir, '$symbolName.s');

  // Compute physical (file) address of the symbol in the base exe
  final int physicalAddress =
      virtualAddress - 0x400000; // 0x400000 == imageBase

  // Load exe
  final arena = Arena();
  
  try {
    final int dataSize = 950272; // load .text
    final Pointer<Uint8> data = arena<Uint8>(dataSize);
    final file = File(exeFilePath).openSync();

    try {
      file.setPositionSync(0x1000);
      file.readIntoSync(data.asTypedList(dataSize));
    } finally {
      file.closeSync();
    }
    
    // Init capstone
    final capstoneDll = ffi.DynamicLibrary.open('../capstone.dll');
    final cs = Capstone(capstoneDll);

    final handle = arena.allocate<csh>(sizeOf<csh>());

    final result = cs.open(cs_arch.X86, cs_mode.$32, handle);
    if (result != cs_err.OK) {
      throw Exception('Failed to initialize Capstone instance: $result.');
    }

    arena.using(handle, (handle) => cs.close(handle));

    final Pointer<Pointer<Uint8>> codePtr = arena.allocate<Pointer<Uint8>>(sizeOf<Pointer<Uint8>>());
    final Pointer<Size> sizePtr = arena.allocate<Size>(sizeOf<Size>());
    final Pointer<Uint64> addressPtr = arena.allocate<Uint64>(sizeOf<Uint64>());
    final Pointer<cs_insn> instPtr = cs.malloc(handle.value);

    arena.using(instPtr, (insn) => cs.free(insn, 1));

    // Disassemble
    int offset = physicalAddress - 0x1000;
    codePtr.value = Pointer<Uint8>.fromAddress(data.address + offset);
    sizePtr.value = dataSize - offset;
    addressPtr.value = virtualAddress;

    final insts = <Instruction>[];

    while (true) {
      if (!cs.disasm_iter(handle.value, codePtr, sizePtr, addressPtr, instPtr)) {
        int err = cs.errno(handle.value);
        if (err == cs_err.OK) {
          // Ran out of bytes to disassemble
          break;
        } else {
          throw Exception('disasm_iter error: $err');
        }
      }

      final inst = Instruction.fromCapstone(instPtr.ref);
      insts.add(inst);

      if (inst.mnemonic == 'ret') {
        break;
      }
    }

    // Write to file
    final buffer = StringBuffer();
    buffer.writeln('$symbolName:');

    for (final inst in insts) {
      buffer.write('/* ${inst.address.toRadixString(16)} */'.padRight(14));
      buffer.write(inst.mnemonic);
      buffer.write(' ');
      buffer.writeln(inst.opStr);
    }

    Directory(p.dirname(asmFilePath)).createSync(recursive: true);

    final asmFile = File(asmFilePath);
    asmFile.writeAsStringSync(buffer.toString());

    print('Wrote assembly to $asmFilePath');
  } finally {
    arena.releaseAll();
  }
}

class Instruction {
  final Uint8List bytes;
  final int address;
  final String mnemonic;
  final String opStr;

  Instruction({
    required this.bytes,
    required this.address,
    required this.mnemonic,
    required this.opStr,
  });

  factory Instruction.fromCapstone(cs_insn insn) {
    final bytes = Uint8List(insn.size);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = insn.bytes[i];
    }

    return Instruction(
        bytes: bytes, 
        address: insn.address,
        mnemonic: insn.mnemonic.readNullTerminatedString(), 
        opStr: insn.op_str.readNullTerminatedString());
  }
}
