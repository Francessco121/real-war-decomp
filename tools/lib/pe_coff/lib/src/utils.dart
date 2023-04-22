import 'dart:typed_data';

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
