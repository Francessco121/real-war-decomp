import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rw_assets/tgc.dart';
import 'package:test/test.dart';

void main() {
  test('tgcRleEncode', () {
    final testImageFile = File(p.join(p.current, 'test/test.tga'));
    final testImageData = _getTgaImageData(testImageFile.readAsBytesSync());

    final encoded = tgcRleEncode(testImageData);
    final (decoded, _) = tgcRleDecode(encoded);

    expect(decoded, equals(testImageData));
  });
}

Uint8List _getTgaImageData(Uint8List tgaBytes) {
  final data = ByteData.sublistView(tgaBytes);
  final imageType = data.getUint8(0x2);
  final width = data.getUint16(0xC, Endian.little);
  final height = data.getUint16(0xE, Endian.little);
  final depth = data.getUint8(0x10);
  final imageDesc = data.getUint8(0x11);
  final imageData = Uint8List.sublistView(tgaBytes, 0x12, 0x12 + (width * height * 2));

  assert(imageType == 2);
  assert(depth == 16);

  final isTopToBottom = (imageDesc & 0x20) != 0;

  if (isTopToBottom) {
    return imageData;
  } else {
    return imageVerticalFlip(imageData, width, height);
  }
}
