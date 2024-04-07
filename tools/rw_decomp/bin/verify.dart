import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe_coff.dart';
import 'package:rw_decomp/diff.dart';
import 'package:rw_decomp/levenshtein.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';
import 'package:rw_decomp/verify.dart';
import 'package:x86_analyzer/functions.dart';


/*
1. find object files to verify by iterating .c files in src
2. find all functions in obj file
3. get bytes for original function and recompiled function
4. relocate recompiled function (or just the entire file)
5. run differ on instructions + jump tables
6. compute matching score by iterating each diff line
  - additions/deletions are +1
  - equality/substitutions are +1 if they:
    - don't match byte for byte
    - dont involve literal symbols that equal by value
  - add +1 for each non-matching byte after the jump tables to catch anything we missed
7. sum total of bytes that match (can be an estimate)
*/


void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root', help: 'Project root.')
      ..addFlag('help', negatable: false, defaultsTo: false, 
          help: 'Displays this help information.')
      ..addOption('baseline-file', abbr: 'f', 
          help: 'The baseline verification file to use if comparing to a baseline. '
            'Defaults to \'verification-baseline.json\' in the project root.')
      ..addFlag('baseline', abbr: 'b', defaultsTo: true, 
          help: 'Only show differences from a baseline verification file. Useful for catching regressions. '
            'If not comparing to a baseline, all non-matching symbols will be shown.')
      ..addFlag('update-baseline', abbr: 'u', defaultsTo: false, 
          help: 'Update the baseline verification file.')
      ..addFlag('check-segments', abbr: 'c', defaultsTo: false,
          help: 'Verifies that symbols defined in each object file are within the expected address range '
              'as defined in the rw.yaml segment mapping.');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);
  final bool showHelp = argResult['help'];
  final String? customBaselineFilePath = argResult['baseline-file'];
  final bool compareToBaseline = argResult['baseline'];
  final bool updateBaseline = argResult['update-baseline'];
  final bool checkSegments = argResult['check-segments'];

  if (showHelp) {
    print('Compares recompiled code/data against the base game to verify decomp accuracy.');
    print('');
    print('Usage: verify [arguments]');
    print('');
    print('Options:');
    print(argParser.usage);
    return;  
  }

  final baselineFile = compareToBaseline
      ? File(customBaselineFilePath ?? p.join(projectDir, 'verification-baseline.json'))
      : null;
  final baselineFileExists = baselineFile != null ? baselineFile.existsSync() : false;
  
  if (compareToBaseline && customBaselineFilePath != null && !baselineFileExists) {
    print('Could not find baseline file at ${p.absolute(customBaselineFilePath)}.');
    exit(-1);
  }

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);
  
  final String srcDirPath = p.join(projectDir, rw.config.srcDir);
  final String buildDirPath = p.join(projectDir, rw.config.buildDir);
  final String buildObjDirPath = p.join(projectDir, rw.config.buildDir, 'obj');

  // Init disassembler
  final capstoneDll = ffi.DynamicLibrary.open(p.join(projectDir, 'tools', 'capstone.dll'));
  final disassembler = FunctionDisassembler.init(capstoneDll);
  
  // Parse exe
  final String exeFilePath = p.join(projectDir, rw.config.exePath);
  final exeBytes = File(exeFilePath).readAsBytesSync();
  final exe = PeFile.fromList(exeBytes);
  final exeData = FileData.fromList(exeBytes);

  // Sort base exe symbols
  final sortedSymbols = rw.symbols.entries.map((e) => (e.value.address, e.key)).toList();
  sortedSymbols.sort((a, b) => a.$1.compareTo(b.$1));

  // Load segment mappings if we're checking that
  final objSegments = checkSegments
      ? _getObjSegments(rw)
      : null;

  // Load previous run if available
  final lastRunFile = File(p.join(buildDirPath, 'verification.json'));
  final lastRun = lastRunFile.existsSync()
      ? VerificationResult.fromJson(json.decode(lastRunFile.readAsStringSync()))
      : null;

  // Verify object files
  final context = VerifyContext(
    rw: rw,
    disassembler: disassembler,
    exe: exe,
    exeData: exeData,
    sortedSymbols: sortedSymbols,
  );

  final nowUtc = DateTime.now().toUtc();

  final objResults = <String, ObjVerificationResult>{};
  final objSegmentResults = <(String, VerifyObjSegmentsResult)>[];
  final srcDir = Directory(srcDirPath);
  for (final file in srcDir.listSync(recursive: true)) {
    if (file is! File || p.extension(file.path) != '.c') {
      continue;
    }

    final objRelativePath = p.relative(p.setExtension(file.absolute.path, '.obj'), from: srcDir.absolute.path);
    final objFile = File(p.join(buildObjDirPath, objRelativePath));
    if (!objFile.existsSync()) {
      stderr.writeln('Could not find ${p.relative(objFile.path, from: projectDir)}. Have you ran the build?');
      exit(-1);
    }

    bool objUnchanged = false;
    if (lastRun != null) {
      final lastRunObjTimestamp = lastRun.objs[objRelativePath];
      if (lastRunObjTimestamp != null && lastRunObjTimestamp.isAfter(objFile.statSync().modified)) {
        // obj hasn't changed since last run, skip
        objUnchanged = true;
      }
    }

    if (objUnchanged && !checkSegments) {
      continue;
    }

    final objBytes = objFile.readAsBytesSync();
    final obj = CoffFile.fromList(objBytes);

    if (!objUnchanged) {
      objResults[objRelativePath] = _verifyObj(context, obj, objBytes);
    }

    if (checkSegments) {
      final segments = objSegments![p.withoutExtension(objRelativePath)];
      if (segments != null) {
        objSegmentResults.add((objRelativePath, _checkSegments(context, segments, obj)));
      }
    }
  }

  // Combine results with previous run
  final objTimestamps = <String, DateTime>{};
  
  final textResults = <int, SymbolVerificationResult>{};
  final rdataResults = <int, SymbolVerificationResult>{};
  final dataResults = <int, SymbolVerificationResult>{};

  if (lastRun != null) {
    objTimestamps.addAll(lastRun.objs);

    textResults.addAll(lastRun.text.symbols);
    rdataResults.addAll(lastRun.rdata.symbols);
    dataResults.addAll(lastRun.data.symbols);
  }

  for (final entry in objResults.entries) {
    objTimestamps[entry.key] = nowUtc;

    for (final textResult in entry.value.text) {
      textResults[textResult.address] = textResult;
    }

    for (final rdataResult in entry.value.rdata) {
      rdataResults[rdataResult.address] = rdataResult;
    }

    for (final dataResult in entry.value.data) {
      dataResults[dataResult.address] = dataResult;
    }
  }

  // Compute new totals
  final textTotalMatchingBytes = textResults.values.fold(0, (sum, sym) => sum + sym.matchingBytes);
  final rdataTotalMatchingBytes = rdataResults.values.fold(0, (sum, sym) => sum + sym.matchingBytes);
  final dataTotalMatchingBytes = dataResults.values.fold(0, (sum, sym) => sum + sym.matchingBytes);

  // Emit verification result file
  final result = VerificationResult(
    timestamp: nowUtc,
    objs: objTimestamps,
    text: VerificationSectionResult(
      totalMatchingBytes: textTotalMatchingBytes,
      symbols: textResults,
    ),
    rdata: VerificationSectionResult(
      totalMatchingBytes: rdataTotalMatchingBytes,
      symbols: rdataResults,
    ),
    data: VerificationSectionResult(
      totalMatchingBytes: dataTotalMatchingBytes,
      symbols: dataResults,
    ),
  );

  final resultFile = File(p.join(buildDirPath, 'verification.json'));
  final jsonEncoder = JsonEncoder.withIndent('  ');
  resultFile.writeAsStringSync(jsonEncoder.convert(result));

  if (compareToBaseline && baselineFileExists) {
    // Show differences from baseline
    print('Differences from baseline:');

    final baselineResults = VerificationResult.fromJson(json.decode(baselineFile.readAsStringSync()));

    final hasTextDifferences = _displayBaselineDifferences(result.text, baselineResults.text, '.text', rw);
    final hasRdataDifferences = _displayBaselineDifferences(result.rdata, baselineResults.rdata, '.rdata', rw);
    final hasDataDifferences = _displayBaselineDifferences(result.data, baselineResults.data, '.data', rw);

    if (!hasTextDifferences && !hasRdataDifferences && !hasDataDifferences) {
      print('  No differences found!');
    }
  } else {
    // Show all non-matching symbols
    print('Non-matching symbols:');

    final nonMatchingText = result.text.symbols.values
        .where((s) => s.nonMatchScore != 0)
        .toList();
    final nonMatchingRdata = result.rdata.symbols.values
        .where((s) => s.nonMatchScore != 0)
        .toList();
    final nonMatchingData = result.data.symbols.values
        .where((s) => s.nonMatchScore != 0)
        .toList();
    
    if (nonMatchingText.isNotEmpty) {
      print('  .text:');
      for (final sym in nonMatchingText) {
        print('    [${_getSymName(sym.address, rw)}] score: ${sym.nonMatchScore}, bytes ${sym.matchingBytes}/${sym.totalBaseBytes}');
      }
    }

    if (nonMatchingRdata.isNotEmpty) {
      print('  .rdata:');
      for (final sym in nonMatchingRdata) {
        print('    [${_getSymName(sym.address, rw)}] score: ${sym.nonMatchScore}, bytes ${sym.matchingBytes}/${sym.totalBaseBytes}');
      }
    }

    if (nonMatchingData.isNotEmpty) {
      print('  .data:');
      for (final sym in nonMatchingData) {
        print('    [${_getSymName(sym.address, rw)}] score: ${sym.nonMatchScore}, bytes ${sym.matchingBytes}/${sym.totalBaseBytes}');
      }
    }

    if (nonMatchingText.isEmpty && nonMatchingRdata.isEmpty && nonMatchingData.isEmpty) {
      print('  No differences found!');
    }
  }

  if (checkSegments) {
    print('');
    print('Segment differences:');

    bool anySegmentDifferences = false;
    
    for (final (objName, segResults) in objSegmentResults) {
      final segRanges = objSegments![p.withoutExtension(objName)]!;
      
      if (segResults.text.isNotEmpty || segResults.rdata.isNotEmpty || segResults.data.isNotEmpty) {
        print('  $objName:');
        anySegmentDifferences = true;
      }

      if (segResults.text.isNotEmpty) {
        final textRange = '0x${segRanges.text!.$1.toRadixString(16)}-0x${segRanges.text!.$2.toRadixString(16)}';

        for (final (addr, symName) in segResults.text) {
          print('    $symName @ 0x${addr.toRadixString(16)} not within range .text $textRange');
        }
      }

      if (segResults.rdata.isNotEmpty) {
        final rdataRange = '0x${segRanges.rdata!.$1.toRadixString(16)}-0x${segRanges.rdata!.$2.toRadixString(16)}';

        for (final (addr, symName) in segResults.rdata) {
          print('    $symName @ 0x${addr.toRadixString(16)} not within range .rdata $rdataRange');
        }
      }

      if (segResults.data.isNotEmpty) {
        final dataRange = '0x${segRanges.data!.$1.toRadixString(16)}-0x${segRanges.data!.$2.toRadixString(16)}';

        for (final (addr, symName) in segResults.data) {
          print('    $symName @ 0x${addr.toRadixString(16)} not within range .data $dataRange');
        }
      }
    }

    if (!anySegmentDifferences) {
      print('  No differences found!');
    }
  }

  if (compareToBaseline && (!baselineFileExists || updateBaseline)) {
    baselineFile!.writeAsStringSync(jsonEncoder.convert(result));

    print('');
    if (updateBaseline) {
      print('Updated baseline.');
    } else {
      print('Created initial baseline.');
    }
  }

  // Done
  exeData.free();
  disassembler.dispose();
  capstoneDll.close();
}

