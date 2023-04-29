import 'package:x86_analyzer/functions.dart';

String dumpFunctionToString(DisassembledFunction func) {
  final buffer = StringBuffer();
  buffer.writeln('${func.name}:');

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

  return buffer.toString();
}
