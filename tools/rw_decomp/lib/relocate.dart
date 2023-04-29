import 'dart:typed_data';

import 'package:pe_coff/coff.dart';

import 'rw_yaml.dart';

class RelocationException implements Exception {
  final String message;

  RelocationException(this.message);
}

/// Applies known symbols in rw.yaml to a COFF file via its relocations.
///
/// - [segmentVirtualAddress] - Virtual address of the [coff]'s .text section in the base exe.
///
/// Throws a [RelocationException] on error.
void relocateObject(
    Uint8List bytes, CoffFile coff, RealWarYaml rw, int segmentVirtualAddress,
    {bool allowUnknownSymbols = false}) {
  final data = ByteData.sublistView(bytes);

  int textSectionAddress = segmentVirtualAddress;

  for (final section in coff.sections) {
    if (section.header.name != '.text') {
      continue;
    }

    for (final reloc in section.relocations) {
      final symbol = coff.symbolTable![reloc.symbolTableIndex]!;
      assert(symbol.storageClass != 104);

      final symbolName = symbol.name.shortName ??
          coff.stringTable!.strings[symbol.name.offset!]!;
      final symbolAddress = rw.symbols[_unmangle(symbolName)];

      if (symbolAddress == null) {
        if (allowUnknownSymbols) {
          continue;
        } else {
          final virtualAddress = textSectionAddress + reloc.virtualAddress;
          throw RelocationException('Unknown symbol: $symbolName @ 0x${virtualAddress.toRadixString(16)}');
        }
      }

      final physicalAddress =
          section.header.pointerToRawData + reloc.virtualAddress;

      switch (reloc.type) {
        case RelocationTypeI386.dir32:
          final curValue = data.getInt32(physicalAddress, Endian.little);
          data.setInt32(
              physicalAddress, symbolAddress + curValue, Endian.little);
          break;
        case RelocationTypeI386.rel32:
          final curValue = data.getInt32(physicalAddress, Endian.little);
          final base = textSectionAddress + reloc.virtualAddress;
          final disp = symbolAddress - base - 4; // why - 4?
          data.setInt32(physicalAddress, disp + curValue, Endian.little);
          break;
        default:
          throw UnimplementedError(
              'Unimplemented relocation type: ${reloc.type}');
      }
    }

    // TODO: do we need to align this?
    // this is to handle multiple .text sections in the same obj, we expect them to be linked
    // one after another in order for the same obj
    textSectionAddress += section.header.sizeOfRawData;
  }
}

String _unmangle(String name) {
  if (name.startsWith('_?')) {
    // Static declared within a function, return in form of 'staticVarName__function_name'
    final qqIndex = name.indexOf('??');
    final atIndex = name.indexOf('@');
    final atIndex2 = name.indexOf('@', atIndex + 1);

    return '${name.substring(2, atIndex)}__${name.substring(qqIndex + 2, atIndex2)}';
  } else {
    // Other
    if (name.startsWith('_')) {
      name = name.substring(1);
    }
    final atIndex = name.indexOf('@');
    if (atIndex >= 0) {
      name = name.substring(0, atIndex);
    }
  }

  return name;
}
