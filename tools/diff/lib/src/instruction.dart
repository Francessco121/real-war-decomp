import 'dart:ffi';
import 'dart:typed_data';

import 'package:capstone/capstone.dart';

class Instruction {
  final Uint8List bytes;
  final int address;
  final String mnemonic;
  final String opStr;

  final int _hashCode;

  Instruction({
    required this.bytes,
    required this.address,
    required this.mnemonic,
    required this.opStr,
  }) : _hashCode = Object.hashAll(bytes);

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

  @override
  int get hashCode => _hashCode;

  @override
  bool operator ==(Object other) {
    if (other is Instruction) {
      if (bytes.length != other.bytes.length) {
        return false;
      }

      for (int i = 0; i < bytes.length; i++) {
        if (bytes[i] != other.bytes[i]) {
          return false;
        }
      }

      return true;
    } else {
      return false;
    }
  }
}
