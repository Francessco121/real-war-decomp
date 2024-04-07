import 'dart:typed_data';

import 'package:pe_coff/coff.dart';

class RelocationException implements Exception {
  final String message;

  RelocationException(this.message);

  @override
  String toString() => 'RelocationException: $message';
}

/// Applies all relocations for a single COFF section to the new [targetVirtualAddress].
/// 
/// Throws a [RelocationException] on error.
void relocateSection(CoffFile coff, Section section, Uint8List sectionBytes,
    {required int targetVirtualAddress,
    required int? Function(String name) symbolLookup,
    bool allowUnknownSymbols = false}) {
  final sectionData = ByteData.sublistView(sectionBytes);

  for (final reloc in section.relocations) {
    final symbol = coff.symbolTable![reloc.symbolTableIndex]!;
    assert(symbol.storageClass != StorageClass.section);

    final symbolName = symbol.name.shortName ??
        coff.stringTable!.strings[symbol.name.offset!]!;
    
    final int? symbolAddress;
    if (symbol.storageClass == StorageClass.label) {
      // Defined code label. The relative offset stored in the value field
      // defines the offset of these symbols
      assert(coff.sections[symbol.sectionNumber - 1] == section);
      symbolAddress = targetVirtualAddress + symbol.value;
    } else {
      symbolAddress = symbolLookup(symbolName);
    }

    if (symbolAddress == null) {
      if (allowUnknownSymbols) {
        continue;
      } else {
        final virtualAddress = targetVirtualAddress + reloc.virtualAddress;
        throw RelocationException(
            'Unknown symbol: $symbolName @ 0x${virtualAddress.toRadixString(16)}');
      }
    }

    applyRelocation(reloc, sectionData, targetVirtualAddress, symbolAddress);
  }
}

/// Applies a single relocation ([reloc]) to a section ([sectionData]) with the given
/// [sectionVA] (virtual address the section is being relocated to) and [symbolVA] (virtual address
/// of the target symbol).
void applyRelocation(
    RelocationEntry reloc, ByteData sectionData, int sectionVA, int symbolVA) {
  final physicalAddress = reloc.virtualAddress;

  switch (reloc.type) {
    case RelocationTypeI386.dir32:
      final curValue = sectionData.getInt32(physicalAddress, Endian.little);
      sectionData.setInt32(physicalAddress, symbolVA + curValue, Endian.little);
      break;
    case RelocationTypeI386.rel32:
      final curValue = sectionData.getInt32(physicalAddress, Endian.little);
      final base = sectionVA + reloc.virtualAddress;
      final disp = symbolVA - base - 4; // why - 4?
      sectionData.setInt32(physicalAddress, disp + curValue, Endian.little);
      break;
    default:
      throw UnimplementedError('Unimplemented relocation type: ${reloc.type}');
  }
}
