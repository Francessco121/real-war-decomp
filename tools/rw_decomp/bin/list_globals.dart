import 'dart:io';

import 'package:pe_coff/coff.dart';

/// Lists all global variables in the given .obj file.
void main(List<String> args) {
  if (args.isEmpty) {
    print('usage: list_globals.dart <path/to/objfile>');
    exit(1);
  }

  final file = File(args[0]);
  final obj = CoffFile.fromList(file.readAsBytesSync());

  for (final (sectionI, section) in obj.sections.indexed) {
    if (!const ['.data', '.rdata'].contains(section.header.name)) {
      continue;
    }
    
    final dataSyms = <SymbolTableEntry>[];

    for (final sym in obj.symbolTable!.values) {
      if ((sym.sectionNumber - 1) != sectionI) {
        continue;
      }
      if (sym.value == 0 && sym.storageClass == StorageClass.static && sym.auxSymbols.isNotEmpty) {
        continue;
      }

      dataSyms.add(sym);
    }

    dataSyms.sort((a, b) => a.value.compareTo(b.value));

    final int sectionFileAddress = section.header.pointerToRawData;

    print('${section.header.name} (#${sectionI + 1})');
    for (final (i, sym) in dataSyms.indexed) {
      final symName = sym.name.shortName ?? obj.stringTable!.strings[sym.name.offset]!;
      final symStart = sym.value;
      final symEnd = (i < dataSyms.length - 1) ? dataSyms[i + 1].value : section.header.sizeOfRawData;
      final symSize = symEnd - symStart;
      final symPA = sectionFileAddress + sym.value;

      print('  $symName: $symSize bytes, at 0x${symPA.toRadixString(16)}');
    }
  }
}