bool _displayBaselineDifferences(VerificationSectionResult newResult, VerificationSectionResult baselineResult,
    String sectionName, RealWarYaml rw) {
  final regressions = <(SymbolVerificationResult, SymbolVerificationResult)>[];
  final improvements = <(SymbolVerificationResult, SymbolVerificationResult)>[];
  final additions = <SymbolVerificationResult>[];
  final deletions = <SymbolVerificationResult>[];

  for (final newSym in newResult.symbols.values) {
    final baselineSym = baselineResult.symbols[newSym.address];
    if (baselineSym == null) {
      additions.add(newSym);
    } else if (newSym.nonMatchScore < baselineSym.nonMatchScore) {
      improvements.add((newSym, baselineSym));
    } else if (newSym.nonMatchScore > baselineSym.nonMatchScore) {
      regressions.add((newSym, baselineSym));
    }
  }

  for (final baselineSym in baselineResult.symbols.values) {
    if (!newResult.symbols.containsKey(baselineSym.address)) {
      deletions.add(baselineSym);
    }
  }

  final hasDifferences = regressions.isNotEmpty || improvements.isNotEmpty 
      || additions.isNotEmpty || deletions.isNotEmpty;
  
  if (hasDifferences) {
    print('  $sectionName:');
    for (final sym in deletions) {
      print('    - ${_getSymName(sym.address, rw)}');
    }
    for (final (newSym, baselineSym) in regressions) {
      print('    < ${_getSymName(newSym.address, rw)} ${baselineSym.nonMatchScore} => ${newSym.nonMatchScore}');
    }
    for (final (newSym, baselineSym) in improvements) {
      print('    > ${_getSymName(newSym.address, rw)} ${baselineSym.nonMatchScore} => ${newSym.nonMatchScore}');
    }
    for (final sym in additions) {
      print('    + ${_getSymName(sym.address, rw)} ${sym.nonMatchScore}');
    }
  }

  return hasDifferences;
}

