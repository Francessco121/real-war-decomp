import 'dart:ffi';

import 'package:capstone/capstone.dart';
import 'package:ffi/ffi.dart';

import 'file_data.dart';
import 'instruction.dart';

class DisassembledFunction {
  final String name;
  /// Size in bytes.
  final int size;
  final List<Instruction> instructions;
  final Set<int> branchTargetSet;
  /// In order of discovery.
  final List<int> branchTargets;

  DisassembledFunction({
    required this.name,
    required this.size,
    required this.instructions,
    required this.branchTargetSet,
    required this.branchTargets,
  });
}

class FunctionDisassembler {
  final Pointer<Pointer<Uint8>> _codePtr;
  final Pointer<Size> _sizePtr;
  final Pointer<Uint64> _addressPtr;
  final Pointer<cs_insn> _instPtr;

  final Arena _arena;
  final Pointer<Size> _handle;
  final Capstone _cs;

  FunctionDisassembler._(this._cs, this._handle, this._arena)
      : _codePtr = _arena.allocate<Pointer<Uint8>>(sizeOf<Pointer<Uint8>>()),
        _sizePtr = _arena.allocate<Size>(sizeOf<Size>()),
        _addressPtr = _arena.allocate<Uint64>(sizeOf<Uint64>()),
        _instPtr = _cs.malloc(_handle.value) {
    _arena.using(_instPtr, (insn) => _cs.free(insn, 1));
  }

  factory FunctionDisassembler.init(DynamicLibrary capstoneDll) {
    final arena = Arena();

    try {
      final cs = Capstone(capstoneDll);
      final handle = arena.allocate<csh>(sizeOf<csh>());

      final result = cs.open(cs_arch.X86, cs_mode.$32, handle);
      if (result != cs_err.OK) {
        throw Exception('Failed to initialize Capstone instance: $result.');
      }

      arena.using(handle, (handle) => cs.close(handle));

      cs.option(handle.value, cs_opt_type.DETAIL, cs_opt_value.ON);

      return FunctionDisassembler._(cs, handle, arena);
    } on Exception {
      arena.releaseAll();
      rethrow;
    }
  }

  DisassembledFunction disassembleFunction(FileData data, int offset,
      {required int address, required String name, int? endAddress}) {
    _codePtr.value = Pointer<Uint8>.fromAddress(data.data.address + offset);
    _sizePtr.value = data.size - offset;
    _addressPtr.value = address;

    final insts = <Instruction>[];
    final branchTargetSet = <int>{};
    final branchTargets = <int>[];
    int? furthestBranchEnd;
    int size = 0;

    while (true) {
      if (!_cs.disasm_iter(
          _handle.value, _codePtr, _sizePtr, _addressPtr, _instPtr)) {
        int err = _cs.errno(_handle.value);
        if (err == cs_err.OK) {
          // Ran out of bytes to disassemble
          break;
        } else {
          throw Exception('disasm_iter error: $err');
        }
      }

      final inst = Instruction.fromCapstone(_instPtr.ref);
      insts.add(inst);

      size += inst.bytes.lengthInBytes;

      if (inst.isLocalBranch) {
        // Possibly local branch, check if the target address is in bounds (if available)
        final target = inst.operands[0].imm!;
        if (endAddress == null || target < endAddress) {
          // Local branch
          if (branchTargetSet.add(target)) {
            branchTargets.add(target);
          }

          if (furthestBranchEnd == null || target > furthestBranchEnd) {
            furthestBranchEnd = target;
          }
        }
      }

      if (furthestBranchEnd != null && inst.address >= furthestBranchEnd) {
        // Reached end of a branch
        furthestBranchEnd = null;
      }

      // Only break on RET if we're outside of all branches in the function
      if (inst.mnemonic == 'ret' && furthestBranchEnd == null) {
        break;
      }
    }

    return DisassembledFunction(
      name: name,
      size: size,
      instructions: insts,
      branchTargetSet: branchTargetSet,
      branchTargets: branchTargets,
    );
  }

  void dispose() {
    _arena.releaseAll();
  }
}
