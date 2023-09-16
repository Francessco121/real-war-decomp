import 'dart:typed_data';

/// While the technical max run length is 32767 (0x7FFF, MS bit is reserved 
/// for the control word type), the longest run in any of game's TGC files
/// is only 4096.
const _maxRunLength = 4096;

/// Descriptor for a Targa Compressed (TGC) file.
/// 
/// TGC files store 16-bit truecolor pixel data where the R, G, and B
/// components take up 5-bits each and the highest bit denotes alpha.
/// This pixel data flows left-to-right top-to-bottom and is run-length
/// encoded.
/// 
/// Pixel format:
/// ARRRRRGGGGGBBBBB 
class TgcFile {
  /// File pointer to run-length encoded 16-bit truecolor ARGB pixel data.
  static const int rleDataOffset = 4;

  final int width;
  final int height;

  TgcFile(this.width, this.height);

  factory TgcFile.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    
    return TgcFile(
        data.getUint16(0, Endian.little), 
        data.getUint16(2, Endian.little));
  }
}

/// Makes a TGC file from a [descriptor] and 16-bit [rgbBytes].
/// 
/// Pixels must be in top-to-bottom order.
Uint8List makeTgc(TgcFile descriptor, Uint8List rgbBytes) {
  final tgcBytes = BytesBuilder(copy: false);
  tgcBytes.addByte(descriptor.width & 0xFF);
  tgcBytes.addByte((descriptor.width >> 8) & 0xFF);
  tgcBytes.addByte(descriptor.height & 0xFF);
  tgcBytes.addByte((descriptor.height >> 8) & 0xFF);
  tgcBytes.add(tgcRleEncode(rgbBytes));

  return tgcBytes.takeBytes();
}

/// Reads a TGC files and decodes its RGB bytes.
(TgcFile, Uint8List) readTgc(Uint8List tgcBytes) {
  final descriptor = TgcFile.fromBytes(tgcBytes);
  final rgbBytes = tgcRleDecode(
      Uint8List.sublistView(tgcBytes, TgcFile.rleDataOffset));
  
  return (descriptor, rgbBytes);
}

/// Decode TGC run-length encoded 16-bit truecolor ARGB pixel data.
Uint8List tgcRleDecode(Uint8List rleBytes) {
  assert(rleBytes.lengthInBytes % 2 == 0);

  final data = ByteData.sublistView(rleBytes);

  final out = BytesBuilder(copy: false);
  int inIdx = 0; // This is in bytes, but we read in words
  
  while (true) {
    // Next control word
    final ctrl = data.getUint16(inIdx, Endian.little);
    inIdx += 2;

    // 0xFFFF marks end of string
    if (ctrl == 0xFFFF) {
      break;
    }

    final sequenceLen = ctrl & 0x7FFF;

    // Check MSB
    if ((ctrl & 0x8000) != 0) {
      // Copy next n words as is
      out.add(Uint8List.sublistView(data, inIdx, inIdx + sequenceLen * 2));

      inIdx += sequenceLen * 2;
    } else {
      // Repeat next word n number of times
      final wordLSB = data.getUint8(inIdx);
      final wordMSB = data.getUint8(inIdx + 1);
      for (int i = 0; i < sequenceLen; i++) {
        out.addByte(wordLSB);
        out.addByte(wordMSB);
      }

      inIdx += 2;
    }
  }

  return out.takeBytes();
}

Uint8List tgcRleEncode(Uint8List rgbBytes) {
  assert(rgbBytes.lengthInBytes % 2 == 0);

  final data = ByteData.sublistView(rgbBytes);
  
  final out = BytesBuilder(copy: false);
  int i = 0;
  int runStart = 0;
  bool? repeatRun;
  int? lastPixel;

  void writeRepeatRun(int length, int pixel) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'Run length must be greater than zero.');
    }

    out.addByte(length & 0xFF);
    out.addByte((length >> 8) & 0x7F);

    out.addByte(pixel & 0xFF);
    out.addByte((pixel >> 8) & 0xFF);
  }

  void writeLiteralRun(int start, int length) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'Run length must be greater than zero.');
    }

    out.addByte(length & 0xFF);
    out.addByte(((length >> 8) & 0x7F) | (1 << 7));

    out.add(Uint8List.sublistView(rgbBytes, start, start + length * 2));
  }

  while (i < rgbBytes.length) {
    final pixel = data.getUint16(i, Endian.little);
    
    if (lastPixel != null) {
      if (repeatRun == null) {
        // Start of run, determine type
        repeatRun = pixel == lastPixel;
      } else {
        final runLength = (i - runStart) ~/ 2;

        if (repeatRun && (runLength >= _maxRunLength || pixel != lastPixel)) {
          // End of repeat run
          writeRepeatRun(runLength, lastPixel);
          runStart = i;
          repeatRun = null;
        } else if (!repeatRun && (runLength >= _maxRunLength || pixel == lastPixel)) {
          // End of literal run
          writeLiteralRun(runStart, runLength);
          runStart = i;
          repeatRun = null;
        }
      }
    }

    i += 2;
    lastPixel = pixel;
  }

  if (i > runStart) {
    if (repeatRun == true) {
      writeRepeatRun((i - runStart) ~/ 2, lastPixel!);
    } else {
      writeLiteralRun(runStart, (i - runStart) ~/ 2);
    }
  }

  // End of string marker
  out.addByte(0xFF);
  out.addByte(0xFF);

  return out.takeBytes();
}

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
    final r = ((word >> 10) & 0x1F) * 8;
    final g = ((word >> 5) & 0x1F) * 8;
    final b = ((word >> 0) & 0x1F) * 8;

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
