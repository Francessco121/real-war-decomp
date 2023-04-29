import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class FileData {
  Pointer<Uint8> get data {
    if (_freed) {
      throw StateError('This file data has been freed.');
    }

    return _data;
  }

  final int size;
  
  bool _freed = false;

  final Pointer<Uint8> _data;

  FileData._(this._data, this.size);

  factory FileData.read(RandomAccessFile file, int offset, int length) {
    final data = malloc<Uint8>(length);
    file.setPositionSync(offset);
    file.readIntoSync(data.asTypedList(length));

    return FileData._(data, length);
  }

  factory FileData.fromList(Uint8List list) {
    final data = malloc<Uint8>(list.lengthInBytes);
    for (int i = 0; i < list.lengthInBytes; i++) {
      data[i] = list[i];
    }

    return FileData._(data, list.lengthInBytes);
  }

  factory FileData.fromClampedList(Uint8ClampedList list) {
    final data = malloc<Uint8>(list.lengthInBytes);
    for (int i = 0; i < list.lengthInBytes; i++) {
      data[i] = list[i];
    }

    return FileData._(data, list.lengthInBytes);
  }

  void free() {
    if (!_freed) {
      malloc.free(_data);
      _freed = true;
    }
  }
}