String _getSymName(int address, RealWarYaml rw) {
  return rw.symbolsByAddress[address]?.name ?? '0x${address.toRadixString(16)}';
}

class VerifyContext {
  final RealWarYaml rw;
  final FunctionDisassembler disassembler;
  final PeFile exe;
  final FileData exeData;
  final List<(int, String)> sortedSymbols;

  VerifyContext({
    required this.rw, 
    required this.disassembler, 
    required this.exe, 
    required this.exeData,
    required this.sortedSymbols,
  });
}

class ObjSegments {
  (int, int)? text;
  (int, int)? rdata;
  (int, int)? data;
}

class VerifyObjSegmentsResult {
  final List<(int, String)> text;
  final List<(int, String)> rdata;
  final List<(int, String)> data;

  VerifyObjSegmentsResult({
    required this.text, 
    required this.rdata, 
    required this.data,
  });
}

VerifyObjSegmentsResult _checkSegments(VerifyContext ctx, ObjSegments segments, CoffFile obj) {
  final List<(int, String)> text = [];
  final List<(int, String)> rdata = [];
  final List<(int, String)> data = [];

  if (segments.text != null) {
    for (final func in _findObjFunctions(obj)) {
      final addr = ctx.rw.symbols[func.symbolName]?.address;
      if (addr != null && (addr < segments.text!.$1 || addr >= segments.text!.$2)) {
        text.add((addr, func.symbolName));
      }
    }
  }

  if (segments.rdata != null) {
    for (final variable in _findObjData(obj, '.rdata')) {
      final addr = ctx.rw.symbols[variable.symbolName]?.address;
      if (addr != null && (addr < segments.rdata!.$1 || addr >= segments.rdata!.$2)) {
        rdata.add((addr, variable.symbolName));
      }
    }
  }

  if (segments.data != null) {
    for (final variable in _findObjData(obj, '.data')) {
      final addr = ctx.rw.symbols[variable.symbolName]?.address;
      if (addr != null && (addr < segments.data!.$1 || addr >= segments.data!.$2)) {
        data.add((addr, variable.symbolName));
      }
    }
  }

  return VerifyObjSegmentsResult(
    text: text,
    rdata: rdata,
    data: data,
  );
}

