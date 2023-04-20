import 'dart:convert';
import 'dart:typed_data';

import 'package:pe_coff/coff.dart';
import 'package:pe_coff/src/structured_file_reader.dart';
import 'package:test/test.dart';

void main() {
  test('can parse header for object file', () {
    final data = base64.decode('TAEGABV2KmP3AwAAGwAAAAAAAAA=');

    final reader = StructuredFileReader.list(data, endian: Endian.little);
    final header = CoffHeader.fromReader(reader);

    expect(header.machine, equals(MachineType.i386));
    expect(header.numberOfSections, equals(6));
    expect(header.timeDateStamp.millisecondsSinceEpoch ~/ 1000,
        equals(0x632A7615));
    expect(header.pointerToSymbolTable, equals(0x3F7));
    expect(header.numberOfSymbols, equals(27));
    expect(header.sizeOfOptionalHeader, equals(0));
    expect(header.characteristics.rawValue, equals(0));
  });
}
