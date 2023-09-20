import 'dart:typed_data';

String readNullTerminatedOrFullString(Uint8List data, [int offset = 0]) {
  final bytes = <int>[];
  int i = offset;
  while (i < data.lengthInBytes) {
    final c = data[i++];
    if (c == 0) {
      break;
    }

    bytes.add(c);
  }

  return String.fromCharCodes(bytes);
}

extension BytesBuilderExtensions on BytesBuilder {
  void addUint32(int value, [Endian endian = Endian.little]) {
    if (endian == Endian.little) {
      addByte(value & 0xFF);
      addByte((value >> 8) & 0xFF);
      addByte((value >> 16) & 0xFF);
      addByte((value >> 24) & 0xFF);
    } else {
      addByte((value >> 24) & 0xFF);
      addByte((value >> 16) & 0xFF);
      addByte((value >> 8) & 0xFF);
      addByte(value & 0xFF);
    }
  }

  void addUint16(int value, [Endian endian = Endian.little]) {
    if (endian == Endian.little) {
      addByte(value & 0xFF);
      addByte((value >> 8) & 0xFF);
    } else {
      addByte((value >> 8) & 0xFF);
      addByte(value & 0xFF);
    }
  }

  void addAsciiString(String string, {bool nullTerminate = true}) {
    for (final c in string.codeUnits) {
      addByte(c);
    }

    if (nullTerminate) {
      addByte(0);
    }
  }
}