/// Determines expected segment address ranges for each obj mapped in rw.yaml.
Map<String, ObjSegments> _getObjSegments(RealWarYaml rw) {
  final objs = <String, ObjSegments>{};

  for (int i = 0; i < (rw.segments.length - 1); i++) {
    final segment = rw.segments[i];
    final segmentName = segment.name;

    if (segmentName == null) {
      continue;
    }

    final start = segment.address;
    final end = rw.segments[i + 1].address;
    final range = (start, end);

    switch (segment.type) {
      case 'text':
        objs.update(segmentName, (s) => s..text = range, 
            ifAbsent: () => ObjSegments()..text = range);
      case 'rdata':
        objs.update(segmentName, (s) => s..rdata = range, 
            ifAbsent: () => ObjSegments()..rdata = range);
      case 'data':
        objs.update(segmentName, (s) => s..data = range, 
            ifAbsent: () => ObjSegments()..data = range);
    }
  }

  return objs;
}

class ObjFunction {
  final String symbolName;
  /// The function's COMDAT section.
  final Section section;

  ObjFunction({
    required this.symbolName, 
    required this.section,
  });
}

class ObjGlobalVariable {
  final String symbolName;
  final Section section;
  final int offset;
  int size = 0;

  ObjGlobalVariable({
    required this.symbolName, 
    required this.section,
    required this.offset,
  });
}

