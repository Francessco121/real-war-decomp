import 'dart:typed_data';

import 'structured_file_reader.dart';
import 'utils.dart';

class SymbolTableEntry {
  /// The name of the symbol.
  final SymbolName name;

  /// The value that is associated with the symbol.
  final int value;

  /// Identifies the section, using a one-based index into the section
  /// table. Some values have special meaning.
  final int sectionNumber;

  /// Type of symbol.
  final int type;

  /// Storage class type.
  final int storageClass;

  /// Additional tool-specific records;
  final List<Uint8List> auxSymbols;

  SymbolTableEntry({
    required this.name,
    required this.value,
    required this.sectionNumber,
    required this.type,
    required this.storageClass,
    required this.auxSymbols,
  });

  factory SymbolTableEntry.fromReader(StructuredFileReader reader) {
    final name = reader.readBytes(8);
    final value = reader.readUint32();
    final sectionNumber = reader.readUint16();
    final type = reader.readUint16();
    final storageClass = reader.readUint8();
    final numberOfAuxSymbols = reader.readUint8();

    final auxSymbols = <Uint8List>[];
    for (int i = 0; i < numberOfAuxSymbols; i++) {
      auxSymbols.add(reader.readBytes(18));
    }

    final nameData = ByteData.sublistView(name);

    return SymbolTableEntry(
      name: nameData.getUint32(0, Endian.little) == 0
          ? SymbolName.long(nameData.getUint32(4, Endian.little))
          : SymbolName.short(readNullTerminatedOrFullString(name)),
      value: value,
      sectionNumber: sectionNumber,
      type: type,
      storageClass: storageClass,
      auxSymbols: auxSymbols,
    );
  }

  @override
  String toString() => name.toString();
}

class SymbolName {
  /// Name of the symbol, if it is not more than 8 bytes long.
  final String? shortName;

  /// Offset of the name in the string table, if the name is more than 8 bytes long.
  final int? offset;

  SymbolName.short(this.shortName) : offset = null;
  SymbolName.long(this.offset) : shortName = null;

  @override
  String toString() => shortName ?? 'stringTable[$offset]';
}
