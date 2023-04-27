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

abstract class RelocationTypeI386 {
  /// Ignored.
  static const int absolute = 0x0000;
  /// Not supported.
  static const int dir16 = 0x0001;
  /// Not supported.
  static const int rel16 = 0x0002;
  /// The target's 32-bit VA.
  static const int dir32 = 0x0006;
  /// The target's 32-bit RVA.
  static const int dir32nb = 0x0007;
  /// Not supported.
  static const int seg12 = 0x0009;
  /// The 16-bit section index of the section that contains the target.
  static const int section = 0x000A;
  /// The 32-bit offset of the target from the beginning of its section.
  static const int secrel = 0x000B;
  /// The CLR token.
  static const int token = 0x000C;
  /// A 7-bit offset from the base of the section that contains the target.
  static const int secrel7 = 0x000D;
  /// The 32-bit relative displacement to the target.
  static const int rel32 = 0x0014;
}
