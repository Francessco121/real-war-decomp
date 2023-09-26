import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';

/// cl_wrapper exists to solve the following issues:
/// - Provide an easy way to invoke CL.EXE without the pain of batch/powershell
///   (escaping strings passed to this compiler is a complete nightmare AND we
///   need to change the PATH environment variable which is also a nightmare).
/// - Generate a .d header dependencies file for Ninja (CL.EXE doesn't have an
///   option to do this for us).
/// - Provide support for stitching in original function assembly in the middle
///   of a file via the custom ASM_FUNC pragma.
Future<void> main(List<String> args) async {
  // Parse args
  final argParser = ArgParser()
      ..addOption('input', abbr: 'i', mandatory: true, help: 'Input C file.')
      ..addOption('output', abbr: 'o', mandatory: true, help: 'Output OBJ file.')
      ..addOption('vsdir', mandatory: true, help: 'Visual Studio directory.')
      ..addOption('asmfuncdir', help: 'Directory containing raw function assembly for ASM_FUNC.')
      ..addMultiOption('include', abbr: 'I', help: 'Include paths.')
      ..addOption('deps', abbr: 'd', help: 'Output header dependencies file.')
      ..addMultiOption('flag', abbr: 'f', help: 'Compiler flags.');
  
  if (args.isEmpty) {
    print('cl_wrapper.dart');
    print(argParser.usage);
    exit(-1);
  }

  final argResults = argParser.parse(args);

  final String vsdir = argResults['vsdir'];
  final String? asmfuncdir = argResults['asmfuncdir'];
  final String input = argResults['input'];
  final String output = argResults['output'];
  final List<String> includes = argResults['include'];
  final List<String> flags = argResults['flag'];

  // Analyze input C file (find header dependencies and ASM_FUNC pragmas)
  final inputLines = File(input).readAsLinesSync();

  final deps = _scanIncludes(input, inputLines, 
      includes.where((i) => !i.startsWith(vsdir)));
  
  final AsmFuncInfo? asmFuncInfo;
  if (asmfuncdir != null) {
    final defines = flags
        .where((f) => f.startsWith('/D'))
        .map((f) => f.substring(2))
        .toSet();
    final asmFuncs = _scanAsmFuncPragmas(inputLines, defines);

    // If we need to, preprocess the input file for ASM_FUNC
    if (asmFuncs.isNotEmpty) {
      asmFuncInfo = await _asmFuncPreprocess(asmFuncs, asmfuncdir, input, inputLines);
    } else {
      asmFuncInfo = null;
    }
  } else {
    asmFuncInfo = null;
  }

  // Build command
  final String path = [
    '$vsdir\\VC98\\Bin',
    '$vsdir\\Common\\MSDev98\\Bin',
    '$vsdir\\VC98\\Lib',
    Platform.environment['PATH'],
  ].join(';');

  final clArgs = [
    '/nologo', // don't output logo/banner
    '/c', // don't link
  ];

  for (final include in includes) {
    clArgs.add('/I');
    clArgs.add(include);
  }

  clArgs.add('/Fo$output');
  clArgs.addAll(flags);
  clArgs.add(asmFuncInfo?.preprocessedInput ?? input);

  // Compile
  final result = Process.runSync('$vsdir\\VC98\\Bin\\CL.EXE', clArgs,
    environment: {'PATH': path},
  );

  if (asmFuncInfo != null) {
    File(asmFuncInfo.preprocessedInput).deleteSync();
  }

  var stdoutStr = result.stdout.toString();
  if (asmFuncInfo != null) {
    // Get rid of the temp path for clarity
    stdoutStr = stdoutStr.replaceAll('${Directory.systemTemp.path}\\', '');

    // Fix line numbers
    final inputName = p.basenameWithoutExtension(input);
    final lineNumberRegex = RegExp('$inputName\\.preprocessed\\.c\\(([0-9]+)\\)');
    stdoutStr = stdoutStr.replaceAllMapped(lineNumberRegex, (match) {
      final preprocessedLineNumber = int.parse(match.group(1)!);
      final srcLineNumber = asmFuncInfo!.lineNumberMap[preprocessedLineNumber];
      return '$inputName.c($srcLineNumber)';
    });
  }
  final srcEchoLine = p.basename(asmFuncInfo?.preprocessedInput ?? input);
  if (stdoutStr.startsWith(srcEchoLine)) {
    // CL annoyingly echos the source file name, strip it out
    stdoutStr = stdoutStr.substring(srcEchoLine.length + 2);
  }

  stdout.write(stdoutStr);
  stderr.write(result.stderr);

  if (result.exitCode == -1073741515) {
    // Env is incorrect
    stderr.writeln('CL.EXE returned STATUS_DLL_NOT_FOUND. Is PATH correct?');
  }

  if (result.exitCode != 0) {
    exit(1);
  }

  // Write deps (.d) file
  _writeDepsFile(output, deps);

  // Stitch in actual function assembly for ASM_FUNCs
  if (asmFuncInfo != null && asmFuncInfo.asmFuncs.isNotEmpty && asmFuncInfo.asmFuncs.any((f) => !f.skipped)) {
    _stitchInAsmFuncs(asmFuncInfo.asmFuncs, asmFuncInfo.asmFuncBytes, output);
  }
}

