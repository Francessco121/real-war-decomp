import 'dart:typed_data';

import 'src/rle.dart';

/// File pointer to the start of the SPT frames.
const _framesOffset = 4;

/// Header for a Sprite Table (SPT) file.
/// 
/// SPT files store a set of frames containing 16-bit truecolor pixel data
/// where the R, G, and B components take up 5-bits each and the highest bit
/// denotes alpha. This pixel data flows left-to-right top-to-bottom and is 
/// *optionally* run-length encoded.
class SptHeader {
  /// Whether each frame's pixel data is run-length encoded.
  final bool isRle;
  /// The total number of frames.
  final int frameCount;

  SptHeader({
    required this.isRle, 
    required this.frameCount,
  });

  factory SptHeader.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final dword = data.getUint32(0, Endian.little);
    
    return SptHeader(
        isRle: (dword & 0x80000000) != 0,
        frameCount: dword & 0x3fffffff);
  }
}

/// A single frame of an SPT file.
class SptFrame {
  /// Width in pixels.
  final int width;
  /// Height in pixels.
  final int height;
  /// ARGB1555 pixel data.
  final Uint8List imageBytes;

  SptFrame({
    required this.width,
    required this.height,
    required this.imageBytes,
  });
}

/// A read SPT file.
class DecodedSptFile {
  final SptHeader header;
  final List<SptFrame> frames;

  DecodedSptFile(this.header, this.frames);
}

/// Reads an SPT file, decoding each frame if it was run-length encoded.
DecodedSptFile readSpt(Uint8List sptBytes) {
  final data = ByteData.sublistView(sptBytes);

  final header = SptHeader.fromBytes(sptBytes);
  final frames = <SptFrame>[];

  for (int i = 0; i < header.frameCount; i++) {
    final framePointer = data.getUint32(_framesOffset + (i * 4), Endian.little);

    final width = data.getUint32(framePointer + 0, Endian.little);
    final height = data.getUint32(framePointer + 4, Endian.little);
    final imageBytes = _readSptFrame(sptBytes, framePointer + 8, 
        width: width,
        height: height,
        isRle: header.isRle);

    frames.add(SptFrame(width: width, height: height, imageBytes: imageBytes));
  }

  return DecodedSptFile(header, frames);
}

Uint8List _readSptFrame(Uint8List sptBytes, int startOffset, {
  required int width,
  required int height,
  required bool isRle
}) {
  if (isRle) {
    return rleDecode16(Uint8List.sublistView(sptBytes, startOffset)).$1;
  } else {
    final byteLength = width * height * 2;
    return sptBytes.sublist(startOffset, startOffset + byteLength);
  }
}
