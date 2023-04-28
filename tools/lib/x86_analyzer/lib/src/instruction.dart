import 'dart:ffi';
import 'dart:typed_data';

import 'package:capstone/capstone.dart';

export 'package:capstone/capstone.dart' show x86_op_type, cs_ac_type;

String makeBranchLabel(int address) {
  return '_L${address.toRadixString(16)}';
}

class OperandMem {
  /// segment register (or X86_REG_INVALID if irrelevant)
  final int segment;

  /// base register (or X86_REG_INVALID if irrelevant)
  final int base;

  /// index register (or X86_REG_INVALID if irrelevant)
  final int index;

  /// scale for index register
  final int scale;

  /// displacement value
  final int disp;

  OperandMem.fromCapstone(x86_op_mem mem)
      : segment = mem.segment,
        base = mem.base,
        index = mem.index,
        scale = mem.scale,
        disp = mem.disp;
}

class Operand {
  /// See [x86_op_type].
  final int type;

  /// How is this operand accessed? (READ, WRITE or READ|WRITE)
  ///
  /// See [cs_ac_type].
  final int access;

  /// register value for REG operand
  final int? reg;

  /// immediate value for IMM operand
  final int? imm;

  /// base/index/scale/disp value for MEM operand
  final OperandMem? mem;

  Operand.fromCapstone(cs_x86_op op)
      : type = op.type,
        access = op.access,
        reg = op.type == x86_op_type.X86_OP_REG ? op.unnamed.reg : null,
        imm = op.type == x86_op_type.X86_OP_IMM ? op.unnamed.imm : null,
        mem = op.type == x86_op_type.X86_OP_MEM
            ? OperandMem.fromCapstone(op.unnamed.mem)
            : null;
}

class Instruction {
  bool get isBranch => mnemonic.startsWith('j');
  bool get isLocalBranch =>
      isBranch &&
      operands.length == 1 &&
      operands[0].type == x86_op_type.X86_OP_IMM;

  final Uint8List bytes;
  final int address;
  final String mnemonic;
  final String opStr;
  final List<Operand> operands;

  final int _hashCode;

  Instruction._({
    required this.bytes,
    required this.address,
    required this.mnemonic,
    required this.opStr,
    required this.operands,
  }) : _hashCode = Object.hashAll(bytes);

  factory Instruction.fromCapstone(cs_insn insn) {
    final bytes = Uint8List(insn.size);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = insn.bytes[i];
    }

    final detail = insn.detail.ref.unnamed.x86;

    final operands = <Operand>[];
    for (int i = 0; i < detail.op_count; i++) {
      operands.add(Operand.fromCapstone(detail.operands[i]));
    }

    return Instruction._(
        bytes: bytes,
        address: insn.address,
        mnemonic: insn.mnemonic.readNullTerminatedString(),
        opStr: insn.op_str.readNullTerminatedString(),
        operands: operands);
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
