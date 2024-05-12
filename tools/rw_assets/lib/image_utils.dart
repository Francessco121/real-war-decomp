
import 'dart:typed_data';

/// Vertically flips a set of 16-bit pixel data.
Uint8List imageVerticalFlip(Uint8List bytes, int width, int height) {
  final builder = BytesBuilder(copy: false);

  int rowIdx = (width * (height - 1) * 2);
  while (rowIdx >= 0) {
    for (int colIdx = 0; colIdx < width * 2; colIdx += 2) {
      builder.addByte(bytes[rowIdx + colIdx]);
      builder.addByte(bytes[rowIdx + colIdx + 1]);
    }

    rowIdx -= width * 2;
  }

  return builder.takeBytes();
}

/// Converts `A RRRRR GGGGG BBBBB` (16-bit) to `RRRRRRRR GGGGGGGG BBBBBBBB AAAAAAAA` (32-bit).
Uint8List argb1555ToRgba8888(Uint8List bytes) {
  assert(bytes.lengthInBytes % 2 == 0);
  
  final data = ByteData.sublistView(bytes);
  final builder = BytesBuilder(copy: false);

  for (int i = 0; i < bytes.lengthInBytes; i += 2) {
    final word = data.getUint16(i, Endian.little);
    final a = (word & 0x8000) == 0 ? 255 : 0;
    final r = (((word >> 10) & 0x1F) * 255) ~/ 31;
    final g = (((word >> 5) & 0x1F) * 255) ~/ 31;
    final b = (((word >> 0) & 0x1F) * 255) ~/ 31;

    builder.addByte(r);
    builder.addByte(g);
    builder.addByte(b);
    builder.addByte(a);
  }

  return builder.takeBytes();
}

/// Converts `RRRRRRRR GGGGGGGG BBBBBBBB AAAAAAAA` (32-bit) to `A RRRRR GGGGG BBBBB` (16-bit).
Uint8List rgba8888ToArgb1555(Uint8List bytes) {
  assert(bytes.lengthInBytes % 4 == 0);
  
  final builder = BytesBuilder(copy: false);

  for (int i = 0; i < bytes.lengthInBytes; i += 4) {
    final r = (bytes[i + 0] ~/ 8) & 0x1F;
    final g = (bytes[i + 1] ~/ 8) & 0x1F;
    final b = (bytes[i + 2] ~/ 8) & 0x1F;
    final a = bytes[i + 3] == 255 ? 0 : 1;

    final word = (a << 15) | (r << 10) | (g << 5) | b;

    builder.addByte(word & 0xFF);
    builder.addByte((word >> 8) & 0xFF);
  }

  return builder.takeBytes();
}
