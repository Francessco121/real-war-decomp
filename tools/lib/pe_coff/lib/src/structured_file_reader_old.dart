// TODO: bring back RandomAccessFile based reader

// import 'dart:io';
// import 'dart:math';
// import 'dart:typed_data';

// const int _defaultFileChunkSize = 8192;

// class EndOfFileException implements Exception {}

// // TODO: instead of source classes, do separate sub classes for file vs list
// // the list version can be soooo much faster since it doesn't need chunking.
// // Users should basically choose memory efficiency over speed when choosing
// // between the two. Most use cases will probably pre-load entire files into RAM.
// // Also, don't expose this class.

// // Implementation notes:
// // - skip and setPosition could be more efficient. For files, they don't
// // make good use of chunked data. large skip values and frequent setPosition
// // calls do more IO than what is actually required.

// class StructuredFileReader {
//   /// A list of byte chunks that have been buffered but have not been
//   /// reached yet.
//   final List<ByteData> _chunkQueue = [];

//   /// The current byte buffer data view.
//   ///
//   /// This does not represent the entire byte stream being read, just
//   /// the current chunk that is loaded into memory by this reader.
//   ByteData _data = ByteData(0);

//   /// Current byte offset into the current buffer.
//   int _offset = 0;

//   /// Current number of available bytes from the current [_offset].
//   int _availableBytes = 0;

//   /// Default endian to read data as.
//   final Endian _endian;

//   /// Temporary buffer for interpreting bytes across chunk boundaries.
//   ///
//   /// Bytes from each chunk across the boundary will be copied here,
//   /// and the final number will be interpreted from that data.
//   final _tempBuffer = Uint8List(8);
//   late final ByteData _tempData = ByteData.sublistView(_tempBuffer);

//   final _ByteDataSource _source;

//   StructuredFileReader._(this._source, {required Endian? endian})
//       : _endian = endian ?? Endian.big;

//   /// Creates a byte reader over a [file] starting at its current byte position.
//   ///
//   /// Any IO required will be performed synchronously.
//   ///
//   /// IMPORTANT: Do not manually change the [file]'s byte position while using
//   /// this reader! Use [setPosition] instead.
//   /// 
//   /// Defaults to big [endian].
//   factory StructuredFileReader.file(RandomAccessFile file,
//       {int? chunkSize, Endian? endian}) {
//     return StructuredFileReader._(
//         _FileByteDataSource(file,
//             chunkSize: chunkSize ?? _defaultFileChunkSize),
//         endian: endian);
//   }

//   /// Creates a byte reader over a [list] of bytes that are already loaded
//   /// into memory.
//   /// 
//   /// Defaults to big [endian].
//   factory StructuredFileReader.list(Uint8List list, {Endian? endian}) {
//     return StructuredFileReader._(_ListByteDataSource(list), endian: endian);
//   }

//   /// Jumps to the absolute file [position].
//   void setPosition(int position) {
//     _data = ByteData(0);
//     _offset = 0;
//     _availableBytes = 0;
//     _chunkQueue.clear();

//     _source.setPosition(position);
//   }

//   /// Skips the given number of [bytes].
//   void skip(int bytes) {
//     _advance(bytes);

//     while (_offset > _data.lengthInBytes) {
//       if (_chunkQueue.isEmpty) {
//         final chunk = _source.nextChunk();
//         if (chunk == null || chunk.isEmpty) {
//           throw EndOfFileException();
//         }

//         _chunkQueue.add(ByteData.sublistView(chunk));
//         _availableBytes += chunk.lengthInBytes;
//       }

//       _offset -= _data.lengthInBytes;
//       _data = _chunkQueue.removeAt(0);
//     }

//     assert(_availableBytes >= 0);
//   }

//   /// Reads [length] number of bytes.
//   Uint8List readBytes(int length) {
//     final bytes = Uint8List(length);
//     int i = 0;

//     while (i < length) {
//       if (_offset >= _data.lengthInBytes) {
//         if (_chunkQueue.isEmpty) {
//           final chunk = _source.nextChunk();
//           if (chunk == null || chunk.isEmpty) {
//             throw EndOfFileException();
//           }

//           _data = ByteData.sublistView(chunk);
//           _availableBytes += chunk.lengthInBytes;
//         } else {
//           _data = _chunkQueue.removeAt(0);
//         }
//       }

//       int toRead = min(_data.lengthInBytes - _offset, length - i);
//       for (final b in _data.buffer.asUint8List(_offset, toRead)) {
//         bytes[i++] = b;
//       }

//       _offset += toRead;
//       _availableBytes -= toRead;
//     }

//     return bytes;
//   }

//   /// Reads and advances the next byte as an unsigned 8-bit integer.
//   int readUint8() {
//     _bufferBytes(1);

//     final int value = _data.getUint8(_offset);

//     _advance(1);
//     return value;
//   }

//   /// Reads and advances the next byte as a signed 8-bit integer.
//   int readInt8() {
//     _bufferBytes(1);

//     final int value = _data.getInt8(_offset);

//     _advance(1);
//     return value;
//   }

//   /// Reads and advances the next 2 bytes as an unsigned 16-bit integer.
//   int readUint16([Endian? endian]) {
//     _bufferBytes(2);

//     final int value;
//     if (_offset + 2 <= _data.lengthInBytes) {
//       value = _data.getUint16(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(2);
//       value = _tempData.getUint16(0, endian ?? _endian);
//     }

//     _advance(2);
//     return value;
//   }

//   /// Reads and advances the next 2 bytes as a signed 16-bit integer.
//   int readInt16([Endian? endian]) {
//     _bufferBytes(2);

