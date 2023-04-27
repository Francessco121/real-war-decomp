import 'dart:typed_data';

import 'package:pe_coff/coff.dart';
import 'package:rw_yaml/rw_yaml.dart';

/// Applies known symbols in rw.yaml to a COFF file via its relocations.
/// 
/// - [segmentVirtualAddress] - Virtual address of the [coff]'s .text section in the base exe.
void relocateObject(Uint8List bytes, CoffFile coff, RealWarYaml rw, int segmentVirtualAddress) {
  final data = ByteData.sublistView(bytes);

  int textSectionAddress = segmentVirtualAddress; 

  for (final section in coff.sections) {
    if (section.header.name != '.text') {
      continue;
    }

    for (final reloc in section.relocations) {
      final symbol = coff.symbolTable![reloc.symbolTableIndex];
      if (symbol == null) {
        continue;
      }

      assert(symbol.storageClass != 104);

      final symbolName = symbol.name.shortName ?? coff.stringTable!.strings[symbol.name.offset!]!;
      final symbolAddress = rw.symbols[_unmangle(symbolName)];

      if (symbolAddress == null) {
        continue;
      }

      final physicalAddress = section.header.pointerToRawData + reloc.virtualAddress;

      switch (reloc.type) {
        case RelocationTypeI386.dir32:
          final curValue = data.getInt32(physicalAddress, Endian.little);
          data.setInt32(physicalAddress, symbolAddress + curValue, Endian.little);
          break;
        case RelocationTypeI386.rel32:
          final curValue = data.getInt32(physicalAddress, Endian.little);
          final base = textSectionAddress + reloc.virtualAddress;
          final disp = symbolAddress - base - 4; // why - 4?
          data.setInt32(physicalAddress, disp + curValue, Endian.little);
          break;
        default:
          throw UnimplementedError('Unimplemented relocation type: ${reloc.type}');
      }
    }

    // TODO: do we need to align this?
    // this is to handle multiple .text sections in the same obj, we expect them to be linked
    // one after another in order for the same obj
    textSectionAddress += section.header.sizeOfRawData;
  }
}

String _unmangle(String name) {
  if (name.startsWith('_')) {
    name = name.substring(1);
  }
  int atIndex = name.indexOf('@');
  if (atIndex >= 0) {
    name = name.substring(0, atIndex);
  }

  return name;
}
