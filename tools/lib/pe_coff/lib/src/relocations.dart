import 'structured_file_reader.dart';

class RelocationEntry {
  /// The address of the item to which relocation is applied.
  final int virtualAddress;

  /// A zero-based index into the symbol table. This symbol gives
  /// the address that is to be used for the relocation. If the
  /// specified symbol has section storage class, then the symbol's
  /// address is the address with the first section of the same name.
  final int symbolTableIndex;

  /// A value that indicates the kind of relocation that should be performed.
  /// Valid relocation types depend on machine type.
  final int type;

  RelocationEntry({
    required this.virtualAddress,
    required this.symbolTableIndex,
    required this.type,
  });

  factory RelocationEntry.fromReader(StructuredFileReader reader) {
    final virtualAddress = reader.readUint32();
    final symbolTableIndex = reader.readUint32();
    final type = reader.readUint16();

    return RelocationEntry(
      virtualAddress: virtualAddress,
      symbolTableIndex: symbolTableIndex,
      type: type,
    );
  }
}
