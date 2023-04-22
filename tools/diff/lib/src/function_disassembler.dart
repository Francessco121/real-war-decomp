import 'dart:ffi';

import 'package:capstone/capstone.dart';
import 'package:ffi/ffi.dart';

import 'file_data.dart';
import 'instruction.dart';

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

      return FunctionDisassembler._(cs, handle, arena);
    } on Exception {
      arena.releaseAll();
      rethrow;
    }
  }

  List<Instruction> disassembleFunction(FileData data, int offset, {required int address}) {
    _codePtr.value = Pointer<Uint8>.fromAddress(data.data.address + offset);
    _sizePtr.value = data.size - offset;
    _addressPtr.value = address;

    final insts = <Instruction>[];

    while (true) {
      if (!_cs.disasm_iter(_handle.value, _codePtr, _sizePtr, _addressPtr, _instPtr)) {
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

      if (inst.mnemonic == 'ret') {
        break;
      }
    }

    return insts;
  }

  void dispose() {
    _arena.releaseAll();
  }
}
