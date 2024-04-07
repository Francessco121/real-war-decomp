import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:capstone/capstone.dart';
import 'package:ffi/ffi.dart';

import 'file_data.dart';
import 'instruction.dart';

class DisassembledFunction {
  final String name;
  /// Size in bytes, including any jump tables.
  final int size;
  final List<Instruction> instructions;
  /// Target addresses of local branches.
  final Set<int> branchTargets;
  /// Target addresses of jump table cases, if a jump table exists.
  final Set<int>? caseTargets;
  final LinkedHashMap<int, DisassembledJumpTable>? jumpTables;

  DisassembledFunction({
    required this.name,
    required this.size,
    required this.instructions,
    required this.branchTargets,
    required this.caseTargets,
    required this.jumpTables,
  });
}

class DisassembledJumpTable {
  final int address;
  final int size;
  final List<int> cases;

  DisassembledJumpTable({
    required this.address,
    required this.size,
    required this.cases,
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

  /// [endAddressHint] - Hint for the likely end address of the function including any jump tables.
  /// The size of the diasassembled function is not guaranteed to be within this address but it will
  /// be used to avoid bailing out early on RET instructions.
  DisassembledFunction disassembleFunction(FileData data, int offset,
      {required int address, required String name, int? endAddressHint}) {
    _codePtr.value = Pointer<Uint8>.fromAddress(data.dataPtr.address + offset);
    _sizePtr.value = data.size - offset;
    _addressPtr.value = address;

    final insts = <Instruction>[];
    final branchTargetSet = <int>{};
    final branchTargets = <int>[];
    final possibleJumpTables = <int>{};
    int? furthestBranchEnd;
    int? furthestJumpTableAddress;
    int size = 0;

    while (true) {
      // Next instruction
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

      if (inst.isRelativeJump) {
        // Possibly local branch, check if the target address is in bounds (if available)
        final target = inst.operands[0].imm!;
        if (endAddressHint == null || target < endAddressHint) {
          // Local branch
          if (branchTargetSet.add(target)) {
            branchTargets.add(target);
          }

          if (furthestBranchEnd == null || target > furthestBranchEnd) {
            furthestBranchEnd = target;
          }
        }
      } else if (inst.mnemonic == 'jmp' &&
          inst.operands.length == 1 &&
          inst.operands[0].type == x86_op_type.X86_OP_MEM) {
        // Possibly a jump into a switch jump table
        final targetDisp = inst.operands[0].mem!.disp;
        if (endAddressHint == null || targetDisp < endAddressHint) {
          if (furthestJumpTableAddress == null || targetDisp > furthestJumpTableAddress) {
            furthestJumpTableAddress = targetDisp;
          }
          possibleJumpTables.add(targetDisp);
        }
      }

      // Break early if we reach the jump table
      if (furthestJumpTableAddress != null && (address + size) >= furthestJumpTableAddress) {
        break;
      }

      if (furthestBranchEnd != null && inst.address >= furthestBranchEnd) {
        // Reached end of an outer branch
        furthestBranchEnd = null;
      }

      // Only break on RET if we're outside of all branches in the function
      //
      // Don't break on RET if we found a jump table. We'll just disassemble until then instead.
      if (inst.mnemonic == 'ret' && furthestBranchEnd == null && furthestJumpTableAddress == null) {
        break;
      }

      // Break on NOP
      //
      // This usually means the function doesn't have a return (i.e. it calls exit()).
      if (inst.mnemonic == 'nop') {
        insts.removeLast();
        break;
      }
    }

    // Read jump table(s)
    //
    // Jump tables should always start right after the end of the function and will be made
    // up of 4-byte addresses that point somewhere in the function
    final funcEndAddress = address + size;
    LinkedHashMap<int, DisassembledJumpTable>? jumpTables;
    Set<int>? caseTargetSet;

    if (possibleJumpTables.any((a) => a >= funcEndAddress)) {
      final byteData = ByteData.sublistView(data.data);
      final jumpTablesData = <int>[];

      caseTargetSet = {};

      // Read all bytes that make up jump tables
      final jumpTablesStart = address + size;
      int jumpTablesEnd = address + size;
      for (int i = jumpTablesStart; (((i + 4) - address) + offset) <= data.size; i += 4) {
        final addr = byteData.getUint32((i - address) + offset, Endian.little);
        if (addr < address || addr >= funcEndAddress) {
          break;
        }

        jumpTablesData.add(addr);
        jumpTablesEnd += 4;

        caseTargetSet.add(addr);
      }

      // Split read data into each individual jump table
      if (jumpTablesEnd - jumpTablesStart > 0) {
        jumpTables = LinkedHashMap<int, DisassembledJumpTable>();

        final validJumpTableAddresses = possibleJumpTables
          .where((a) => a >= funcEndAddress && a < jumpTablesEnd)
          .toList();

        for (int i = 0; i < validJumpTableAddresses.length; i++) {
          final jumpTableStart = validJumpTableAddresses[i];
          final jumpTableEnd = i < (validJumpTableAddresses.length - 1)
              ? validJumpTableAddresses[i + 1]
              : jumpTablesEnd;
          final jumpTableSize = jumpTableEnd - jumpTableStart;

          jumpTables[jumpTableStart] = DisassembledJumpTable(
            address: jumpTableStart, 
            size: jumpTableSize, 
            cases: jumpTablesData.sublist(
                (jumpTableStart - jumpTablesStart) ~/ 4,
                (jumpTableEnd - jumpTablesStart) ~/ 4),
          );
        }

        size += jumpTablesData.length * 4;
      } else {
        caseTargetSet = null;
      }
    }

    return DisassembledFunction(
      name: name,
      size: size,
      instructions: insts,
      branchTargets: branchTargetSet,
      caseTargets: caseTargetSet,
      jumpTables: jumpTables,
    );
  }

  void dispose() {
    _arena.releaseAll();
  }
}
