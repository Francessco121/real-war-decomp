import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:rw_decomp/rw_yaml.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner('rwyaml',
      'Tool for automating some work with rw.yaml.')
    ..addCommand(AddCommand())
    ..addCommand(GenStringsHCommand());

  await runner.run(args);
}

class AddCommand extends Command {
  @override
  final name = 'add';

  @override
  final description = 'Adds a new symbol/string.';

  AddCommand() {
    argParser
      ..addOption('root')
      ..addMultiOption('sym',
          abbr: 's',
          help: 'A symbol to add. In the form of [name:]address. '
            'If only an address is given, a default name will be created.',
          splitCommas: true)
      ..addMultiOption('str',
          abbr: 'g',
          help: 'A string literal symbol to add. In the form of [name:]address. '
            'If only an address is given, a default name will be created. '
            'The strings.h header will also be recreated.',
          splitCommas: true)
      ..addFlag('update', 
          abbr: 'u', 
          help: 'Update the name of existing symbols/strings instead of skipping them.',
          defaultsTo: false);
  }

  @override
  void run() {
    final String projectDir = p.absolute(argResults!['root'] ?? p.current);
    final List<String> symbolsInput = argResults!['sym'];
    final List<String> stringsInput = argResults!['str'];
    final bool update = argResults!['update'];

    if (symbolsInput.isEmpty && stringsInput.isEmpty) {
      print('Nothing to do.');
      return;
    }

    final List<SymbolNamePair> symbolsToAdd = symbolsInput
      .map((s) => SymbolNamePair.parse(s))
      .toList()
      ..sort((a, b) => a.address.compareTo(b.address));
    final List<SymbolNamePair> stringsToAdd = stringsInput
      .map((s) => SymbolNamePair.parse(s))
      .toList()
      ..sort((a, b) => a.address.compareTo(b.address));

    // Load rw.yaml as lines
    final rwYamlFile = File(p.join(projectDir, 'rw.yaml'));
    final rwYamlLines = rwYamlFile.readAsLinesSync();

    // Add symbols
    final addedSymbols = <(String, int)>[];
    final updatedSymbols = <(String, int)>[];
    if (symbolsToAdd.isNotEmpty) {
      // Find start-end of symbols list
      final (symbolsStart, symbolsEnd) = findList(rwYamlLines, 'symbols');
      int i = symbolsStart;
      int insertIdx = i;

      for (final sym in symbolsToAdd) {
        // Find slot to insert symbol
        int current = 0;
        bool alreadyExists = false;
        while (i < symbolsEnd) {
          i += 1;

          final line = rwYamlLines[i].trim();
          if (line.isEmpty || line.startsWith('#')) {
            continue;
          }

          current = int.parse(line.split(':')[1].trimLeft());
          if (current < sym.address) {
            insertIdx = i;
          } else if (current == sym.address) {
            alreadyExists = true;
            insertIdx = i;
            break;
          } else {
            break;
          }
        }

        // Make symbol name
        final symName = sym.name ?? 'DAT_${sym.address.toRadixString(16).padLeft(8, '0')}';
        final yamlLine = '  $symName: 0x${sym.address.toRadixString(16)}';

        // Insert/update
        if (alreadyExists) {
          if (update) {
            rwYamlLines[insertIdx] = yamlLine;
            updatedSymbols.add((symName, sym.address));
          }
        } else {
          rwYamlLines.insert(insertIdx + 1, yamlLine);
          addedSymbols.add((symName, sym.address));
          insertIdx += 1;
        }
      }
    }

    // Add strings
    final addedStrings = <(String, int)>[];
    final updatedStrings = <(String, int)>[];
    if (stringsToAdd.isNotEmpty) {
      // Find start-end of strings list
      final (stringsStart, stringsEnd) = findList(rwYamlLines, 'strings');
      int i = stringsStart;
      int insertIdx = i;

      for (final str in stringsToAdd) {
        // Find slot to insert string
        int current = 0;
        bool alreadyExists = false;
        while (i < stringsEnd) {
          i += 1;

          final line = rwYamlLines[i].trim();
          if (line.isEmpty || line.startsWith('#')) {
            continue;
          }

          current = int.parse(line.split(':')[1].trimLeft());
          if (current < str.address) {
            insertIdx = i;
          } else if (current == str.address) {
            alreadyExists = true;
            insertIdx = i;
            break;
          } else {
            break;
          }
        }

        // Make string name
        final strName = str.name ?? 'str_${str.address.toRadixString(16).padLeft(8, '0')}';
        final yamlLine = '  $strName: 0x${str.address.toRadixString(16)}';

        // Insert/update
        if (alreadyExists) {
          if (update) {
            rwYamlLines[insertIdx] = yamlLine;
            updatedStrings.add((strName, str.address));
          }
        } else {
          rwYamlLines.insert(insertIdx + 1, yamlLine);
          addedStrings.add((strName, str.address));
          insertIdx += 1;
        }
      }
    }

    // Write new rw.yaml
    rwYamlLines.add('');
    rwYamlFile.writeAsStringSync(rwYamlLines.join('\r\n'));

    if (addedSymbols.isNotEmpty) {
      print('Added symbols:');
      for (final sym in addedSymbols) {
        print('${sym.$1}: 0x${sym.$2.toRadixString(16)}');
      }
    }

    if (updatedSymbols.isNotEmpty) {
      if (addedSymbols.isNotEmpty) {
        print('');
      }
      
      print('Updated symbols:');
      for (final sym in updatedSymbols) {
        print('${sym.$1}: 0x${sym.$2.toRadixString(16)}');
      }
    }

    if (addedStrings.isNotEmpty) {
      if (addedSymbols.isNotEmpty || updatedSymbols.isNotEmpty) {
        print('');
      }
      
      print('Added strings:');
      for (final str in addedStrings) {
        print('${str.$1}: 0x${str.$2.toRadixString(16)}');
      }
    }

    if (updatedStrings.isNotEmpty) {
      if (addedSymbols.isNotEmpty || updatedSymbols.isNotEmpty || addedStrings.isNotEmpty) {
        print('');
      }
      
      print('Updated strings:');
      for (final str in updatedStrings) {
        print('${str.$1}: 0x${str.$2.toRadixString(16)}');
      }
    }

    if (addedSymbols.isEmpty && updatedSymbols.isEmpty && addedStrings.isEmpty && updatedStrings.isEmpty) {
      print('All given strings and symbols already exist.');
    }

    // Regenerate strings.h
    if (stringsToAdd.isNotEmpty) {
      print('');
      genStringsH(rwYamlFile);
    }
  }
}