class ObjVerificationResult {
  final List<SymbolVerificationResult> text;
  final List<SymbolVerificationResult> rdata;
  final List<SymbolVerificationResult> data;

  ObjVerificationResult({
    required this.text, 
    required this.rdata, 
    required this.data,
  });
}

ObjVerificationResult _verifyObj(VerifyContext ctx, CoffFile obj, Uint8List objBytes) {
  // Verify .text
  final textResults = <SymbolVerificationResult>[];
  final funcs = _findObjFunctions(obj);

  for (final func in funcs) {
    final result = _verifyFunction(ctx, obj, objBytes, func);
    if (result == null) {
      continue;
    }

    textResults.add(result);
  }

  // Verify .data
  final dataResults = <SymbolVerificationResult>[];
  final dataVars = _findObjData(obj, '.data');

  for (final section in obj.sections) {
    if (section.header.name == '.data') {
      _relocateDataSection(ctx, obj, objBytes, section);
    }
  }

  for (final dataVar in dataVars) {
    final result = _verifyDataVariable(ctx, obj, objBytes, dataVar);
    if (result == null) {
      continue;
    }

    dataResults.add(result);
  }

  // Verify .rdata
  final rdataResults = <SymbolVerificationResult>[];
  final rdataVars = _findObjData(obj, '.rdata');

  for (final section in obj.sections) {
    if (section.header.name == '.rdata') {
      _relocateDataSection(ctx, obj, objBytes, section);
    }
  }

  for (final rdataVar in rdataVars) {
    final result = _verifyDataVariable(ctx, obj, objBytes, rdataVar);
    if (result == null) {
      continue;
    }

    rdataResults.add(result);
  }

  return ObjVerificationResult(
    text: textResults, 
    rdata: rdataResults, 
    data: dataResults,
  );
}

