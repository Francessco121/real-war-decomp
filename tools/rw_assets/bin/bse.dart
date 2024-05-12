import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:rw_assets/bse.dart';
import 'package:rw_assets/bse_gltf.dart';
import 'package:rw_assets/console_utils.dart';
import 'package:rw_assets/tgc.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner('bse',
      'Tool for converting Real War\'s BSE model files to glTF.')
    ..addCommand(ToCommand())
    ..addCommand(ToDirCommand());

  await runner.run(args);
}

class ToCommand extends Command {
  @override
  final name = 'to';

  @override
  final description = 'Converts a single BSE model file to glTF (excluding animation).';

  ToCommand() {
    argParser
      ..addOption('input',
          abbr: 'i', help: 'The BSE file to convert.', mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The path/filename of the output model to create. '
              'Defaults to the input path but as a glTF.')
      ..addFlag('force',
          abbr: 'f',
          help: 'Whether an existing output file should be overwritten.',
          defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final String inputPath = argResults!['input'];
    String? outputPath = argResults!['output'];
    final bool force = argResults!['force'];

    outputPath ??= p.join(
        p.dirname(inputPath), '${p.basenameWithoutExtension(inputPath)}.gltf');

    final outputFile = File(outputPath);
    if (outputFile.existsSync() && !force) {
      print('ERR: File already exists at: ${p.normalize(p.absolute(outputPath))}');
      exit(-1);
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      print('ERR: Could not find input file at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    _bseToGltf(inputFile, outputFile);

    print('Converted BSE to glTF: ${p.normalize(p.absolute(outputFile.path))}');
  }
}

class ToDirCommand extends Command {
  @override
  final name = 'to-dir';

  @override
  final description =
      'Converts all .BSE model files in a directory to glTF files (excluding animation).';

  ToDirCommand() {
    argParser
      ..addOption('input',
          abbr: 'i',
          help: 'The directory to scan for BSE files.',
          mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The directory to output the converted files to.',
          mandatory: true)
      ..addFlag('recursive',
          abbr: 'r', help: 'Recurse through all sub-directories.')
      ..addFlag('force',
          abbr: 'f',
          help: 'Whether an existing output file should be overwritten.',
          defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final String inputPath = argResults!['input'];
    final String outputPath = argResults!['output'];
    final bool recursive = argResults!['recursive'];
    final bool force = argResults!['force'];

    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      print('ERR: Could not find input directory at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    final progress = ConsoleProgress()
      ..step = 1
      ..steps = 2
      ..label = 'Scanning'
      ..timer = true
      ..startTimer()
      ..startAutoRender();

    final files = <File>[];
    for (final file in inputDir.listSync(recursive: recursive)) {
      if (file is! File) {
        continue;
      }

      if (p.extension(file.path).toLowerCase() == '.bse') {
        files.add(file);
      }
    }

    if (files.isEmpty) {
      progress.break$();
      print('No BSE files found in: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    progress
      ..break$()
      ..barMax = files.length
      ..barValue = 0
      ..label = 'Converting'
      ..incrementStep()
      ..restartTimer()
      ..startAutoRender();

    for (final file in files) {
      final relativePath = p.relative(file.path, from: inputPath);
      final filename = '${p.basenameWithoutExtension(file.path)}.gltf';
      final outputFile =
          File(p.join(outputPath, p.dirname(relativePath), filename));

      if (outputFile.existsSync() && !force) {
        progress.break$();
        print('ERR: File already exists at: ${p.normalize(p.absolute(outputFile.path))}');
        exit(-1);
      }

      outputFile.parent.createSync(recursive: true);
      _bseToGltf(file, outputFile);

      progress.incrementBar();
    }
    
    progress.break$();
    print('Wrote glTF files to: ${p.normalize(p.absolute(outputPath))}');
  }
}

void _bseToGltf(File inputFile, File outputFile) {
  final bseBytes = inputFile.readAsBytesSync();
  final bse = readBse(bseBytes);

  final textureFile = File('${p.withoutExtension(inputFile.path)}.tgc');
  final texture = textureFile.existsSync() ? readTgc(textureFile.readAsBytesSync()) : null;

  final gltf = bseToGltf(bse, texture);

  outputFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(gltf));
}