class GenStringsHCommand extends Command {
  @override
  final name = 'genstringsh';

  @override
  final description = 'Regenerate include/strings.h.';

  GenStringsHCommand() {
    argParser.addOption('root');
  }

  @override
  void run() {
    final String projectDir = p.absolute(argResults!['root'] ?? p.current);

    genStringsH(File(p.join(projectDir, 'rw.yaml')));
  }
}

void genStringsH(File rwYamlFile) {
  // Load project config
  final rw = RealWarYaml.load(
      rwYamlFile.readAsStringSync(),
      dir: p.dirname(rwYamlFile.path));
  
  // Get base exe bytes
  final baseExeBytes = File(p.join(rw.dir, rw.config.exePath)).readAsBytesSync();

  // Build file
  final buffer = StringBuffer();
  buffer.writeln('#pragma once');
  buffer.writeln();
  buffer.writeln('// AUTO-GENERATED FILE! DO NOT MODIFY BY HAND (please)!');
  buffer.writeln();
  buffer.writeln('''/**
 * @file
 * @brief Static strings affected by duplicate string elimination (/Gf) in the
 * base executable.
 * 
 * Since the way the MSVC linker deals with duplicate strings isn't documented,
 * for the purposes of this decomp we will refer to them primarily as externs.
 * Object files that happen to have the actual declaration can declare them as
 * a global to let its .data section actually match.
 * 
 * Note: Real War used /Gf NOT /GF so strings are declared in *writable* .data,
 * and NOT readonly .rdata like other compilers would do.
 */''');
  buffer.writeln();

  for (final str in rw.strings.entries) {
    final fileOffset = str.value - rw.exe.imageBase;
    final preview = _readStringContents(baseExeBytes, fileOffset);

    buffer.writeln('extern char ${str.key}[]; // "$preview"');
  }

  final stringsHPath = p.join(rw.dir, rw.config.includeDir, 'strings.h');
  File(stringsHPath).writeAsStringSync(buffer.toString());
  print('Regenerated ${p.relative(stringsHPath, from: rw.dir)}');
}

String _readStringContents(Uint8List bytes, int offset) {
  final buffer = StringBuffer();

  for (int i = offset; i < bytes.lengthInBytes; i++) {
    if (i >= offset + 100) {
      buffer.write('...');
      break;
    }

    final c = bytes[i];
    if (c == 0) {
      break;
    }

    switch (c) {
      case 9: // horizontal tab
        buffer.write('\\t');
      case 10: // newline
        buffer.write('\\n');
      case 13: // carriage return
        buffer.write('\\r');
      case < 32: // non-printable
        break;
      default:
        buffer.writeCharCode(c);
    }
  }

  return buffer.toString();
}

(int, int) findList(List<String> lines, String name) {
  final prefix = '$name:';
  final start = lines.indexWhere((l) => l.startsWith(prefix));
  var end = lines.indexWhere((l) {
    if (l.startsWith('  ')) {
      return false;
    }

    final trimmed = l.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      return false;
    }

    return true;
  }, start + 1);

  if (end < 0) {
    end = lines.length;
  }

  return (start, end);
}

class SymbolNamePair {
  final String? name;
  final int address;

  SymbolNamePair(this.name, this.address);

  factory SymbolNamePair.parse(String str) {
    final parts = str.split(':');
    if (parts.length == 1) {
      return SymbolNamePair(null, _parseInt(str));
    } else {
      return SymbolNamePair(parts[0], _parseInt(parts[1]));
    }
  }

  static int _parseInt(String str) {
    return int.tryParse(str, radix: 16) ?? int.parse(str);
  }
}
