import 'structured_file_reader.dart';

class StringTable {
  /// Size in bytes of the string table (including the size field itself).
  final int size;

  /// A map of string indexes (byte offset relative to start of table) to
  /// the actual string.
  final Map<int, String> strings;

  StringTable({required this.size, required this.strings});

  factory StringTable.fromReader(StructuredFileReader reader) {
    final size = reader.readUint32();

    final strings = <int, String>{};
    final curStringBytes = <int>[];
    int start = 4;
    int offset = 4;

    while (offset < size) {
      final c = reader.readUint8();

      if (c == 0) {
        strings[start] = String.fromCharCodes(curStringBytes);
        curStringBytes.clear();
        start = offset + 1; // Skip null byte
      } else {
        curStringBytes.add(c);
      }

      offset++;
    }

    // Shouldn't happen, but just in case
    if (curStringBytes.isNotEmpty) {
      strings[start] = String.fromCharCodes(curStringBytes);   
    }

    return StringTable(size: size, strings: strings);
  }
}
