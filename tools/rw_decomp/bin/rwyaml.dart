import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:rw_decomp/msvc_literal_symbols.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';
import 'package:rw_decomp/yaml_edits.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner('rwyaml',
      'Tool for automating some work with rw.yaml.')
    ..addCommand(AddCommand())
    ..addCommand(BackfillFuncSizesCommand());

  await runner.run(args);
}

class AddCommand extends Command {
  @override
  final name = 'add';

  @override
  final description = 'Adds/updates symbols.';

  AddCommand() {
    argParser
      ..addOption('root')
      ..addMultiOption('sym',
          abbr: 's',
          help: 'A named symbol to add. In the form of [name:]address[;size]. '
            'If only an address is given, a default name will be created. '
            'Do not use for literals that have compiler-generated symbol names (e.g. static strings).',
          splitCommas: true)
      ..addMultiOption('str',
          abbr: 'g',
          help: 'A string literal symbol to add, by its address.',
          splitCommas: true)
      ..addMultiOption('float',
          abbr: 'f',
          help: 'A float literal symbol to add, by its address.',
          splitCommas: true)
      ..addMultiOption('double',
          abbr: 'd',
          help: 'A double literal symbol to add, by its address.',
          splitCommas: true)
      ..addFlag('update', 
          abbr: 'u', 
          help: 'Update the name of existing symbols instead of skipping them.',
          defaultsTo: false);
  }

