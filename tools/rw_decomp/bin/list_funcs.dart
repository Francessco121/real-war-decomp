import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';

/// Lists all functions in the given .obj file.
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('usage: list_funcs.dart <path/to/objfile>');
  }

  final file = File(args[0]);
  final obj = CoffFile.fromList(await file.readAsBytes());

  print('${p.basename(file.path)} functions:');

  if (obj.symbolTable == null) {
    print('  (none)');
    return;
  }

  for (final symbol in obj.symbolTable!.values) {
    // Symbol is a function defined in this object file if it has a section number and MSB == 2
    if (symbol.sectionNumber > 0 && (symbol.type >> 4) == 2) {
      final name = symbol.name.shortName ??
          obj.stringTable!.strings[symbol.name.offset]!;
      
      final Section section = obj.sections[symbol.sectionNumber - 1];

      final int textFileAddress = section.header.pointerToRawData;
      final int funcFileAddress = textFileAddress + symbol.value;
      
      print('  ${name.padRight(36)} @ FILE 0x${funcFileAddress.toRadixString(16)}');
    }
  }
}
