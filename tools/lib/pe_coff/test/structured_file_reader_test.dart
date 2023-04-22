@Skip()
library;

// import 'dart:typed_data';

// import 'package:file/file.dart';
// import 'package:file/memory.dart';
// import 'package:pe_coff/src/structured_file_reader.dart';
// import 'package:test/test.dart';

import 'package:test/test.dart';

void main() {
//   late MemoryFileSystem fs;

//   setUp(() {
//     fs = MemoryFileSystem();
//   });

//   test('can read in memory lists', () {
//     var data = ByteData(8);
//     data.setFloat32(0, 3.140000104904175);
//     data.setInt8(4, -1);
//     data.setUint16(5, 24);
//     data.setUint8(7, 255);

//     var reader = StructuredFileReader.list(data.buffer.asUint8List());

//     expect(reader.readFloat32(), 3.140000104904175);
//     expect(reader.readInt8(), -1);
//     expect(reader.readUint16(), 24);
//     expect(reader.readUint8(), 255);
//   });

//   test('can read files', () {
//     final file = fs.file('test.bin');
//     var data = ByteData(8);
//     data.setFloat32(0, 3.140000104904175);
//     data.setInt8(4, -1);
//     data.setUint16(5, 24);
//     data.setUint8(7, 255);
//     file.writeAsBytesSync(data.buffer.asUint8List());

//     var randomAccess = file.openSync(mode: FileMode.read);
//     var reader = StructuredFileReader.file(randomAccess);

//     expect(reader.readFloat32(), 3.140000104904175);
//     expect(reader.readInt8(), -1);
//     expect(reader.readUint16(), 24);
//     expect(reader.readUint8(), 255);
//   });

//   test('can read chunked files', () {
//     final file = fs.file('test.bin');
//     var data = ByteData(16);
//     data.setFloat32(0, 3.140000104904175);
//     data.setInt8(4, -1);
//     data.setUint16(8, 24);
//     data.setUint8(10, 255);
//     file.writeAsBytesSync(data.buffer.asUint8List());

//     var randomAccess = file.openSync(mode: FileMode.read);
//     var reader = StructuredFileReader.file(randomAccess, chunkSize: 8);

//     expect(reader.readFloat32(), 3.140000104904175);
//     expect(reader.readInt8(), -1);
//     reader.skip(3);
//     expect(reader.readUint16(), 24);
//     expect(reader.readUint8(), 255);
//   });

//   test('can skip', () {
//     final file = fs.file('test.bin');
//     var data = ByteData(32);
//     data.setInt32(21, 121);
//     file.writeAsBytesSync(data.buffer.asUint8List());

//     var randomAccess = file.openSync(mode: FileMode.read);
//     var reader = StructuredFileReader.file(randomAccess, chunkSize: 8);
//     reader.skip(21);

//     expect(reader.readInt32(), 121);
//   });

//   test('can skip to chunk edge and read', () {
//     final file = fs.file('test.bin');
//     var data = ByteData(16);
//     data.setInt32(8, 121);
//     file.writeAsBytesSync(data.buffer.asUint8List());

//     var randomAccess = file.openSync(mode: FileMode.read);
//     var reader = StructuredFileReader.file(randomAccess, chunkSize: 8);
//     reader.skip(8);

//     expect(reader.readInt32(), 121);
//   });

//   test('can read across file chunk boundaries', () {
//     final file = fs.file('test.bin');
//     var data = ByteData(16);
//     data.setInt16(7, 121);
//     file.writeAsBytesSync(data.buffer.asUint8List());

//     var randomAccess = file.openSync(mode: FileMode.read);
//     var reader = StructuredFileReader.file(randomAccess, chunkSize: 8);
//     reader.skip(7);

//     expect(reader.readInt16(), 121);
//   });

//   test('throws exception on eof on read', () {
//     var data = ByteData(8);

//     var reader = StructuredFileReader.list(data.buffer.asUint8List());
//     reader.skip(8);

//     expect(reader.readFloat32, throwsA(isA<EndOfFileException>()));
//   });

//   test('throws exception on eof on skip', () {
//     var data = ByteData(8);

//     var reader = StructuredFileReader.list(data.buffer.asUint8List());

//     expect(() => reader.skip(9), throwsA(isA<EndOfFileException>()));
//   });
}
