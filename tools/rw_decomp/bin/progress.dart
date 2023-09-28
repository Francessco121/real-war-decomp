import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';

const int _textStart = 0x401000;
const int _textEnd = 0x4e1510; // LIBC.LIB
const int _rdataStart = 0x4e9000;
const int _rdataEnd = 0x4ec000;
const int _dataStart = 0x4ec000;
const int _dataEnd = 0x51b000; // .bss

Future<void> main(List<String> args) async {
  final argParser = ArgParser()
      ..addOption('root')
      ..addFlag('shields', 
          help: 'Regenerate docs/shields/*', 
          defaultsTo: false, 
          negatable: false)
      ..addFlag('help', negatable: false);

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);
  final bool genShields = argResult['shields'];

  if (argResult['help'] == true) {
    print('progress.dart [options]');
    print(argParser.usage);
    return;
  }

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);
  
  final buildDir = p.join(rw.dir, rw.config.buildDir);
  final srcDir = p.join(rw.dir, rw.config.srcDir);

  final objCache = ObjCache();

  // Determine .text progress
  int textTotalBytes = _textEnd - _textStart;
  int totalFunctions = rw.symbols.values
      .fold(0, (sum, addr) => (addr >= _textStart && addr < _textEnd) ? (sum + 1) : sum);
  int textMatchingBytes = 0;
  int matchingFunctions = 0;
  
  for (final (i, segment) in rw.segments.indexed) {
    if (segment.address < _textStart || segment.address >= _textEnd) {
      continue;
    }

    if (segment.type == 'c') {
      final cFile = File(p.join(srcDir, '${segment.name}.c'));
      final asmFuncs = _getAsmFuncs(cFile);

      final obj = objCache.get(p.join(buildDir, 'obj', '${segment.name}.obj'));
      final objProgress = _getObjTextProgress(obj, asmFuncs);

      textMatchingBytes += objProgress.matchingBytes;
      matchingFunctions += objProgress.matchingFunctions;
    } else if (segment.type == 'thunks') {
      final nextSegment = rw.segments[i + 1];
      final segmentSize = nextSegment.address - segment.address;
      textTotalBytes -= segmentSize;
      totalFunctions -= rw.symbols.values
          .fold(0, (sum, addr) => (addr >= segment.address && addr < nextSegment.address) ? (sum + 1) : sum);
    }
  }

  // Determine .rdata progress
  int rdataTotalBytes = _rdataEnd - _rdataStart;
  int rdataMatchingBytes = 0;

  for (final (i, segment) in rw.segments.indexed) {
    if (segment.address < _rdataStart || segment.address >= _rdataEnd) {
      continue;
    }

    if (segment.type == 'rdata') {
      final obj = objCache.get(p.join(buildDir, 'obj', '${segment.name}.obj'));
      rdataMatchingBytes += _getObjRdataProgress(obj);
    } else if (segment.type == 'extfuncs') {
      final nextSegment = rw.segments[i + 1];
      final segmentSize = nextSegment.address - segment.address;
      rdataTotalBytes -= segmentSize;
    }
  }

  // Determine .data progress
  int dataTotalBytes = _dataEnd - _dataStart;
  int dataMatchingBytes = 0;

  for (final segment in rw.segments) {
    if (segment.address < _dataStart || segment.address >= _dataEnd) {
      continue;
    }

    if (segment.type == 'data') {
      final obj = objCache.get(p.join(buildDir, 'obj', '${segment.name}.obj'));
      dataMatchingBytes += _getObjDataProgress(obj);
    }
  }

  // Display
  final totalBytes = textTotalBytes + rdataTotalBytes + dataTotalBytes;
  final totalMatchingBytes = textMatchingBytes + rdataMatchingBytes + dataMatchingBytes;

  final funcPercentage = ((matchingFunctions / totalFunctions) * 100.0).toStringAsFixed(2);
  final textBytePercentage = ((textMatchingBytes / textTotalBytes) * 100.0).toStringAsFixed(2);
  final rdataBytePercentage = ((rdataMatchingBytes / rdataTotalBytes) * 100.0).toStringAsFixed(2);
  final dataBytePercentage = ((dataMatchingBytes / dataTotalBytes) * 100.0).toStringAsFixed(2);
  final totalBytePercentage = ((totalMatchingBytes / totalBytes) * 100.0).toStringAsFixed(2);

  print('total:');
  print('    bytes: ${'$totalMatchingBytes/$totalBytes'.padLeft(14)} ($totalBytePercentage%)');
  print('.text:');
  print('    funcs: ${'$matchingFunctions/$totalFunctions'.padLeft(14)} ($funcPercentage%)');
  print('    bytes: ${'$textMatchingBytes/$textTotalBytes'.padLeft(14)} ($textBytePercentage%)');
  print('.rdata:');
  print('    bytes: ${'$rdataMatchingBytes/$rdataTotalBytes'.padLeft(14)} ($rdataBytePercentage%)');
  print('.data:');
  print('    bytes: ${'$dataMatchingBytes/$dataTotalBytes'.padLeft(14)} ($dataBytePercentage%)');

  // Generate shields
  if (genShields) {
    final shieldsDir = p.join(rw.dir, 'docs', 'shields');

    Future<void> makeShield(String filename, String label, String content) async {
      final shieldSvg = await _getNewShield(label, content);
      final shieldFile = File(p.join(shieldsDir, filename));
      shieldFile.writeAsStringSync(shieldSvg);
    }

    await makeShield('total.svg', 'Total', '$totalBytePercentage%');
    await makeShield('funcs.svg', 'Functions', '$funcPercentage%');

    print('');
    print('Wrote new shields to $shieldsDir');
  }
}