List<ObjFunction> _findObjFunctions(CoffFile obj) {
  final funcs = <ObjFunction>[];
  
  if (obj.symbolTable == null) {
    return funcs;
  }

  for (final symbol in obj.symbolTable!.values) {
    // Symbol is a function defined in this object file if it has a section number and MSB == 2
    if (symbol.sectionNumber > 0 && (symbol.type >> 4) == 2) {
      final name = symbol.name.shortName ??
          obj.stringTable!.strings[symbol.name.offset]!;
      
      final Section section = obj.sections[symbol.sectionNumber - 1];

      // Assume COMDAT
      assert(section.header.flags.lnkComdat);
      
      funcs.add(ObjFunction(
        symbolName: unmangle(name), 
        section: section,
      ));
    }
  }

  return funcs;
}

List<ObjGlobalVariable> _findObjData(CoffFile obj, String sectionName) {
  final vars = <ObjGlobalVariable>[];
  final varsGrouped = <int, List<ObjGlobalVariable>>{};
  
  if (obj.symbolTable == null) {
    return vars;
  }

  // Locate all .data symbols
  for (final symbol in obj.symbolTable!.values) {
    if (symbol.sectionNumber <= 0) {
      continue;
    }

    final section = obj.sections[symbol.sectionNumber - 1];
    if (section.header.name != sectionName) {
      continue;
    }

    // Symbols with a value of zero that are static storage and have an aux symbol are section name symbols
    // Those with a value of zero, static storage, but zero aux symbols are static global variables
    if (symbol.value == 0 && symbol.storageClass == StorageClass.static && symbol.auxSymbols.isNotEmpty) {
      continue;
    }

    final name = symbol.name.shortName ??
        obj.stringTable!.strings[symbol.name.offset]!;
    
    if (isLiteralSymbolName(name)) {
      continue;
    }
   
    final variable = ObjGlobalVariable(
      symbolName: unmangle(name), 
      section: section, 
      offset: symbol.value,
    );

    vars.add(variable);
    varsGrouped
        .putIfAbsent(symbol.sectionNumber, () => [])
        .add(variable);
  }

  // Sort symbols per section and determine their byte sizes
  for (final group in varsGrouped.entries) {
    group.value.sort((a, b) => a.offset.compareTo(b.offset));

    for (final (i, v) in group.value.indexed) {
      final varStart = v.offset;
      final varEnd = (i < group.value.length - 1) ? group.value[i + 1].offset : v.section.header.sizeOfRawData;
      
      v.size = _align4(varEnd - varStart);
    }
  }

  return vars;
}

void _relocateDataSection(VerifyContext ctx, CoffFile obj, Uint8List objBytes, Section section) {
  final sectionData = ByteData.sublistView(objBytes);

  for (final reloc in section.relocations) {
    final symbol = obj.symbolTable![reloc.symbolTableIndex]!;
    final symbolName = symbol.name.shortName ??
        obj.stringTable!.strings[symbol.name.offset!]!;
    
    final int? symbolAddress = ctx.rw.lookupSymbol(unmangle(symbolName));

    if (symbolAddress == null) {
      print('Could not find global variable symbol $symbolName in rw.yaml. Skipping relocation...');
      continue;
    }

    if (reloc.type == RelocationTypeI386.dir32) {
      applyRelocation(reloc, sectionData, /*sectionVA not important for dir32*/0, symbolAddress);
    } else {
      throw UnimplementedError('Unimplemented relocation type: ${reloc.type}');
    }
  }
}