//     final int value;
//     if (_offset + 2 <= _data.lengthInBytes) {
//       value = _data.getInt16(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(2);
//       value = _tempData.getInt16(0, endian ?? _endian);
//     }

//     _advance(2);
//     return value;
//   }

//   /// Reads and advances the next 4 bytes as an unsigned 32-bit integer.
//   int readUint32([Endian? endian]) {
//     _bufferBytes(4);

//     final int value;
//     if (_offset + 4 <= _data.lengthInBytes) {
//       value = _data.getUint32(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(4);
//       value = _tempData.getUint32(0, endian ?? _endian);
//     }

//     _advance(4);
//     return value;
//   }

//   /// Reads and advances the next 4 bytes as a signed 32-bit integer.
//   int readInt32([Endian? endian]) {
//     _bufferBytes(4);

//     final int value;
//     if (_offset + 4 <= _data.lengthInBytes) {
//       value = _data.getInt32(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(4);
//       value = _tempData.getInt32(0, endian ?? _endian);
//     }

//     _advance(4);
//     return value;
//   }

//   /// Reads and advances the next 8 bytes as an unsigned 64-bit integer.
//   int readUint64([Endian? endian]) {
//     _bufferBytes(8);

//     final int value;
//     if (_offset + 8 <= _data.lengthInBytes) {
//       value = _data.getUint64(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(8);
//       value = _tempData.getUint64(0, endian ?? _endian);
//     }

//     _advance(8);
//     return value;
//   }

//   /// Reads and advances the next 8 bytes as a signed 64-bit integer.
//   int readInt64([Endian? endian]) {
//     _bufferBytes(8);

//     final int value;
//     if (_offset + 8 <= _data.lengthInBytes) {
//       value = _data.getInt64(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(8);
//       value = _tempData.getInt64(0, endian ?? _endian);
//     }

//     _advance(8);
//     return value;
//   }

//   /// Reads and advances the next 4 bytes as a 32-bit single-precision floating point number.
//   double readFloat32([Endian? endian]) {
//     _bufferBytes(4);

//     final double value;
//     if (_offset + 4 <= _data.lengthInBytes) {
//       value = _data.getFloat32(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(4);
//       value = _tempData.getFloat32(0, endian ?? _endian);
//     }

//     _advance(4);
//     return value;
//   }

//   /// Reads and advances the next 8 bytes as a 32-bit single-precision floating point number.
//   double readFloat64([Endian? endian]) {
//     _bufferBytes(8);

//     final double value;
//     if (_offset + 8 <= _data.lengthInBytes) {
//       value = _data.getFloat64(_offset, endian ?? _endian);
//     } else {
//       _loadTempData(8);
//       value = _tempData.getFloat64(0, endian ?? _endian);
//     }

//     _advance(8);
//     return value;
//   }

//   void _loadTempData(int bytes) {
//     final nextChunk = _chunkQueue.first;
//     _tempBuffer.setAll(
//         0,
//         _data.buffer.asUint8List(_offset).followedBy(Uint8List.view(
//             nextChunk.buffer, 0, bytes - (_data.lengthInBytes - _offset))));
//   }

//   void _advance(int bytes) {
//     _offset += bytes;
//     _availableBytes -= bytes;
//   }

//   /// Attempts to make at least the given number of [bytes] available from
//   /// this reader.
//   ///
//   /// If the number of [bytes] couldn't be reached, throws an
//   /// [EndOfFileException].
//   void _bufferBytes(int bytes) {
//     while (_availableBytes < bytes) {
//       final chunk = _source.nextChunk();
//       if (chunk == null || chunk.isEmpty) {
//         throw EndOfFileException();
//       }

//       _chunkQueue.add(ByteData.sublistView(chunk));
//       _availableBytes += chunk.lengthInBytes;
//     }

//     while (_offset >= _data.lengthInBytes) {
//       // I don't think this can ever happen, but check it just in case...
//       if (_chunkQueue.isEmpty) {
//         throw EndOfFileException();
//       }

//       _offset -= _data.lengthInBytes;
//       _data = _chunkQueue.removeAt(0);
//     }
//   }
// }

// abstract class _ByteDataSource {
//   Uint8List? nextChunk();
//   void setPosition(int position);
// }

// class _FileByteDataSource implements _ByteDataSource {
//   bool _eof = false;
//   final int _chunkSize;
//   final RandomAccessFile _file;

//   _FileByteDataSource(this._file, {required int chunkSize})
//       : _chunkSize = chunkSize {
//     if (chunkSize < 8) {
//       throw ArgumentError.value(
//           chunkSize, 'chunkSize', 'Chunk size must be at least 8.');
//     }
//   }

//   @override
//   Uint8List? nextChunk() {
//     if (_eof) {
//       return null;
//     }

//     final chunk = Uint8List(_chunkSize);
//     final read = _file.readIntoSync(chunk);

//     if (read < _chunkSize) {
//       _eof = true;
//       return Uint8List.sublistView(chunk, 0, read);
//     } else {
//       _file.setPositionSync(_file.positionSync() + read);
//       return chunk;
//     }
//   }

//   @override
//   void setPosition(int position) {
//     _eof = false;
//     _file.setPositionSync(position);
//   }
// }

// class _ListByteDataSource implements _ByteDataSource {
//   int _offset = 0;
//   bool _read = false;
//   final Uint8List _bytes;

//   _ListByteDataSource(this._bytes);

//   @override
//   Uint8List? nextChunk() {
//     if (_read) {
//       return null;
//     } else {
//       _read = true;

//       if (_offset == 0) {
//         return _bytes;
//       } else {
//         return Uint8List.sublistView(_bytes, _offset);
//       }
//     }
//   }

//   @override
//   void setPosition(int position) {
//     _read = false;
//     _offset = position;
//   }
// }
