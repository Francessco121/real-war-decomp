import 'dart:typed_data';

/// Decode 16-bit run-length encoded data.
(Uint8List outBytes, int readBytes) rleDecode16(Uint8List rleBytes) {
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

  // Skip 0xFFFFFFFF end marker
  // (we already parsed the first half, skip the second half if it exists)
  if (inIdx + 2 <= data.lengthInBytes) {
    inIdx += 2;
  }

  return (out.takeBytes(), inIdx);
}

/// Encode 16-bit data with run-length encoding.
Uint8List rleEncode16(Uint8List rgbBytes, {int maxRunLength = 0x7FFF}) {
  assert(rgbBytes.lengthInBytes % 2 == 0);

  final data = ByteData.sublistView(rgbBytes);
  
  final out = BytesBuilder(copy: false);
  int i = 0;
  int runStart = 0;
  bool repeatRun = false;
  int? lastPixel;
  int matches = 0;

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
      final runLength = (i - runStart) ~/ 2;

      if (!repeatRun) {
        if (matches != -1) {
          if (pixel == lastPixel) {
            matches++;

            if (matches >= 3) {
              // 3 matches at the start of the run, change into a repeat run
              repeatRun = true;
            }
          } else {
            // Run doesn't start with at least 3 matches, lock out of a repeat run
            matches = -1;
          }
        } else if (pixel == lastPixel || runLength >= maxRunLength) {
          // Potential repeat run start or run is too long, break
          writeLiteralRun(runStart, runLength);
          runStart = i;
          matches = 0;
        }
      } else {
        if (pixel != lastPixel || runLength >= maxRunLength) {
          // End of repeat run or run is too long, break
          writeRepeatRun(runLength, lastPixel);
          runStart = i;
          repeatRun = false;
          matches = 0;
        }
      }
    }

    i += 2;
    lastPixel = pixel;
  }

  if (i > runStart) {
    if (repeatRun == true || matches != -1) {
      writeRepeatRun((i - runStart) ~/ 2, lastPixel!);
    } else {
      writeLiteralRun(runStart, (i - runStart) ~/ 2);
    }
  }

  // End of string marker
  out.addByte(0xFF);
  out.addByte(0xFF);
  out.addByte(0xFF);
  out.addByte(0xFF);

  return out.takeBytes();
}
