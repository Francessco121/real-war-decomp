import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class FileData {
  Pointer<Uint8> get dataPtr {
    if (_freed) {
      throw StateError('This file data has been freed.');
    }

    return _dataPtr;
  }

  Uint8List get data {
    if (_freed) {
      throw StateError('This file data has been freed.');
    }

    return _data;
  }

  final int size;
  
  bool _freed = false;

  final Pointer<Uint8> _dataPtr;
  final Uint8List _data;

  FileData._(this._dataPtr, this._data, this.size);

  factory FileData.read(RandomAccessFile file, int offset, int length) {
    final dataPtr = malloc<Uint8>(length);
    final data = dataPtr.asTypedList(length);

    file.setPositionSync(offset);
    file.readIntoSync(data);

    return FileData._(dataPtr, data, length);
  }

  factory FileData.fromList(Uint8List list) {
    final dataPtr = malloc<Uint8>(list.lengthInBytes);
    for (int i = 0; i < list.lengthInBytes; i++) {
      dataPtr[i] = list[i];
    }

    return FileData._(dataPtr, list, list.lengthInBytes);
  }

  void free() {
    if (!_freed) {
      malloc.free(_dataPtr);
      _freed = true;
    }
  }
}
