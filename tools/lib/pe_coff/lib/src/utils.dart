import 'dart:typed_data';

import 'structured_file_reader.dart';

/// Reads a string at the given [offset] that is either null-terminated or
/// which goes to the end of the [data].
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

/// Parses an ASCII numeric string from the given range of the [data] with the
/// given [radix] (defaults to base 10).
int parseAsciiNumeric(Uint8List data,
    {int offset = 0, int? length, int? radix}) {
  final string = String.fromCharCodes(
      data, offset, length != null ? offset + length : null).trim();

  if (string.isEmpty) {
    return 0;
  }

  return int.parse(string, radix: radix);
}

extension StructuredFileReaderExtensions on StructuredFileReader {
  /// Reads and advances bytes until a full null-terminated string
  /// has been read (advances past the null byte).
  String readNullTerminatedString() {
    final bytes = <int>[];
    while (true) {
      final c = readUint8();
      if (c == 0) {
        break;
      }

      bytes.add(c);
    }

    return String.fromCharCodes(bytes);
  }
}