  @override
  void run() {
    final String projectDir = p.absolute(argResults!['root'] ?? p.current);
    final List<String> symbolsInput = argResults!['sym'];
    final List<String> stringsInput = argResults!['str'];
    final List<String> floatsInput = argResults!['float'];
    final List<String> doublesInput = argResults!['double'];
    final bool update = argResults!['update'];

    if (symbolsInput.isEmpty && stringsInput.isEmpty && floatsInput.isEmpty && doublesInput.isEmpty) {
      print('Nothing to do.');
      return;
    }

    final symbolsToAdd = <SymbolMapping>[
      ...symbolsInput.map((s) => _parseSymbolNameSizePair(s)),
    ];

    symbolsToAdd.sort((a, b) => a.address.compareTo(b.address));

    final literalSymbolsToAdd = <LiteralSymbolMapping>[
      ...stringsInput.map((a) => LiteralSymbolMapping(_parseInt(a), MsvcLiteralSymbolType.string)),
      ...floatsInput.map((a) => LiteralSymbolMapping(_parseInt(a), MsvcLiteralSymbolType.float)),
      ...doublesInput.map((a) => LiteralSymbolMapping(_parseInt(a), MsvcLiteralSymbolType.double)),
    ];

    literalSymbolsToAdd.sort((a, b) => a.address.compareTo(b.address));

    // Load project config
    final rwYamlFile = File(p.join(projectDir, 'rw.yaml'));
    final rwYamlContents = rwYamlFile.readAsStringSync();
    final rw = RealWarYaml.load(
        rwYamlContents,
        dir: p.dirname(rwYamlFile.path));

    // Load rw.yaml as lines
    final rwYamlLines = LineSplitter.split(rwYamlContents).toList();

    // Get base exe bytes
    final baseExeBytes = File(p.join(rw.dir, rw.config.exePath)).readAsBytesSync();
    final baseExeData = ByteData.sublistView(baseExeBytes);

    // Add symbols
    final addedSymbols = <String>[];
    final updatedSymbols = <String>[];
    if (symbolsToAdd.isNotEmpty) {
      // Find start-end of symbols list
      final (symbolsStart, symbolsEnd) = findYamlList(rwYamlLines, 'symbols');
      int i = symbolsStart;
      int insertIdx = i;

      for (final sym in symbolsToAdd) {
        // Find slot to insert symbol
        SymbolLine? current;
        bool alreadyExists = false;
        while (i < symbolsEnd - 1) {
          i += 1;

          final line = rwYamlLines[i].trim();
          if (line.isEmpty || line.startsWith('#')) {
            continue;
          }

          current = _parseSymbolLine(line);

          if (current.address < sym.address) {
            insertIdx = i;
          } else if (current.address == sym.address) {
            alreadyExists = true;
            insertIdx = i;
            break;
          } else {
            break;
          }
        }

        // Default name/size if necessary
        String? symName = sym.name;
        int? symSize = sym.size;

        if (alreadyExists) {
          symName ??= current!.name;
          symSize ??= current!.size;
        }

        symName ??= 'DAT_${sym.address.toRadixString(16).padLeft(8, '0')}';

        // Make YAML symbol entry
        final yamlLine = symSize == null 
          ? '  $symName: 0x${sym.address.toRadixString(16)}'
          : '  $symName: [0x${sym.address.toRadixString(16)}, $symSize]';

        // Insert/update
        if (alreadyExists) {
          if (update) {
            rwYamlLines[insertIdx] = yamlLine;
            updatedSymbols.add(yamlLine);
          }
        } else {
          rwYamlLines.insert(insertIdx + 1, yamlLine);
          addedSymbols.add(yamlLine);
          insertIdx += 1;
        }
      }
    }

    // Add literal symbols
    final addedLiteralSymbols = <String>[];
    final updatedLiteralSymbols = <String>[];
    if (literalSymbolsToAdd.isNotEmpty) {
      // Find start-end of literal symbols list
      final (symbolsStart, symbolsEnd) = findYamlList(rwYamlLines, 'literalSymbols');
      int i = symbolsStart;
      int insertIdx = i;

      for (final sym in literalSymbolsToAdd) {
        // Generate the symbol name
        final (msvcSymbol, literal) = generateMsvcSymbolForLiteral(rw, baseExeData, sym.address, sym.literalType!);
        final symName = '"${unmangle(msvcSymbol)}"';

        // Find slot to insert symbol
        LiteralSymbolLine? current;
        bool alreadyExists = false;
        while (i < symbolsEnd - 1) {
          i += 1;

          final line = rwYamlLines[i].trim();
          if (line.isEmpty || line.startsWith('#')) {
            continue;
          }

          current = _parseLiteralSymbolLine(line);

          if (current.name == symName || current.addresses.contains(sym.address)) {
            alreadyExists = true;
            insertIdx = i;
            break;
          } else if (current.addresses.first < sym.address) {
            insertIdx = i;
          } else {
            break;
          }
        }

        // Generate the display name and determine size
        final String displayName;
        final int size;
        if (sym.literalType == MsvcLiteralSymbolType.string) {
          displayName = '&\\"${_literalToDisplayString(literal)}\\"';
          size = _memoryAlign((literal as String).codeUnits.length + 1);
        } else if (sym.literalType == MsvcLiteralSymbolType.float) {
          displayName = '&${literal}f';
          size = 4;
        } else if (sym.literalType == MsvcLiteralSymbolType.double) {
          displayName = '&$literal';
          size = 8;
        } else {
          throw UnimplementedError();
        }

        // Add address if necessary
        final List<int> addresses;
        if (alreadyExists) {
          addresses = current!.addresses.toList();
          if (!addresses.contains(sym.address)) {
            addresses.add(sym.address);
          }
        } else {
          addresses = [sym.address];
        }

        // Make YAML symbol entry
        final yamlLine = '  $symName: ["$displayName", $size, ${addresses.map((a) => '0x${a.toRadixString(16)}').join(', ')}]';

        // Insert/update
        //
        // Note: always update existing literal symbols
        if (alreadyExists) {
          rwYamlLines[insertIdx] = yamlLine;
          updatedLiteralSymbols.add(yamlLine);
        } else {
          rwYamlLines.insert(insertIdx + 1, yamlLine);
          addedLiteralSymbols.add(yamlLine);
          insertIdx += 1;
        }
      }
    }

    // Write new rw.yaml
    rwYamlLines.add('');
    rwYamlFile.writeAsStringSync(rwYamlLines.join('\r\n'));

    if (addedSymbols.isNotEmpty || addedLiteralSymbols.isNotEmpty) {
      print('Added symbols:');
      for (final line in addedSymbols) {
        print(line.trimLeft());
      }
      for (final line in addedLiteralSymbols) {
        print(line.trimLeft());
      }
    }

    if (updatedSymbols.isNotEmpty || updatedLiteralSymbols.isNotEmpty) {
      if (addedSymbols.isNotEmpty || addedLiteralSymbols.isNotEmpty) {
        print('');
      }
      
      print('Updated symbols:');
      for (final line in updatedSymbols) {
        print(line.trimLeft());
      }
      for (final line in updatedLiteralSymbols) {
        print(line.trimLeft());
      }
    }

    if (addedSymbols.isEmpty && updatedSymbols.isEmpty && 
        addedLiteralSymbols.isEmpty && updatedLiteralSymbols.isEmpty) {
      print('All given symbols already exist.');
    }
  }
}

