import 'package:collection/collection.dart';
import 'package:x86_analyzer/functions.dart';

import 'levenshtein.dart';

class DiffLine<T> {
  final DiffEditType diffType;

  /// Target (base exe)
  final T? target;

  /// Source (obj)
  final T? source;

  DiffLine(this.diffType, this.target, this.source);
}

class InstructionDiffEquality implements Equality<Instruction> {
  final int _imageBase;

  InstructionDiffEquality({required int imageBase}) : _imageBase = imageBase;

  @override
  bool equals(Instruction a, Instruction b) {
    // Consider two instructions to be the same (as far as the diffing algorithm goes) if:
    // - The mnemonics are the same
    // - They have the same number of operands and each is the same op type in the same order
    // - Memory operands have the same displacement or neither displacement is an absolute
    //   memory address (i.e. something in .text, .data, .rdata, .bss)
    //
    // Otherwise, assume the two instructions are unrelated.
    // Instructions that have equality via this function may still have differences. Those
    // differences will be highlighted after the diffing algorithm is ran. Allowing instructions
    // to appear equal to the diffing algorithm even if they differ in some ways can clean up
    // the final diff in some cases, such as preventing register allocation differences from
    // placing two instructions that match in everything but registers on different diff lines.
    if (a.mnemonic != b.mnemonic) {
      return false;
    }

    if (a.operands.length != b.operands.length) {
      return false;
    }

    for (int i = 0; i < a.operands.length; i++) {
      final ao = a.operands[i];
      final bo = b.operands[i];

      if (ao.type != bo.type) {
        return false;
      }

      if (ao.type == x86_op_type.X86_OP_MEM) {
        final am = ao.mem!;
        final bm = bo.mem!;

        // Consider instructions related if the displacements are different but neither is an
        // absolute memory address. In these cases it may be referencing a stack variable,
        // which is likely to be related but with different stack variable allocations.
        if (am.disp != bm.disp && (am.disp >= _imageBase || bm.disp >= _imageBase)) {
          return false;
        }
      }
    }

    return true;
  }
  
  @override
  int hash(Instruction e) => e.hashCode;
  
  @override
  bool isValidKey(Object? o) => o is Instruction;
}

List<DiffLine<T>> runDiff<T>(List<T> target, List<T> source, [Equality<T> diffEquality = const DefaultEquality()]) {
  // Run diff
  // Note: run diff backwards, we want changes from source (the obj file) to target (the exe file)
  // i swear it's not confusing...
  final result = levenshtein<T>(target, source, diffEquality);
  final edits = generateLevenshteinEdits(result.item2);

  // Note: target/source in the diff lines represent our original definition of target/source,
  // where target = exe, source = obj. This is backwards from the diff's definition since we're
  // trying to generate a list of changes to go from the base exe to the obj file.
  final lines = <DiffLine<T>>[];

  for (int i = edits.length - 1; i >= 0; i--) {
    final edit = edits[i];

    if (edit.type == DiffEditType.equal ||
        edit.type == DiffEditType.substitute) {
      lines.add(DiffLine(edit.type, target[edit.sourceIndex - 1],
          source[edit.targetIndex! - 1]));
    } else if (edit.type == DiffEditType.insert) {
      lines.add(DiffLine(edit.type, null, source[edit.targetIndex! - 1]));
    } else if (edit.type == DiffEditType.delete) {
      lines.add(DiffLine(edit.type, target[edit.sourceIndex - 1], null));
    } else {
      throw UnimplementedError();
    }
  }

  return lines;
}
