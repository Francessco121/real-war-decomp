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