class BackfillFuncSizesCommand extends Command {
  @override
  final name = 'backfill-func-sizes';

  @override
  final description = 'Estimates function sizes for all function symbols that don\'t have a defined size.';

  BackfillFuncSizesCommand() {
    argParser.addOption('root');
  }

  @override
  void run() {
    final String projectDir = p.absolute(argResults!['root'] ?? p.current);

    // Load project config
    final rwYamlFile = File(p.join(projectDir, 'rw.yaml'));
    final rwYamlContents = rwYamlFile.readAsStringSync();
    final rw = RealWarYaml.load(
        rwYamlContents,
        dir: p.dirname(rwYamlFile.path));

    // Load rw.yaml as lines
    final rwYamlLines = LineSplitter.split(rwYamlContents).toList();
    
    (String, int, int?) parseSymbolLine(String line) {
      final kv = line.split(':');
      final name = kv[0].trim();
      final value = kv[1].trimLeft();

      final int address;
      final int? size;
      if (value.startsWith('[')) {
        final endBracketIdx = value.indexOf(']');
        final pair = value.substring(1, endBracketIdx).split(',');

        address = int.parse(pair[0].trim());
        size = int.parse(pair[1].trim());
      } else {
        address = int.parse(value.split(' ')[0]); // strip any comments
        size = null;
      }

      return (name, address, size);
    }

    // Find start-end of symbols list
    final (symbolsStart, symbolsEnd) = findYamlList(rwYamlLines, 'symbols');
    final funcs = <(int, (String, int, int?))>[];
    final textStart = rw.exe.imageBase + rw.exe.textVirtualAddress;
    final textEnd = rw.exe.imageBase + rw.exe.rdataVirtualAddress;

    // Parse all .text symbols
    for (int i = symbolsStart + 1; i < (symbolsEnd - 1); i++) {
      final line = rwYamlLines[i].trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final sym = parseSymbolLine(line);

      assert(sym.$2 >= textStart);
      if (sym.$2 >= textEnd) {
        break;
      }

      funcs.add((i, sym));
    }

    // Backfill missing symbol sizes
    int updateCount = 0;
    for (final (i, (yamlIdx, (name, address, size))) in funcs.indexed) {
      if (size != null) {
        // Already has defined size
        continue;
      }

      final inferredSize = i < (funcs.length - 1)
          ? funcs[i + 1].$2.$2 - address
          : textEnd - address;
      
      final yamlLine = '  $name: [0x${address.toRadixString(16)}, $inferredSize]';

      rwYamlLines[yamlIdx] = yamlLine;
      updateCount++;
    }

    // Write new rw.yaml
    rwYamlLines.add('');
    rwYamlFile.writeAsStringSync(rwYamlLines.join('\r\n'));

    print('Backfilled $updateCount symbol size(s).');
  }
}

