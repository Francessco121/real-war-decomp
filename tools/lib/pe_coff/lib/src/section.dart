import 'dart:typed_data';

import 'line_numbers.dart';
import 'relocations.dart';
import 'section_flags.dart';
import 'structured_file_reader.dart';
import 'utils.dart';

class Section {
  /// The section header.
  final SectionHeader header;

  /// Section relocation entries.
  final List<RelocationEntry> relocations;

  /// Debugging information linking source code line numbers to symbols/addresses.
  final List<LineNumberEntry> lineNumbers;

  Section({
    required this.header,
    required this.relocations,
    required this.lineNumbers,
  });

  @override
  String toString() => header.name;
}

class SectionHeader {
  static const int byteSize = 40;

  /// The name of the section.
  final String name;

  /// The total size of the section when loaded into memory.
  /// 
  /// For Windows object files, this is always zero. For non-Windows object 
  /// files this field is instead the 'physical address', i.e. where this 
  /// section should be loaded into in memory.
  final int virtualSize;

  /// For images, this is the address of the first byte of the section relative
  /// to the image base when loaded into memory.
  /// 
  /// For objects, this field is the address of the first byte before relocation
  /// is applied, usually zero.
  final int virtualAddress;

  /// Size of the section data in bytes.
  final int sizeOfRawData;

  /// File pointer to the section data.
  final int pointerToRawData;

  /// File pointer to the section relocation entries.
  final int pointerToRelocations;

  /// File pointer to the section line number entries.
  final int pointerToLineNumbers;

  /// Number of relocation entries for the section.
  /// 
  /// If [flags.lnkNrelocOvfl] is set, this value will be 0xFFFF and the real
  /// relocation count is the relocations list length.
  final int numberOfRelocations;

  /// Number of line number entries for the section.
  final int numberOfLineNumbers;

  /// Additional section information.
  final SectionFlags flags;

  SectionHeader({
    required this.name,
    required this.virtualSize,
    required this.virtualAddress,
    required this.sizeOfRawData,
    required this.pointerToRawData,
    required this.pointerToRelocations,
    required this.pointerToLineNumbers,
    required this.numberOfRelocations,
    required this.numberOfLineNumbers,
    required this.flags,
  });

  factory SectionHeader.fromReader(StructuredFileReader reader) {
    final name = reader.readBytes(8);
    final virtualSize = reader.readUint32();
    final virtualAddress = reader.readUint32();
    final sizeOfRawData = reader.readUint32();
    final pointerToRawData = reader.readUint32();
    final pointerToRelocations = reader.readUint32();
    final pointerToLineNumbers = reader.readUint32();
    final numberOfRelocations = reader.readUint16();
    final numberOfLineNumbers = reader.readUint16();
    final flags = reader.readUint32();

    return SectionHeader(
      name: readNullTerminatedOrFullString(name),
      virtualSize: virtualSize,
      virtualAddress: virtualAddress,
      sizeOfRawData: sizeOfRawData,
      pointerToRawData: pointerToRawData,
      pointerToRelocations: pointerToRelocations,
      pointerToLineNumbers: pointerToLineNumbers,
      numberOfRelocations: numberOfRelocations,
      numberOfLineNumbers: numberOfLineNumbers,
      flags: SectionFlags(flags),
    );
  }

  Uint8List toBytes() {
    final data = ByteData(byteSize);
    
    final nameChars = name.codeUnits;
    for (int i = 0; i < 8 && i < nameChars.length; i++) {
      data.setUint8(i, nameChars[i]);
    }
    for (int i = 0; i < (8 - nameChars.length); i++) {
      data.setUint8(i + nameChars.length, 0);
    }

    data.setUint32(8, virtualSize, Endian.little);
    data.setUint32(12, virtualAddress, Endian.little);
    data.setUint32(16, sizeOfRawData, Endian.little);
    data.setUint32(20, pointerToRawData, Endian.little);
    data.setUint32(24, pointerToRelocations, Endian.little);
    data.setUint32(28, pointerToLineNumbers, Endian.little);
    data.setUint16(32, numberOfRelocations, Endian.little);
    data.setUint16(34, numberOfLineNumbers, Endian.little);
    data.setUint32(36, flags.rawValue, Endian.little);

    return data.buffer.asUint8List();
  }
}
