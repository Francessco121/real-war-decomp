import 'package:x86_analyzer/functions.dart';

final _memAddressRegex = RegExp(r'(0x[0-9a-fA-F]{4,})');

String dumpFunctionToString(DisassembledFunction func) {
  final buffer = StringBuffer();
  buffer.writeln('${func.name}:');

  for (final inst in func.instructions) {
    if (func.branchTargets.contains(inst.address)) {
      buffer.write(makeBranchLabel(inst.address));
      buffer.writeln(':');
    }
    if (func.caseTargets != null && func.caseTargets!.contains(inst.address)) {
      buffer.write(makeCaseLabel(inst.address));
      buffer.writeln(':');
    }

    buffer.write('/* ${inst.address.toRadixString(16)} */'.padRight(14));
    buffer.write(inst.mnemonic.padRight(10));
    buffer.write(' ');
    if (inst.isRelativeJump && 
        inst.operands.length == 1 && 
        inst.operands[0].imm != null) {
      // Replace branch target imm with label
      buffer.write(makeBranchLabel(inst.operands[0].imm!));
    } else if (inst.mnemonic == 'jmp' &&
          inst.operands.length == 1 &&
          inst.operands[0].type == x86_op_type.X86_OP_MEM &&
          func.jumpTables != null &&
          func.jumpTables!.containsKey(inst.operands[0].mem!.disp)) {
      // Replace jump table target imm with label
      buffer.write(inst.opStr.replaceFirst(_memAddressRegex, makeSwitchLabel(inst.operands[0].mem!.disp)));
    } else {
      buffer.write(inst.opStr);
    }
    buffer.writeln();
  }

  if (func.jumpTables != null) {
    for (final jumpTable in func.jumpTables!.values) {
      buffer.writeln();

      buffer.write(makeSwitchLabel(jumpTable.address));
      buffer.writeln(':');

      for (final (i, $case) in jumpTable.cases.indexed) {
        buffer.write('/* ${(jumpTable.address + (i * 4)).toRadixString(16)} */'.padRight(14));
        buffer.write('dd'.padRight(10));
        buffer.write(' ');
        buffer.writeln(makeCaseLabel($case));
      }
    }
  }

  return buffer.toString();
}