SymbolVerificationResult? _verifyDataVariable(VerifyContext ctx, CoffFile obj, Uint8List objBytes, ObjGlobalVariable variable) {
  final symbolName = variable.symbolName;

  final rwSymbol = ctx.rw.symbols[symbolName];
  if (rwSymbol == null) {
    print('Could not find global variable symbol $symbolName in rw.yaml. Skipping...');
    return null;
  }

  final symbolAddress = rwSymbol.address;

  // Note: sizes should include padding due to alignment
  final baseVarSize = rwSymbol.size ?? variable.size; // use size defined in rw.yaml if available 
  final newVarSize = variable.size;

  final baseVarPA = (symbolAddress - ctx.rw.exe.dataVirtualAddress - ctx.rw.exe.imageBase)
      + ctx.rw.exe.dataFileOffset;
  final newVarPA = variable.section.header.pointerToRawData + variable.offset;

  final baseVarBytes = ctx.exeData.data.sublist(baseVarPA, baseVarPA + baseVarSize);
  final newVarBytes = objBytes.sublist(newVarPA, newVarPA + newVarSize);

  int nonMatchScore = 0;
  int matchingBytes = 0;

  final toCompare = math.min(baseVarBytes.length, newVarBytes.length);
  for (int i = 0; i < toCompare; i++) {
    if (baseVarBytes[i] == newVarBytes[i]) {
      matchingBytes++;
    } else {
      nonMatchScore++;
    }
  }

  nonMatchScore += (baseVarBytes.length - newVarBytes.length).abs();

  switch (variable.section.header.name) {
    case '.data':
      if (symbolAddress < ctx.rw.exe.dataVirtualAddress) {
        print('Expected global data variable $symbolName to be declared in .data but it\'s not!');
        nonMatchScore++;
      }
    case '.rdata':
      if (symbolAddress < ctx.rw.exe.rdataVirtualAddress || symbolAddress >= ctx.rw.exe.dataVirtualAddress) {
        print('Expected global data variable $symbolName to be declared in .rdata but it\'s not!');
        nonMatchScore++;
      }
  }

  return SymbolVerificationResult(
    address: symbolAddress,
    nonMatchScore: nonMatchScore,
    matchingBytes: matchingBytes,
    totalBaseBytes: baseVarBytes.length,
  );
}

