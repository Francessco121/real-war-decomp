import 'dart:typed_data';

import 'src/common.dart';
import 'src/structured_file_reader.dart';

export 'src/common.dart';

/// Descriptor for a Common Object File Format (COFF) file.
///
/// Does not include the actual data/code contained within a COFF file,
/// just the headers, tables, and other metadata.
class CoffFile {
  /// Image/object header.
  final CoffHeader header;

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

  CoffFile({
    required this.header,
    required this.optionalHeader,
    required this.sections,
    required this.symbolTable,
    required this.stringTable,
  });

  factory CoffFile.fromList(Uint8List list, {Endian endian = Endian.little}) {
    return CoffFile._fromReader(StructuredFileReader.list(list, endian: endian));
  }

  factory CoffFile._fromReader(StructuredFileReader reader) {
    final header = CoffHeader.fromReader(reader);
    final optionalHeader = header.sizeOfOptionalHeader == 0
        ? null
        : OptionalHeader.fromReader(reader, header.sizeOfOptionalHeader);

    final sectionHeaders = <SectionHeader>[];
    for (int i = 0; i < header.numberOfSections; i++) {
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
    for (int i = 0; i < header.numberOfSections; i++) {
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
    if (header.pointerToSymbolTable != 0) {
      reader.setPosition(header.pointerToSymbolTable);
      symbols = [];

      for (int i = 0; i < header.numberOfSymbols; i++) {
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
    if (header.pointerToSymbolTable != 0) {
      stringTable = StringTable.fromReader(reader);
    } else {
      stringTable = null;
    }

    return CoffFile(
      header: header,
      optionalHeader: optionalHeader,
      sections: sections,
      symbolTable: symbols,
      stringTable: stringTable,
    );
  }
}

class CoffHeader {
  /// Magic number/target machine type.
  ///
  /// See [MachineType].
  final int machine;

  /// Number of entries in the section table.
  final int numberOfSections;

  /// Time and date stamp indicating when the file was created.
  final DateTime timeDateStamp;

  /// File offset of the COFF symbol table or 0 if none is present.
  final int pointerToSymbolTable;

  /// Number of entries in the symbol table (including aux symbols).
  final int numberOfSymbols;

  /// Number of bytes in the optional header.
  ///
  /// Will be 0 if the optional header is not present.
  final int sizeOfOptionalHeader;

  /// Flags indicating attributes of the file.
  final Characteristics characteristics;

  CoffHeader({
    required this.machine,
    required this.numberOfSections,
    required this.timeDateStamp,
    required this.pointerToSymbolTable,
    required this.numberOfSymbols,
    required this.sizeOfOptionalHeader,
    required this.characteristics,
  });

  factory CoffHeader.fromReader(StructuredFileReader reader) {
    final machine = reader.readUint16();
    final numberOfSections = reader.readUint16();
    final timeDateStamp = reader.readUint32();
    final pointerToSymbolTable = reader.readUint32();
    final numberOfSymbols = reader.readUint32();
    final sizeOfOptionalHeader = reader.readUint16();
    final characteristics = reader.readUint16();

    return CoffHeader(
      machine: machine,
      numberOfSections: numberOfSections,
      timeDateStamp: DateTime.fromMillisecondsSinceEpoch(timeDateStamp * 1000),
      pointerToSymbolTable: pointerToSymbolTable,
      numberOfSymbols: numberOfSymbols,
      sizeOfOptionalHeader: sizeOfOptionalHeader,
      characteristics: Characteristics(characteristics),
    );
  }
}
