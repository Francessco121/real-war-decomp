import 'dart:typed_data';

import 'src/rle.dart';

/// While the technical max run length is 32767 (0x7FFF, MS bit is reserved 
/// for the control word type), the longest run in any of game's TGC files
/// is only 4096.
const _maxRunLength = 4096;

/// File pointer to RLE data section of all TGC files.
const _rleDataOffset = 4;

/// Header for a Targa Compressed (TGC) file.
/// 
/// TGC files store 16-bit truecolor pixel data where the R, G, and B
/// components take up 5-bits each and the highest bit denotes alpha.
/// This pixel data flows left-to-right top-to-bottom and is run-length
/// encoded.
/// 
/// Pixel format:
/// ARRRRRGGGGGBBBBB 
class TgcHeader {
  final int width;
  final int height;

  TgcHeader(this.width, this.height);

  factory TgcHeader.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    
    return TgcHeader(
        data.getUint16(0, Endian.little), 
        data.getUint16(2, Endian.little));
  }
}

/// A read TGC file with it's image data decoded into ARGB1555.
class DecodedTgcFile {
  final TgcHeader header;

  /// ARGB1555 pixel data.
  final Uint8List imageBytes;

  /// An unknown 32-bit trailer.
  final int trailer;

  DecodedTgcFile(this.header, this.imageBytes, this.trailer);
}

/// Makes a TGC file from a [header] and 16-bit [rgbBytes].
/// 
/// Pixels must be in top-to-bottom order.
Uint8List makeTgc(TgcHeader header, Uint8List rgbBytes) {
  final tgcBytes = BytesBuilder(copy: false);
  // Header
  tgcBytes.addByte(header.width & 0xFF);
  tgcBytes.addByte((header.width >> 8) & 0xFF);
  tgcBytes.addByte(header.height & 0xFF);
  tgcBytes.addByte((header.height >> 8) & 0xFF);
  // RLE image data
  tgcBytes.add(rleEncode16(rgbBytes, maxRunLength: _maxRunLength));
  // Trailer
  //
  // It's unknown what this is supposed to be. The game files have a 4 byte trailer
  // that sometimes is 0 and sometimes not, but the game itself never actually reads
  // it. So, just write zeroes to be consistent.
  tgcBytes.addByte(0);
  tgcBytes.addByte(0);
  tgcBytes.addByte(0);
  tgcBytes.addByte(0);

  return tgcBytes.takeBytes();
}

/// Reads a TGC file and decodes its RGB bytes.
DecodedTgcFile readTgc(Uint8List tgcBytes) {
  final header = TgcHeader.fromBytes(tgcBytes);
  final (imageBytes, rleByteLength) = rleDecode16(
      Uint8List.sublistView(tgcBytes, _rleDataOffset));
  
  final int trailer;
  if (_rleDataOffset + rleByteLength + 4 <= tgcBytes.lengthInBytes) {
    trailer = ByteData.sublistView(tgcBytes, _rleDataOffset + rleByteLength)
        .getUint32(0, Endian.little);
  } else {
    trailer = 0;
  }
  
  return DecodedTgcFile(header, imageBytes, trailer);
}
