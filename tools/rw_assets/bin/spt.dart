import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rw_assets/console_utils.dart';
import 'package:rw_assets/image_utils.dart';
import 'package:rw_assets/spt.dart';
import 'package:rw_assets/tga.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner('spt',
      'Tool for converting from and to Real War\'s SPT (Sprite Table) format.')
    ..addCommand(ToCommand())
    ..addCommand(ToDirCommand());

  await runner.run(args);
}

class ToCommand extends Command {
  @override
  final name = 'to';

  @override
  final description = 'Extracts a single SPT file to a directory.';

  ToCommand() {
    argParser
      ..addOption('input',
          abbr: 'i', help: 'The SPT file to convert.', mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The path of the output directory to extract each frame to. '
              'Defaults to a folder next to the input with the same name without an extension.')
      ..addOption('format',
          abbr: 'F',
          help: 'The format to convert each SPT frame to.',
          allowed: const ['tga', 'jpg', 'png', 'gif', 'tiff', 'bmp'],
          defaultsTo: 'tga')
      ..addFlag('force',
          abbr: 'f',
          help: 'Whether any existing output files should be overwritten.',
          defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final String inputPath = argResults!['input'];
    String? outputPath = argResults!['output'];
    final bool force = argResults!['force'];
    final String format = argResults!['format'];

    outputPath ??= p.join(
        p.dirname(inputPath), p.basenameWithoutExtension(inputPath));

    final outputDirectory = Directory(outputPath);
    if (outputDirectory.existsSync() && !force) {
      print(
          'ERR: Directory already exists at: ${p.normalize(p.absolute(outputPath))}');
      exit(-1);
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      print(
          'ERR: Could not find input file at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    await outputDirectory.create();

    final spt = readSpt(await inputFile.readAsBytes());
    for (final (i, frame) in spt.frames.indexed) {
      final outputFile = File(p.join(outputPath, 'frame$i.$format'));
      if (outputFile.existsSync() && !force) {
        print(
            'ERR: File already exists at: ${p.normalize(p.absolute(outputFile.path))}');
        exit(-1);
      }

      await _sptFrameToImage(frame, outputFile);
    }

    print(
        'Extracted SPT to: ${p.normalize(p.absolute(outputDirectory.path))}');
  }
}

class ToDirCommand extends Command {
  @override
  final name = 'to-dir';

  @override
  final description =
      'Extracts all .spt files in a directory to another directory';

  ToDirCommand() {
    argParser
      ..addOption('input',
          abbr: 'i',
          help: 'The directory to scan for SPT files.',
          mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The directory to output the extracted images to.',
          mandatory: true)
      ..addOption('format',
          abbr: 'F',
          help: 'The format to convert each SPT frame to.',
          allowed: const ['tga', 'jpg', 'png', 'gif', 'tiff', 'bmp'],
          defaultsTo: 'tga')
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
    final String format = argResults!['format'];
    final bool recursive = argResults!['recursive'];
    final bool force = argResults!['force'];

    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      print(
          'ERR: Could not find input directory at: ${p.normalize(p.absolute(inputPath))}');
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

      if (p.extension(file.path).toLowerCase() == '.spt') {
        files.add(file);
      }
    }

    if (files.isEmpty) {
      progress.break$();
      print('No SPT files found in: ${p.normalize(p.absolute(inputPath))}');
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
      final dirName = p.basenameWithoutExtension(file.path);
      final fileOutputDir = Directory(p.join(outputPath, p.dirname(relativePath), dirName));

      fileOutputDir.createSync(recursive: true);

      final spt = readSpt(await file.readAsBytes());

      for (final (i, frame) in spt.frames.indexed) {
        final filename = 'frame$i.$format';
        final outputFile = File(p.join(fileOutputDir.path, filename));
        if (outputFile.existsSync() && !force) {
          print(
              'ERR: File already exists at: ${p.normalize(p.absolute(outputFile.path))}');
          exit(-1);
        }

        await _sptFrameToImage(frame, outputFile);
      }

      progress.incrementBar();
    }
    
    progress.break$();
    print('Extracted SPT files to: ${p.normalize(p.absolute(outputPath))}');
  }
}

Future<void> _sptFrameToImage(SptFrame frame, File outputFile) async {
  if (p.extension(outputFile.path).toLowerCase() == '.tga') {
    final imageDataBottomToTop =
        imageVerticalFlip(frame.imageBytes, frame.width, frame.height);
    final tga = make16BitTarga(imageDataBottomToTop, frame.width, frame.height);

    outputFile.writeAsBytesSync(tga);
  } else {
    final rgba32 = argb1555ToRgba8888(frame.imageBytes);

    final image = img.Image.fromBytes(
        width: frame.width,
        height: frame.height,
        bytes: rgba32.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba);

    await img.encodeImageFile(outputFile.path, image);
  }
}