class AsmFuncInfo {
  final List<AsmFuncPragma> asmFuncs;
  final String preprocessedInput;
  final Map<String, Uint8List> asmFuncBytes;
  final Map<int, int> lineNumberMap;

  AsmFuncInfo(this.asmFuncs, this.preprocessedInput, this.asmFuncBytes, this.lineNumberMap);
}

class AsmFuncPragma {
  final int lineIndex;
  final String funcName;
  final bool skipped;

  AsmFuncPragma(this.lineIndex, this.funcName, this.skipped);
}

final _pragmaAsmFuncRegex = RegExp(r'^#pragma(?:\s+)ASM_FUNC(?:\s+)(\S+)');

void _stitchInAsmFuncs(
  List<AsmFuncPragma> asmFuncs, 
  Map<String, Uint8List> asmFuncBytes,
  String output,
) {
  // Load .obj
  final objectFile = File(output);
  final bytes = objectFile.readAsBytesSync();
  final obj = CoffFile.fromList(bytes);

  // Replace each ASM_FUNC function
  for (final asmFuncPragma in asmFuncs) {
    if (asmFuncPragma.skipped) {
      continue;
    }

    final mangledFuncName = '_${asmFuncPragma.funcName}';

    final SymbolTableEntry symbol = obj.symbolTable!.values.firstWhere((sym) {
      final name =
          sym.name.shortName ?? obj.stringTable!.strings[sym.name.offset]!;
      return mangledFuncName == name;
    });
    // NOTE: Functions may be compiled as COMDATs, so there's possibly more than one .text section.
    // The symbol specifies which section exactly and a relative offset within it.
    final int textFileAddress =
        obj.sections[symbol.sectionNumber - 1].header.pointerToRawData;

    final int funcFileAddress = textFileAddress + symbol.value;

    final funcBytes = asmFuncBytes[asmFuncPragma.funcName]!;

    for (int i = 0; i < funcBytes.lengthInBytes; i++) {
      bytes[funcFileAddress + i] = funcBytes[i];
    }
  }

  // Write out new .obj
  objectFile.writeAsBytesSync(bytes);
}

Future<AsmFuncInfo> _asmFuncPreprocess(
  List<AsmFuncPragma> asmFuncs, 
  String asmfuncdir,
  String input,
  List<String> inputLines,
) async {
  final String? preprocessedInput;
  final Map<String, Uint8List> asmFuncBytes = {};
  final Map<int, int> lineNumberMap = {};

  for (final asmFuncPragma in asmFuncs) {
    if (asmFuncPragma.skipped) {
      // Skipped, just remove the #pragma
      inputLines[asmFuncPragma.lineIndex] = '';
      continue;
    }

    final funcBinFile = File(p.join(asmfuncdir, '${asmFuncPragma.funcName}.bin'));
    if (!funcBinFile.existsSync()) {
      stderr.writeln(
          '${p.basename(input)}(${asmFuncPragma.lineIndex + 1}) : Could not find ASM_FUNC file ${funcBinFile.path}');
      exit(1);
    }

    final bytes = funcBinFile.readAsBytesSync();
    asmFuncBytes[asmFuncPragma.funcName] = bytes;

    // Replace the pragma with inline assembly that results in a nop'd function of the exact
    // same amount of bytes required to fit the actual function assembly, we will stitch in
    // the real bytes after compilation
    final buffer = StringBuffer();
    buffer.writeln('void ${asmFuncPragma.funcName}() {');
    buffer.writeln('    __asm');
    buffer.writeln('    {');
    // Note: The final RET is automatically included by the compiler
    for (int i = 0; i < (bytes.lengthInBytes - 1); i++) {
      buffer.writeln('        NOP');
    }
    buffer.writeln('    }');
    buffer.write('}');

    inputLines[asmFuncPragma.lineIndex] = buffer.toString();
  }

  preprocessedInput = p.join(Directory.systemTemp.path, 
      '${p.basenameWithoutExtension(input)}.preprocessed.c');
  await (File(preprocessedInput).openWrite()
    ..writeAll(inputLines, '\n'))
    .close();
  
  const newlineChar = 10;
  int preprocessedLine = 1;
  for (int i = 0; i < inputLines.length; i++) {
    final newLineCount = inputLines[i].codeUnits
        .fold(0, (sum, c) => c == newlineChar ? (sum + 1) : sum);
    
    for (int j = 0; j < (newLineCount + 1); j++) {
      lineNumberMap[preprocessedLine++] = i + 1;
    }
  }

  return AsmFuncInfo(asmFuncs, preprocessedInput, asmFuncBytes, lineNumberMap);
}

