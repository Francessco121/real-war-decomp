import 'structured_file_reader.dart';

class LineNumberEntry {
  /// Symbol index if [lineNumber] == 0,
  /// otherwise this is the physical address.
  final int symbolIndexOrPhysicalAddress;

  /// If not zero, this is a 1-based line number.
  final int lineNumber;

  LineNumberEntry({
    required this.symbolIndexOrPhysicalAddress,
    required this.lineNumber,
  });

  factory LineNumberEntry.fromReader(StructuredFileReader reader) {
    final symbolIndexOrPhysicalAddress = reader.readUint32();
    final lineNumber = reader.readUint16();

    return LineNumberEntry(
      symbolIndexOrPhysicalAddress: symbolIndexOrPhysicalAddress,
      lineNumber: lineNumber,
    );
  }
}
