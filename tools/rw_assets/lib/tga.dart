import 'dart:typed_data';

const int _imageTypeUncompressedRGB = 2;

/// Creates a 16-bit Targa (TGA) file.
/// 
/// [imageData] must be 16-bit RGB bytes.
Uint8List make16BitTarga(Uint8List imageData, int width, int height,
    {bool orderTopToBottom = false}) {
  final tgaHeader = ByteData(0x12);
  tgaHeader.setUint8(0x0, 0); // idLength
  tgaHeader.setUint8(0x1, 0); // colorMapType
  tgaHeader.setUint8(0x2, _imageTypeUncompressedRGB); // imageType
  tgaHeader.setUint16(0x3, 0, Endian.little); // colorMapSpec.entryIndex
  tgaHeader.setUint16(0x5, 0, Endian.little); // colorMapSpec.entryLength
  tgaHeader.setUint8(0x7, 0); // colorMapSpec.bpp
  tgaHeader.setUint16(0x8, 0, Endian.little); // imageSpec.xOrigin
  tgaHeader.setUint16(0xA, 0, Endian.little); // imageSpec.yOrigin
  tgaHeader.setUint16(0xC, width, Endian.little); // imageSpec.width
  tgaHeader.setUint16(0xE, height, Endian.little); // imageSpec.height
  tgaHeader.setUint8(0x10, 16); // imageSpec.depth
  tgaHeader.setUint8(0x11, ((orderTopToBottom ? 1 : 0) << 5) | 1); // imageSpec.imageDesc

  final tgaFooter = ByteData(0x1A);
  tgaFooter.setUint32(0x0, 0, Endian.little); // extensionOffset
  tgaFooter.setUint32(0x4, 0, Endian.little); // developerDirectoryOffset
  for (final (i, c) in "TRUEVISION-XFILE.\u{00}".codeUnits.indexed) { // signature
    tgaFooter.setUint8(0x8 + i, c);
  }

  final tgaBytes = BytesBuilder(copy: false);
  tgaBytes.add(tgaHeader.buffer.asUint8List());
  tgaBytes.add(imageData);
  tgaBytes.add(tgaFooter.buffer.asUint8List());

  return tgaBytes.takeBytes();
}