class ObjCache {
  final _cache = <String, CoffFile>{};

  CoffFile get(String path) {
    return _cache.putIfAbsent(path, () {
      final bytes = File(path).readAsBytesSync();
      return CoffFile.fromList(bytes);
    });
  }
}

class ObjTextProgress {
  final int matchingBytes;
  final int matchingFunctions;

  ObjTextProgress(this.matchingBytes, this.matchingFunctions);
}

ObjTextProgress _getObjTextProgress(CoffFile obj, Set<String> asmFuncs) {
  int matchingBytes = 0;
  int matchingFunctions = 0;

  // Assume the obj was compiled with COMDAT functions
  for (final (i, section) in obj.sections.indexed) {
    if (section.header.name != '.text') {
      continue;
    }

    assert(section.header.flags.lnkComdat);
    
    final funcSymbol = obj.symbolTable!.values
        .firstWhere((s) => s.type == 0x20 && s.value == 0 && s.sectionNumber == (i + 1));
    final funcName = funcSymbol.name.shortName 
      ?? obj.stringTable!.strings[funcSymbol.name.offset!]!;

    if (!asmFuncs.contains(unmangle(funcName))) {
      matchingFunctions++;
      matchingBytes += (section.header.sizeOfRawData / 8).ceil() * 8;
    }
  }

  return ObjTextProgress(matchingBytes, matchingFunctions);
}

int _getObjRdataProgress(CoffFile obj) {
  int matchingBytes = 0;

  for (final section in obj.sections) {
    if (section.header.name != '.rdata') {
      continue;
    }

    matchingBytes += section.header.sizeOfRawData;
  }

  return matchingBytes;
}

int _getObjDataProgress(CoffFile obj) {
  int matchingBytes = 0;

  for (final section in obj.sections) {
    if (section.header.name != '.data') {
      continue;
    }

    matchingBytes += section.header.sizeOfRawData;
  }

  return matchingBytes;
}

final _pragmaAsmFuncRegex = RegExp(r'^#pragma(?:\s+)ASM_FUNC(?:\s+)(\S+)');

Set<String> _getAsmFuncs(File file) {
  final asmFuncs = <String>{};

  for (final line in file.readAsLinesSync()) {
    final asmFunc = _pragmaAsmFuncRegex.firstMatch(line)?.group(1);
    if (asmFunc != null) {
      asmFuncs.add(asmFunc);
    }
  }

  return asmFuncs;
}

Future<String> _getNewShield(String label, String text) async {
  final args = Uri.encodeComponent('$label-$text-blue');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse('https://img.shields.io/badge/$args'));
  final response = await request.close();
  final content = await utf8.decodeStream(response);
  client.close();

  if (response.statusCode >= 400) {
    throw Exception('Failed to get new shield: $content');
  }

  return content;
}
