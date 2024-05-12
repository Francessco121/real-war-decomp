import 'dart:typed_data';

/// Makes all fully black (0,0,0) pixels transparent.
/// 
/// Expects ARGB1555 pixel data.
void maskOutBlackPixels(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);

  for (int i = 0; i < bytes.lengthInBytes; i += 2) {
    final pixel = data.getUint16(i, Endian.little);

    int a = (pixel >> 15) & 0x1;
    int r = (pixel >> 10) & 0x1F;
    int g = (pixel >> 5) & 0x1F;
    int b = (pixel >> 0) & 0x1F;

    if (a != 1 && r == 0 && g == 0 && b == 0) {
      a = 1;
    }

    data.setUint16(i, (a << 15) | (r << 10) | (g << 5) | (b), Endian.little);
  }
}