List<AsmFuncPragma> _scanAsmFuncPragmas(List<String> lines, Set<String> defines) {
  final asmFuncs = <AsmFuncPragma>[];

  List<bool> skipStack = [];
  bool skipping = false;

  bool evaluate(String expr) {
    final number = int.tryParse(expr);
    if (number != null) {
      return number != 0;
    }

    return defines.contains(expr);
  }

  String arg(String line, int idx) {
    final parts = line.split(' ');
    if ((idx + 1) < parts.length) {
      return parts[idx + 1];
    } else {
      return '';
    }
  }

  String rest(String line) {
    final spaceIdx = line.indexOf(' ');
    if (spaceIdx < 0) {
      return '';
    } else {
      return line.substring(spaceIdx + 1);
    }
  }

  void push(bool skip) {
    skipStack.add(skipping);
    skipping = skip;
  }

  void pop() {
    skipping = skipStack.removeLast();
  }

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('#if')) {
      push(!evaluate(rest(line)));
    } else if (line.startsWith('#ifdef')) {
      push(!defines.contains(arg(line, 0)));
    } else if (line.startsWith('#ifndef')) {
      push(defines.contains(arg(line, 0)));
    } else if (line.startsWith('#elif')) {
      pop();
      push(!evaluate(rest(line)));
    } else if (line.startsWith('#else')) {
      skipping = !skipping;
    } else if (line.startsWith('#endif')) {
      pop();
    } else {
      final asmFunc = _pragmaAsmFuncRegex.firstMatch(line)?.group(1);
      if (asmFunc != null) {
        asmFuncs.add(AsmFuncPragma(i, asmFunc, skipping));
      }
    }
  }

  return asmFuncs;
}

void _writeDepsFile(String output, List<String> deps) {
  final buffer = StringBuffer();

  int chars = 0;

  buffer.write(output);
  buffer.write(':');

  chars += output.length + 1;

  for (final dep in deps) {
    final strLen = dep.length + 1;

    // Line break at 80 characters (matches what gcc does)
    if ((chars + strLen) >= 80) {
      buffer.write(' \\\n');
      chars = 0;
    }

    buffer.write(' ');
    buffer.write(dep);

    chars += strLen + 1;
  }

  buffer.write('\n');

  File('$output.d').writeAsStringSync(buffer.toString());
}

List<String> _scanIncludes(String srcPath, List<String> srcLines, Iterable<String> includeDirs) {
  final includeRegex = RegExp(r'#include ["<](.*)[">]');
  final deps = <String>[srcPath];
  final resolved = <String>{};
  final fromIncludeDirCache = <String, String>{};

  String? resolve(String srcPath, String includePath) {
    // Try path relative to the file that included it
    final relativePath = '${p.dirname(srcPath)}\\$includePath';
    if (File(relativePath).existsSync()) {
      return relativePath;
    } else {
      // Otherwise, try from the include directories
      String? fromIncludePath = fromIncludeDirCache[includePath];
      
      if (fromIncludePath == null) {
        for (final includeDir in includeDirs) {
          final tryIncludePath = '$includeDir\\$includePath';
          if (File(tryIncludePath).existsSync()) {
            fromIncludePath = tryIncludePath;
            fromIncludeDirCache[includePath] = tryIncludePath;
            break;
          }
        }
      }

      return fromIncludePath;
    }
  }

  void parseIncludes(String filePath, List<String> lines) {
    // Note: This does not respect #if directives
    for (final line in lines) {
      // Find #include's in the file
      final match = includeRegex.firstMatch(line);
      if (match == null) {
        continue;
      }

      // Resolve the full path
      final includePath = resolve(filePath, match.group(1)!);

      // If the path was resolved and not a duplicate, add it to the deps list
      if (includePath != null && !resolved.contains(includePath)) {
        deps.add(includePath);
        resolved.add(includePath);

        // Recurse into included file
        parseIncludes(includePath, File(includePath).readAsLinesSync());
      }
    }
  }

  parseIncludes(srcPath, srcLines);

  return deps;
}
