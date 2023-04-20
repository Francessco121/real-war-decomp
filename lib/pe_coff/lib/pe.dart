import 'dart:typed_data';

import 'src/common.dart';
import 'src/structured_file_reader.dart';
import 'src/utils.dart';
import 'coff.dart' show CoffHeader;

export 'src/common.dart';
export 'coff.dart' show CoffHeader;

/// Descriptor for a Portable Executable (PE) file.
///
/// Does not include the actual data/code contained within a PE file,
/// just the headers, tables, and other metadata.
class PeFile {
  /// PE image header.
  final PeHeader header;

  /// Windows COFF image header.
  final CoffHeader coffHeader;

  /// Additional information primarily for the loader.
  ///
  /// Usually not present for objects.
  final OptionalHeader? optionalHeader;

  /// Section information.
  final List<Section> sections;

  /// The symbol table.
  final List<SymbolTableEntry>? symbolTable;

  /// The string table.
  final StringTable? stringTable;

  PeFile({
    required this.header,
    required this.coffHeader,
    required this.optionalHeader,
    required this.sections,
    required this.symbolTable,
    required this.stringTable,
  });

  factory PeFile.fromList(Uint8List list, {Endian endian = Endian.little}) {
    return PeFile._fromReader(StructuredFileReader.list(list, endian: endian));
  }

  factory PeFile._fromReader(StructuredFileReader reader) {
    final peHeader = PeHeader.fromReader(reader);
    final coffHeader = CoffHeader.fromReader(reader);
    final optionalHeader = coffHeader.sizeOfOptionalHeader == 0
        ? null
        : OptionalHeader.fromReader(reader, coffHeader.sizeOfOptionalHeader);

    final sectionHeaders = <SectionHeader>[];
    for (int i = 0; i < coffHeader.numberOfSections; i++) {
      sectionHeaders.add(SectionHeader.fromReader(reader));
    }

    // Sections are usually laid out like this, so we'll try to read them in order
    // and avoid jumping around the file (excluding data):
    // +--------------+
    // | data         |
    // +--------------+
    // +--------------+
    // | relocations  |
    // +--------------+
    // +--------------+
    // | line numbers |
    // +--------------+
    // +--------------+
    // | data         |
    // +--------------+
    // etc ...
    final sections = <Section>[];
    for (int i = 0; i < coffHeader.numberOfSections; i++) {
      final secHeader = sectionHeaders[i];
      final relocations = <RelocationEntry>[];
      final lineNumbers = <LineNumberEntry>[];

      if (secHeader.pointerToRelocations != 0) {
        reader.setPosition(secHeader.pointerToRelocations);

        for (int k = 0; k < secHeader.numberOfRelocations; k++) {
          relocations.add(RelocationEntry.fromReader(reader));
        }
      }

      if (secHeader.pointerToLineNumbers != 0) {
        reader.setPosition(secHeader.pointerToLineNumbers);

        for (int k = 0; k < secHeader.numberOfLineNumbers; k++) {
          lineNumbers.add(LineNumberEntry.fromReader(reader));
        }
      }

      sections.add(Section(
        header: secHeader,
        relocations: relocations,
        lineNumbers: lineNumbers,
      ));
    }

    final List<SymbolTableEntry>? symbols;
    if (coffHeader.pointerToSymbolTable != 0) {
      reader.setPosition(coffHeader.pointerToSymbolTable);
      symbols = [];

      for (int i = 0; i < coffHeader.numberOfSymbols; i++) {
        final symbol = SymbolTableEntry.fromReader(reader);
        // aux symbols count toward numberOfSymbols
        i += symbol.auxSymbols.length;

        symbols.add(symbol);
      }
    } else {
      symbols = null;
    }

    final StringTable? stringTable;
    // String table only exists if the symbol table exists
    if (coffHeader.pointerToSymbolTable != 0) {
      stringTable = StringTable.fromReader(reader);
    } else {
      stringTable = null;
    }

    return PeFile(
      header: peHeader,
      coffHeader: coffHeader,
      optionalHeader: optionalHeader,
      sections: sections,
      symbolTable: symbols,
      stringTable: stringTable,
    );
  }
}

class PeHeader {
  /// DOS header signature.
  /// 
  /// Should be 'MZ'.
  final String dosSignature;

  /// File pointer to the COFF header.
  final int coffHeaderPointer;

  /// PE header signature.
  /// 
  /// Should be 'PE'.
  final String peSignature;

  PeHeader({
    required this.dosSignature,
    required this.coffHeaderPointer,
    required this.peSignature,
  });

  factory PeHeader.fromReader(StructuredFileReader reader) {
    final dosSignature = reader.readBytes(2);

    reader.setPosition(0x3C);
    final coffHeaderPointer = reader.readUint32();

    reader.setPosition(coffHeaderPointer);
    final peSignature = reader.readBytes(4);

    return PeHeader(
      dosSignature: readNullTerminatedOrFullString(dosSignature), 
      coffHeaderPointer: coffHeaderPointer,
      peSignature: readNullTerminatedOrFullString(peSignature),
    );
  }
}
