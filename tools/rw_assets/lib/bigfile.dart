import 'dart:typed_data';

import 'package:charcode/ascii.dart';

import 'src/utils.dart';

/// bigfile.dat
class Bigfile {
  final List<BigfileEntry> entries;

  Bigfile(this.entries);

  factory Bigfile.fromBytes(Uint8List bytes) {
    final header = ByteData.sublistView(bytes, 0, 4);
    final entryCount = header.getUint32(0, Endian.little);

    final entries = <BigfileEntry>[];
    for (int i = 0; i < entryCount; i++) {
      int offset = (i * 0x4c) + 4;
      entries.add(BigfileEntry.fromByteData(ByteData.sublistView(bytes, offset, offset + 0x4c), offset));
    }

    return Bigfile(entries);
  }
}

class BigfileEntry {
  static const int maxPathLength = 64;
  static const int headerSize = 0x4C;

  /// Filename as a path relative to the game executable directory.
  /// 
  /// Usually should start with `DATA\`.
  final String path;
  /// An XOR hash of [path].
  final int pathHash;
  /// File pointer to this entry's data.
  final int byteOffset;
  /// Byte size of this entry's data.
  final int sizeBytes;

  BigfileEntry({
    required this.path,
    required this.pathHash,
    required this.byteOffset,
    required this.sizeBytes,
  });

  BigfileEntry.fromByteData(ByteData data, int offset)
      : path = readNullTerminatedOrFullString(data.buffer.asUint8List(offset, 64)),
        pathHash = data.getUint32(64, Endian.little),
        byteOffset = data.getUint32(68, Endian.little),
        sizeBytes = data.getUint32(72, Endian.little);
  
  Uint8List toBytes() {
    if (path.length > maxPathLength) {
      throw StateError('Path $path is too long!');
    }

    final pathCodeUnits = path.codeUnits;
    
    final data = ByteData(headerSize);
    for (int i = 0; i < maxPathLength && i < path.length; i++) {
      data.setUint8(i, pathCodeUnits[i]);
    }

    data.setUint32(64, pathHash, Endian.little);
    data.setUint32(68, byteOffset, Endian.little);
    data.setUint32(72, sizeBytes, Endian.little);

    return data.buffer.asUint8List();
  }
}

/// Computes the XOR hash of a [path] for a bigfile entry.
int computeBigfileEntryPathHash(String path) {
  final codeUnits = path.codeUnits;
  
  int hash = 0;
  int pos = 0;
  
  while (pos < codeUnits.length) {
    final int dword;
    (pos, dword) = _packDword(codeUnits, pos);

    hash ^= dword;
  }

  return hash;
}

(int newPos, int dword) _packDword(List<int> codeUnits, int pos) {
  final ints = List<int>.filled(4, 0);

  for (int i = 0; i < 4; i++) {
    int c = pos >= codeUnits.length ? 0 : codeUnits[pos];

    // To uppercase
    if (c >= $a && c <= $z) {
      c = c & 0xdf;
    }

    // Substitute ':' for '/' and '\'
    ints[i] = (c == $backslash || c == $slash) ? $colon : c;

    // Only increment if not at the end of the string,
    // but don't break the loop since we still need 4 values
    if (pos < codeUnits.length) {
      pos++;
    }
  }

  // Pack
  final dword = ints[0] | (ints[1] << 8) | (ints[2] << 16) | (ints[3] << 24);
  return (pos, dword);
}