String _literalToDisplayString(String literal) {
  final buffer = StringBuffer();

  for (final c in literal.codeUnits) {
    if (buffer.length > 32) {
      buffer.write('...');
      break;
    }

    switch (c) {
      case 9: // horizontal tab
        buffer.write(r'\\t');
      case 10: // newline
        buffer.write(r'\\n');
      case 13: // carriage return
        buffer.write(r'\\r');
      case < 32: // non-printable
        break;
      case 34: // double quote
        buffer.write(r'\\"');
      case 92: // backslash
        buffer.write(r'\\\\');
      default:
        buffer.writeCharCode(c);
    }
  }

  return buffer.toString();
}

int _memoryAlign(int value) {
  return (value / 4).ceil() * 4;
}

class SymbolLine {
  final String name;
  final int address;
  final int? size;

  SymbolLine(this.name, this.address, this.size);
}

SymbolLine _parseSymbolLine(String line) {
  final kv = line.split(':');
  final name = kv[0].trim();
  final value = kv[1].trimLeft();

  final int address;
  final int? size;
  if (value.startsWith('[')) {
    final endBracketIdx = value.indexOf(']');
    final pair = value.substring(1, endBracketIdx).split(',');

    address = int.parse(pair[0].trim());
    size = int.parse(pair[1].trim());
  } else {
    address = int.parse(value.split(' ')[0]); // strip any comments
    size = null;
  }

  return SymbolLine(name, address, size);
}

class LiteralSymbolLine {
  final String name;
  final String displayName;
  final int size;
  final List<int> addresses;

  LiteralSymbolLine(this.name, this.displayName, this.size, this.addresses);
}

LiteralSymbolLine _parseLiteralSymbolLine(String line) {
  final colonIdx = line.indexOf(':');
  final name = line.substring(0, colonIdx).trim();
  final value = line.substring(colonIdx + 1).trimLeft();

  final String displayName;
  final int size;
  final List<int>? addresses;
  if (value.startsWith('[')) {
    final endBracketIdx = value.lastIndexOf(']');
    final displayStringEnd = value.lastIndexOf('"');
    final numbers = value.substring(displayStringEnd + 1, endBracketIdx).split(',');

    displayName = value.substring(1, displayStringEnd + 1).trim();
    size = int.parse(numbers[1].trim());
    addresses = numbers.skip(2).map((s) => int.parse(s.trim())).toList();
  } else {
    displayName = name;
    size = int.parse(value.split(' ')[0]); // strip any comments
    addresses = null;
  }

  return LiteralSymbolLine(name, displayName, size, addresses ?? []);
}

class SymbolMapping {
  final String? name;
  final int address;
  final int? size;

  SymbolMapping(this.name, this.address, this.size);
}

class LiteralSymbolMapping {
  final int address;
  final MsvcLiteralSymbolType? literalType;

  LiteralSymbolMapping(this.address, this.literalType);
}

SymbolMapping _parseSymbolNameSizePair(String str) {
  // [name:]address[;size]
  final String? name;
  
  final colonIdx = str.indexOf(':');
  if (colonIdx >= 0) {
    name = str.substring(0, colonIdx);
  } else {
    name = null;
  }

  final int? size;
  final int address;

  final semicolonIdx = str.indexOf(';', colonIdx < 0 ? 0 : colonIdx);
  if (semicolonIdx >= 0) {
    address = _parseInt(str.substring(colonIdx < 0 ? 0 : (colonIdx + 1), semicolonIdx));
    size = _parseInt(str.substring(semicolonIdx + 1));
  } else {
    address = _parseInt(str.substring(colonIdx < 0 ? 0 : (colonIdx + 1)));
    size = null;
  }

  return SymbolMapping(name, address, size);
}

int _parseInt(String str) {
  return int.tryParse(str) ?? int.parse(str, radix: 16);
}
