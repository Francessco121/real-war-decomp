import 'package:collection/collection.dart';
import 'package:x86_analyzer/functions.dart';

import 'rw_yaml.dart';

class VerificationResult {
  final DateTime timestamp;
  final Map<String, DateTime> objs;
  final VerificationSectionResult text;
  final VerificationSectionResult rdata;
  final VerificationSectionResult data;

  VerificationResult({
    required this.timestamp, 
    required this.objs, 
    required this.text, 
    required this.rdata, 
    required this.data,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      timestamp: DateTime.parse(json['timestamp']),
      objs: (json['objs'] as Map<String, dynamic>)
          .map((name, dt) => MapEntry(name, DateTime.parse(dt))),
      text: VerificationSectionResult.fromJson(json['.text']),
      rdata: VerificationSectionResult.fromJson(json['.rdata']),
      data: VerificationSectionResult.fromJson(json['.data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'objs': {
        for (final entry in objs.entries)
          entry.key: entry.value.toIso8601String()
      },
      '.text': text.toJson(),
      '.rdata': rdata.toJson(),
      '.data': data.toJson(),
    };
  }
}

class VerificationSectionResult {
  final int totalMatchingBytes;
  final int totalCoveredBytes;
  final Map<int, SymbolVerificationResult> symbols;

  VerificationSectionResult({
    required this.totalMatchingBytes, 
    required this.totalCoveredBytes, 
    required this.symbols,
  });

  factory VerificationSectionResult.fromJson(Map<String, dynamic> json) {
    final symbols = <int, SymbolVerificationResult>{};
    for (final entry in (json['symbols'] as Map<String, dynamic>).entries) {
      final address = int.parse(entry.key);
      symbols[address] = _symbolFromString(address, entry.value);
    }

    return VerificationSectionResult(
      totalMatchingBytes: json['totalMatchingBytes'],
      totalCoveredBytes: json['totalCoveredBytes'],
      symbols: symbols,
    );
  }

  Map<String, dynamic> toJson() {
    final syms = symbols.values.sorted((a, b) => a.address.compareTo(b.address));

    return {
      'totalMatchingBytes': totalMatchingBytes,
      'totalCoveredBytes': totalCoveredBytes,
      'symbols': {
        for (final sym in syms)
          '0x${sym.address.toRadixString(16)}': _symbolToString(sym)
      }
    };
  }

  static String _symbolToString(SymbolVerificationResult symbol) {
    return '${symbol.nonMatchScore},${symbol.matchingBytes},${symbol.totalBaseBytes}';
  }

  static SymbolVerificationResult _symbolFromString(int address, String str) {
    final parts = str.split(',');

    return SymbolVerificationResult(
      address: address,
      nonMatchScore: int.parse(parts[0]),
      matchingBytes: int.parse(parts[1]),
      totalBaseBytes: int.parse(parts[2]),
    );
  }
}

class SymbolVerificationResult {
  /// Symbol absolute virtual address (in base exe)
  final int address;
  /// Non-matching score, the larger the number the less it matches
  /// 
  /// 0 = matching
  /// > 0 = non-matching
  final int nonMatchScore;
  /// Number of matching bytes
  final int matchingBytes;
  /// Total number of bytes in base exe
  final int totalBaseBytes;

  SymbolVerificationResult({
    required this.address, 
    required this.nonMatchScore, 
    required this.matchingBytes, 
    required this.totalBaseBytes,
  });
}

/// Returns whether the only difference between the two instructions is a reference to
/// a literal symbol and that they reference the same literal by value. In this case, the
/// instructions should be considered matching even tho the literal address is different.
bool doInstructionsMatchViaLiteralSymbol(RealWarYaml rw, Instruction a, Instruction b) {
  if (a.mnemonic != b.mnemonic || !_doOperandsOnlyDifferInImmOrDisp(a, b)) {
    return false;
  }

  assert(a.operands.length == b.operands.length);

  bool foundAnyLiteral = false;
  for (int i = 0; i < a.operands.length; i++) {
    final ao = a.operands[i];
    String? aLiteralName;

    if (ao.type == x86_op_type.X86_OP_IMM) {
      aLiteralName = rw.literalSymbolsByAddress[ao.imm!]?.name;
    } else if (ao.type == x86_op_type.X86_OP_MEM) {
      aLiteralName = rw.literalSymbolsByAddress[ao.mem!.disp]?.name;
    }

    if (aLiteralName == null || !isLiteralSymbolName(aLiteralName)) {
      continue;
    }

    // Found literal symbol reference, ensure other instruction references it with the same operand type/index
    foundAnyLiteral = true;
    final bo = b.operands[i];
    assert(ao.type == bo.type);

    String? bLiteralName;
    if (bo.type == x86_op_type.X86_OP_IMM) {
      bLiteralName = rw.literalSymbolsByAddress[bo.imm!]?.name;
    } else if (bo.type == x86_op_type.X86_OP_MEM) {
      bLiteralName = rw.literalSymbolsByAddress[bo.mem!.disp]?.name;
    }

    if (bLiteralName == null || !isLiteralSymbolName(bLiteralName)) {
      // Found literal reference for a but not b, the instructions do not match
      return false;
    }

    if (aLiteralName != bLiteralName) {
      // Found literals on both sides but they don't match
      return false;
    }
  }

  // Instructions match by literal reference if at least one was found and all found matched
  return foundAnyLiteral;
}

bool isLiteralSymbolName(String name) {
  return name.startsWith('__real@') || name.startsWith('??_C@');
}

bool _doOperandsOnlyDifferInImmOrDisp(Instruction a, Instruction b) {
  if (a.operands.length != b.operands.length) {
    return false;
  }

  for (int i = 0; i < a.operands.length; i++) {
    final ao = a.operands[i];
    final bo = b.operands[i];

    if (ao.type != bo.type) {
      return false;
    }

    switch (ao.type) {
      case x86_op_type.X86_OP_REG:
        if (ao.reg != bo.reg) {
          return false;
        }
      case x86_op_type.X86_OP_MEM:
        if (ao.mem!.base != bo.mem!.base ||
            ao.mem!.index != bo.mem!.index ||
            ao.mem!.scale != bo.mem!.scale ||
            ao.mem!.segment != bo.mem!.segment) {
          return false;
        }
    }
  }

  return true;
}
