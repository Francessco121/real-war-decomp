import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  // Parse args
  final argParser = ArgParser()
      ..addOption('input', abbr: 'i', mandatory: true, help: 'Input C file.')
      ..addOption('output', abbr: 'o', mandatory: true, help: 'Output OBJ file.')
      ..addOption('vsdir', mandatory: true, help: 'Visual Studio directory.')
      ..addMultiOption('include', abbr: 'I', help: 'Include paths.')
      ..addOption('deps', abbr: 'd', help: 'Output header dependencies file.')
      ..addMultiOption('flag', abbr: 'f', help: 'Compiler flags.');
  
  if (args.isEmpty) {
    print('cl_wrapper.dart');
    print(argParser.usage);
    exit(-1);
  }

  final argResults = argParser.parse(args);

  // Build command
  final String vsdir = argResults['vsdir'];
  final String path = [
    '$vsdir\\VC98\\Bin',
    '$vsdir\\Common\\MSDev98\\Bin',
    '$vsdir\\VC98\\Lib',
    Platform.environment['PATH'],
  ].join(';');
  
  final String input = argResults['input'];
  final String output = argResults['output'];
  final List<String> includes = argResults['include'];
  final List<String> flags = argResults['flag'];

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
  clArgs.add(input);

  // Compile
  final result = Process.runSync('$vsdir\\VC98\\Bin\\CL.EXE', clArgs,
    environment: {'PATH': path},
  );

  var stdoutStr = result.stdout.toString();
  final srcEchoLine = p.basename(input);
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

  // Scan for header dependencies
  final deps = _scanIncludes(input, includes.firstWhere((i) => i.startsWith('rw')));

  // Write deps (.d) file
  _writeDepsFile(output, deps);
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

List<String> _scanIncludes(String srcPath, String rwIncludeDir) {
  final includeRegex = RegExp(r'#include ["<](.*)[">]');
  final deps = <String>[srcPath];
  final resolved = <String>{};

  String? resolve(String srcPath, String includePath) {
    // Try path relative to the file that included it
    final relativePath = '${p.dirname(srcPath)}\\$includePath';
    if (File(relativePath).existsSync()) {
      return relativePath;
    } else {
      // Otherwise, try from the include directory
      final fromIncludePath = '$rwIncludeDir\\$includePath';
      if (File(fromIncludePath).existsSync()) {
        return fromIncludePath;
      }

      return null;
    }
  }

  void parseIncludes(String filePath) {
    // Note: This does not respect #if directives
    for (final line in File(filePath).readAsLinesSync()) {
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
        parseIncludes(filePath);
      }
    }
  }

  parseIncludes(srcPath);

  return deps;
}
