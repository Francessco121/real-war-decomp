import 'dart:io';
import 'dart:typed_data';

class Entry {
  final String path;
  final int pathHash;
  final int byteOffset;
  final int sizeBytes;

  Entry(ByteData data, int offset)
      : path = readNullTerminatedOrFullString(data.buffer.asUint8List(offset, 64)),
        pathHash = data.getUint32(64, Endian.little),
        byteOffset = data.getUint32(68, Endian.little),
        sizeBytes = data.getUint32(72, Endian.little);
}

void main(List<String> args) {
  if (args.length != 2) {
    print('Usage: extract_bigfile.dart <path to bigfile.dat> <output dir>');
    return;
  }

  final bigfile = File(args[0]);
  if (!bigfile.existsSync()) {
    print('Could not find file at ${args[0]}');
    return;
  }

  final bytes = bigfile.readAsBytesSync();

  final header = ByteData.sublistView(bytes, 0, 4);
  final entryCount = header.getUint32(0, Endian.little);

  final paths = <String>{};

  final entries = <Entry>[];
  for (int i = 0; i < entryCount; i++) {
    int offset = (i * 0x4c) + 4;
    entries.add(Entry(ByteData.sublistView(bytes, offset, offset + 0x4c), offset));
  }

  for (final entry in entries) {
    var path = entry.path;
    while (paths.contains(path)) {
      path = '$path.duplicate';
    }
    paths.add(path);

    final file = File('${args[1]}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(Uint8List.sublistView(bytes, entry.byteOffset, entry.byteOffset + entry.sizeBytes));
  }

  print('Wrote files to ${args[1]}');
}

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