SymbolVerificationResult? _verifyFunction(VerifyContext ctx, CoffFile obj, Uint8List objBytes, ObjFunction func) {
  final symbolName = func.symbolName;

  final symbolAddress = ctx.rw.symbols[symbolName]?.address;
  if (symbolAddress == null) {
    print('Could not find function symbol $symbolName in rw.yaml. Skipping...');
    return null;
  }

  int nonMatchScore = 0;
  int matchingBytes = 0;

  // Compare instructions
  final baseFuncPA = (symbolAddress - ctx.rw.exe.textVirtualAddress - ctx.rw.exe.imageBase) 
      + ctx.rw.exe.textFileOffset;

  final (baseFunc, baseFuncBytes) = _disassembleExeFunction(ctx, baseFuncPA, symbolAddress, symbolName);
  final (newFunc, newFuncBytes) = _disassembleObjFunction(ctx, obj, objBytes, symbolAddress, func);

  final instructionDiff = runDiff(baseFunc.instructions, newFunc.instructions, 
      InstructionDiffEquality(imageBase: ctx.rw.exe.imageBase));

  for (final line in instructionDiff) {
    switch (line.diffType) {
      case DiffEditType.insert:
      case DiffEditType.delete:
        nonMatchScore++;
      case DiffEditType.equal:
      case DiffEditType.substitute:
        final a = line.target!;
        final b = line.source!;

        bool considerMatching = false;

        if (line.diffType == DiffEditType.equal) {
          if (a == b) {
            considerMatching = true;
          } else if (doInstructionsMatchViaLiteralSymbol(ctx.rw, a, b)) {
            // Instructions aren't the same but we want to consider them equal if the only
            // difference is a reference to a literal symbol and they reference the same literal value
            considerMatching = true;
          }
        }
        
        if (!considerMatching) {
          nonMatchScore++;
        } else {
          matchingBytes += a.bytes.length;
        }
    }
  }

  // Compare jump tables
  if (baseFunc.jumpTables != null) {
    for (final entry in baseFunc.jumpTables!.entries) {
      final jumpTableA = entry.value;
      final jumpTableB = newFunc.jumpTables?[entry.key];

      final jumpTableDiff = runDiff(jumpTableA.cases, jumpTableB?.cases ?? const []);
      for (final line in jumpTableDiff) {
        switch (line.diffType) {
          case DiffEditType.insert:
          case DiffEditType.delete:
          case DiffEditType.substitute:
            nonMatchScore++;
          case DiffEditType.equal:
            matchingBytes += 4;
        }
      }
    }
  } else if (newFunc.jumpTables != null) {
    for (final jumpTable in newFunc.jumpTables!.values) {
      nonMatchScore += jumpTable.cases.length;
    }
  }

  // Compare leftover bytes
  if (baseFuncBytes.length > baseFunc.size && newFuncBytes.length <= newFunc.size) {
    nonMatchScore += baseFuncBytes.length - baseFunc.size;
  } else if (baseFuncBytes.length <= baseFunc.size && newFuncBytes.length > newFunc.size) {
    nonMatchScore += newFuncBytes.length - newFunc.size;
  } else if (baseFuncBytes.length > baseFunc.size && newFuncBytes.length > newFunc.size) {
    for (int i = baseFunc.size, j = newFunc.size; i < baseFuncBytes.length && j < newFuncBytes.length; i++, j++) {
      if (baseFuncBytes[i] != newFuncBytes[j]) {
        nonMatchScore++;
      } else {
        matchingBytes++;
      }
    }

    nonMatchScore += ((newFuncBytes.length - newFunc.size) - (baseFuncBytes.length - baseFunc.size)).abs();
  }

  if (nonMatchScore == 0 && matchingBytes < baseFunc.size) {
    // Score was 0 but not all bytes were matched... shouldn't happen but we don't want to
    // accidentally think this matched
    nonMatchScore++;
  }

  return SymbolVerificationResult(
    address: symbolAddress,
    nonMatchScore: nonMatchScore,
    matchingBytes: matchingBytes,
    totalBaseBytes: baseFuncBytes.length,
  );
}

(DisassembledFunction, Uint8List) _disassembleExeFunction(VerifyContext ctx, int physicalAddress, 
    int virtualAddress, String symbolName) {
  // Get function size or estimate
  final funcSize = ctx.rw.symbols[symbolName]?.size
      ?? ctx.sortedSymbols[ctx.sortedSymbols.indexWhere((s) => s.$1 == virtualAddress) + 1].$1 - virtualAddress;

  final func = ctx.disassembler.disassembleFunction(ctx.exeData, physicalAddress,
      address: virtualAddress, 
      name: symbolName, 
      endAddressHint: virtualAddress + funcSize);

  return (func, Uint8List.sublistView(ctx.exeData.data, physicalAddress, physicalAddress + funcSize));
}

(DisassembledFunction, Uint8List) _disassembleObjFunction(VerifyContext ctx, CoffFile obj, Uint8List objBytes, 
    int virtualAddress, ObjFunction func) {
  // Relocate function .text COMDAT section
  final filePtr = func.section.header.pointerToRawData;
  final funcSize = func.section.header.sizeOfRawData;
  final sectionBytes = Uint8List.sublistView(objBytes, filePtr, filePtr + funcSize);

  relocateSection(obj, func.section, 
      sectionBytes, 
      targetVirtualAddress: virtualAddress, 
      symbolLookup: (sym) => ctx.rw.lookupSymbol(unmangle(sym)));
  
  final funcData = FileData.fromList(sectionBytes);

  final disasmFunc = ctx.disassembler.disassembleFunction(funcData, 0,
      address: virtualAddress, 
      name: func.symbolName,
      endAddressHint: virtualAddress + funcSize);
  
  return (disasmFunc, sectionBytes);
}

int _align4(int value) {
  return (value / 4).ceil() * 4;
}
