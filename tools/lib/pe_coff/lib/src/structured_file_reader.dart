import 'dart:typed_data';

class EndOfFileException implements Exception {}

abstract class StructuredFileReader {
  /// Gets the current file byte position.
  int get position;
  
  /// Creates a new [StructuredFileReader] over a file loaded into memory as a [list].
  factory StructuredFileReader.list(Uint8List list, {Endian endian = Endian.big}) {
    return _ListBasedStructuredFileReader(list, endian: endian);
  }
  
  /// Jumps to the absolute file [position].
  void setPosition(int position);

  /// Skips the given number of [bytes].
  void skip(int bytes);

  /// Reads [length] number of bytes.
  Uint8List readBytes(int length);

  /// Reads and advances the next byte as an unsigned 8-bit integer.
  int readUint8();

  /// Reads and advances the next byte as a signed 8-bit integer.
  int readInt8();

  /// Reads and advances the next 2 bytes as an unsigned 16-bit integer.
  int readUint16([Endian? endian]);

  /// Reads and advances the next 2 bytes as a signed 16-bit integer.
  int readInt16([Endian? endian]);

  /// Reads and advances the next 4 bytes as an unsigned 32-bit integer.
  int readUint32([Endian? endian]);

  /// Reads and advances the next 4 bytes as a signed 32-bit integer.
  int readInt32([Endian? endian]);

  /// Reads and advances the next 8 bytes as an unsigned 64-bit integer.
  int readUint64([Endian? endian]);

  /// Reads and advances the next 8 bytes as a signed 64-bit integer.
  int readInt64([Endian? endian]);

  /// Reads and advances the next 4 bytes as a 32-bit single-precision floating point number.
  double readFloat32([Endian? endian]);

  /// Reads and advances the next 8 bytes as a 32-bit single-precision floating point number.
  double readFloat64([Endian? endian]);
}
class _ListBasedStructuredFileReader implements StructuredFileReader {
  @override
  int get position => _offset;

  /// Current byte offset.
  int _offset = 0;

  /// Default endian to read data as.
  final Endian _endian;

  final ByteData _data;
  final Uint8List _source;

  _ListBasedStructuredFileReader(this._source, {required Endian endian})
      : _endian = endian,
        _data = ByteData.sublistView(_source);

  /// Jumps to the absolute file [position].
  @override
  void setPosition(int position) {
    _offset = position;
  }

  /// Skips the given number of [bytes].
  @override
  void skip(int bytes) {
    _offset += bytes;

    if (_offset > _source.lengthInBytes) {
      throw EndOfFileException();
    }
  }

  /// Reads [length] number of bytes.
  @override
  Uint8List readBytes(int length) {
    if (_offset + length > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final bytes = Uint8List.sublistView(_source, _offset, _offset + length);
    _advance(length);
    
    return bytes;
  }

  /// Reads and advances the next byte as an unsigned 8-bit integer.
  @override
  int readUint8() {
    if (_offset + 1 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getUint8(_offset);

    _advance(1);
    return value;
  }

  /// Reads and advances the next byte as a signed 8-bit integer.
  @override
  int readInt8() {
    if (_offset + 1 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getInt8(_offset);

    _advance(1);
    return value;
  }

  /// Reads and advances the next 2 bytes as an unsigned 16-bit integer.
  @override
  int readUint16([Endian? endian]) {
    if (_offset + 2 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getUint16(_offset, endian ?? _endian);

    _advance(2);
    return value;
  }

  /// Reads and advances the next 2 bytes as a signed 16-bit integer.
  @override
  int readInt16([Endian? endian]) {
    if (_offset + 2 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getInt16(_offset, endian ?? _endian);

    _advance(2);
    return value;
  }

  /// Reads and advances the next 4 bytes as an unsigned 32-bit integer.
  @override
  int readUint32([Endian? endian]) {
    if (_offset + 4 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getUint32(_offset, endian ?? _endian);

    _advance(4);
    return value;
  }

  /// Reads and advances the next 4 bytes as a signed 32-bit integer.
  @override
  int readInt32([Endian? endian]) {
    if (_offset + 4 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getInt32(_offset, endian ?? _endian);

    _advance(4);
    return value;
  }

  /// Reads and advances the next 8 bytes as an unsigned 64-bit integer.
  @override
  int readUint64([Endian? endian]) {
    if (_offset + 8 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getUint64(_offset, endian ?? _endian);

    _advance(8);
    return value;
  }

  /// Reads and advances the next 8 bytes as a signed 64-bit integer.
  @override
  int readInt64([Endian? endian]) {
    if (_offset + 8 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final int value = _data.getInt64(_offset, endian ?? _endian);

    _advance(8);
    return value;
  }

  /// Reads and advances the next 4 bytes as a 32-bit single-precision floating point number.
  @override
  double readFloat32([Endian? endian]) {
    if (_offset + 4 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final double value = _data.getFloat32(_offset, endian ?? _endian);

    _advance(4);
    return value;
  }

  /// Reads and advances the next 8 bytes as a 32-bit single-precision floating point number.
  @override
  double readFloat64([Endian? endian]) {
    if (_offset + 8 > _source.lengthInBytes) {
      throw EndOfFileException();
    }

    final double value = _data.getFloat64(_offset, endian ?? _endian);

    _advance(8);
    return value;
  }

  void _advance(int bytes) {
    _offset += bytes;
  }
}
