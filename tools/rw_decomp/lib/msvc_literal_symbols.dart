import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';

import 'rw_yaml.dart';

enum MsvcLiteralSymbolType {
  /// Static string literal. 
  string,
  /// 32-bit floating point number literal.
  float,
  /// 64-bit floating point number literal.
  double
}

const _vsDir = 'C:\\Program Files (x86)\\Microsoft Visual Studio';

/// Returns the MSVC symbol for the given literal.
/// 
/// MSVC automatically generates unique symbols for certain literals (like static strings) that
/// otherwise don't have an assigned symbol. Note: The symbol returned for strings will be the
/// one MSVC generates with /Gf or /GF enabled (string pooling).
(String, dynamic) generateMsvcSymbolForLiteral(RealWarYaml rw, ByteData baseExeData, int symbolAddress, 
    MsvcLiteralSymbolType type) {
  final physicalAddress = symbolAddress - rw.exe.imageBase;

  final literal = _readLiteralValue(baseExeData, physicalAddress, type);
  final symbol = _generateSymbol(literal, type);

  return (symbol, literal);
}

String _generateSymbol(dynamic literal, MsvcLiteralSymbolType type) {
  final String code;
  switch (type) {
    case MsvcLiteralSymbolType.string:
      final buffer = StringBuffer();
      for (final int c in (literal as String).codeUnits) {
        switch (c) {
          case 0x07:
            buffer.write('\\a');
          case 0x08:
            buffer.write('\\b');
          case 0x0C:
            buffer.write('\\f');
          case 0x0A:
            buffer.write('\\n');
          case 0x0D:
            buffer.write('\\r');
          case 0x09:
            buffer.write('\\t');
          case 0x0B:
            buffer.write('\\v');
          case 0x27:
            buffer.write('\\\'');
          case 0x22:
            buffer.write('\\"');
          case 0x5C:
            buffer.write('\\\\');
          case 0x3F:
            buffer.write('\\?');
          default:
            buffer.writeCharCode(c);
        }
      }

      code = 'char *func() { return "$buffer"; }';
    case MsvcLiteralSymbolType.float:
      code = 'float func() { return $literal; }';
    case MsvcLiteralSymbolType.double:
      code = 'double func() { return $literal; }';
  }

  final tempDir = Directory.systemTemp.createTempSync('rw-decomp-msvc-literals');
  try {
    final cPath = p.join(tempDir.path, 'source.c');
    final objPath = p.join(tempDir.path, 'source.obj');
    File(cPath).writeAsStringSync(code);

    final String path = [
      '$_vsDir\\VC98\\Bin',
      '$_vsDir\\Common\\MSDev98\\Bin',
      '$_vsDir\\VC98\\Lib',
      Platform.environment['PATH'],
    ].join(';');

    final clArgs = [
      '/nologo',
      '/c',
      '/W4',
      '/Og',
      '/Oi',
      '/Ot',
      '/Oy',
      '/Ob1',
      '/Gs',
      '/Gf',
      '/Gy',
      '/Fo$objPath',
      cPath
    ];

    final result = Process.runSync('$_vsDir\\VC98\\Bin\\CL.EXE', clArgs,
      environment: {'PATH': path},
    );

    if (result.exitCode != 0) {
      throw Exception('CL.EXE failed with exit code ${result.exitCode}.\n${result.stdout}\n${result.stderr}');
    }

    final coff = CoffFile.fromList(File(objPath).readAsBytesSync());
    final textSection = coff.sections.singleWhere((s) => s.header.name == '.text');
    final reloc = textSection.relocations.single;
    final symbol = coff.symbolTable![reloc.symbolTableIndex];
    final symbolName = symbol!.name.shortName
        ?? coff.stringTable!.strings[symbol.name.offset]!;

    return symbolName;
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

dynamic _readLiteralValue(ByteData exeData, int physicalAddress, MsvcLiteralSymbolType type) {
  switch (type) {
    case MsvcLiteralSymbolType.string:
      return _readNullTerminatedOrFullString(exeData, physicalAddress);
    case MsvcLiteralSymbolType.float:
      return exeData.getFloat32(physicalAddress, Endian.little);
    case MsvcLiteralSymbolType.double:
      return exeData.getFloat64(physicalAddress, Endian.little);
  }
}

String _readNullTerminatedOrFullString(ByteData data, [int offset = 0]) {
  final bytes = <int>[];
  int i = offset;
  while (i < data.lengthInBytes) {
    final c = data.getUint8(i++);
    if (c == 0) {
      break;
    }

    bytes.add(c);
  }

  return String.fromCharCodes(bytes);
}
