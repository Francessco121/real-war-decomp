import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:rw_assets/console_utils.dart';
import 'package:rw_assets/image_utils.dart';
import 'package:rw_assets/tga.dart';
import 'package:rw_assets/tgc.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner('tgc',
      'Tool for converting from and to Real War\'s TGC (Targa Compressed) format.')
    ..addCommand(ToCommand())
    ..addCommand(ToDirCommand())
    ..addCommand(FromCommand())
    ..addCommand(FromDirCommand());

  await runner.run(args);
}

class ToCommand extends Command {
  @override
  final name = 'to';

  @override
  final description = 'Converts a single TGC file to the specified format.';

  ToCommand() {
    argParser
      ..addOption('input',
          abbr: 'i', help: 'The TGC file to convert.', mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The path/filename of the output image to create. '
              'Supports JPEG, PNG, TGA, GIF, TIFF, BMP, and ICO. '
              'Defaults to the input path but as a TGA.')
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
        p.dirname(inputPath), '${p.basenameWithoutExtension(inputPath)}.tga');

    final outputFile = File(outputPath);
    if (outputFile.existsSync() && !force) {
      print(
          'ERR: File already exists at: ${p.normalize(p.absolute(outputPath))}');
      exit(-1);
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      print(
          'ERR: Could not find input file at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    await _tgcToImage(inputFile, outputFile);

    print(
        'Converted TGC to image: ${p.normalize(p.absolute(outputFile.path))}');
  }
}

class ToDirCommand extends Command {
  @override
  final name = 'to-dir';

  @override
  final description =
      'Converts all .tgc files in a directory to the specified image format.';

  ToDirCommand() {
    argParser
      ..addOption('input',
          abbr: 'i',
          help: 'The directory to scan for TGC files.',
          mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The directory to output the converted images to.',
          mandatory: true)
      ..addOption('format',
          abbr: 'F',
          help: 'The format to convert each TGC file to.',
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

      if (p.extension(file.path).toLowerCase() == '.tgc') {
        files.add(file);
      }
    }

    if (files.isEmpty) {
      progress.break$();
      print('No TGC files found in: ${p.normalize(p.absolute(inputPath))}');
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
      final filename = '${p.basenameWithoutExtension(file.path)}.$format';
      final outputFile =
          File(p.join(outputPath, p.dirname(relativePath), filename));

      if (outputFile.existsSync() && !force) {
        progress.break$();
        print(
            'ERR: File already exists at: ${p.normalize(p.absolute(outputFile.path))}');
        exit(-1);
      }

      outputFile.parent.createSync(recursive: true);
      await _tgcToImage(file, outputFile);

      progress.incrementBar();
    }
    
    progress.break$();
    print('Wrote images to: ${p.normalize(p.absolute(outputPath))}');
  }
}

class FromCommand extends Command {
  @override
  final name = 'from';

  @override
  final description = 'Converts a single image to a TGC file.';

  FromCommand() {
    argParser
      ..addOption('input',
          abbr: 'i',
          help:
              'The image file to convert. Supports JPEG, PNG, TGA, GIF, TIFF, BMP, and ICO.',
          mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The path/filename of the output TGC to create. '
              'Defaults to the input path but with a .tgc extension.')
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
        p.dirname(inputPath), '${p.basenameWithoutExtension(inputPath)}.tgc');

    final outputFile = File(outputPath);
    if (outputFile.existsSync() && !force) {
      print(
          'ERR: File already exists at: ${p.normalize(p.absolute(outputPath))}');
      exit(-1);
    }

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      print(
          'ERR: Could not find input file at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    _imageToTgc(inputFile, outputFile);

    print('Wrote TGC file to: ${p.normalize(p.absolute(outputFile.path))}');
  }
}

class FromDirCommand extends Command {
  @override
  final name = 'from-dir';

  @override
  final description =
      'Converts all image files in a directory of the given format to TGC files.';

  FromDirCommand() {
    argParser
      ..addOption('input',
          abbr: 'i',
          help: 'The directory to scan for image files.',
          mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The directory to output the TGC files to.',
          mandatory: true)
      ..addOption('format',
          abbr: 'F',
          help:
              'The image format to convert to TGC. Only files matching this type will be converted.',
          allowed: const ['tga', 'jpg', 'jpeg', 'png', 'gif', 'tif', 'tiff', 'bmp'],
          defaultsTo: 'tga')
      ..addFlag('recursive',
          abbr: 'r', help: 'Recurse through all sub-directories.')
      ..addFlag('update',
          abbr: 'u',
          help:
              'Overwrite existing files only if they are older than the source image. '
              'Overridden by --force.')
      ..addFlag('force',
          abbr: 'f',
          help: 'Always overwrite existing files. Overrides --update.',
          defaultsTo: false);
  }

  @override
  Future<void> run() async {
    final String inputPath = argResults!['input'];
    final String outputPath = argResults!['output'];
    final String format = argResults!['format'];
    final bool recursive = argResults!['recursive'];
    final bool update = argResults!['update'];
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

    final inputFiles = <File>[];
    final outputFiles = <File>[];
    bool foundAnything = false;
    for (final file in inputDir.listSync(recursive: recursive)) {
      if (file is! File) {
        continue;
      }

      if (p.extension(file.path).toLowerCase() == '.$format') {
        foundAnything = true;

        final relativePath = p.relative(file.path, from: inputPath);
        final outputFilename = '${p.basenameWithoutExtension(file.path)}.tgc';
        final outputFile =
            File(p.join(outputPath, p.dirname(relativePath), outputFilename));
        final exists = outputFile.existsSync();
        
        if (!exists || force || (update && file.lastModifiedSync().isAfter(outputFile.lastModifiedSync()))) {
          inputFiles.add(file);
          outputFiles.add(outputFile);
        } else if (exists && !force && !update) {
          progress.break$();
          print(
              'ERR: File already exists at: ${p.normalize(p.absolute(file.path))}');
          exit(-1);
        }
      }
    }

    if (inputFiles.isEmpty) {
      if (foundAnything && update) {
        progress.break$();
        print('All TGC files are already up-to-date.');
        exit(0);
      } else {
        progress.break$();
        print('No ${format.toUpperCase()} files found in: ${p.normalize(p.absolute(inputPath))}');
        exit(-1);
      }
    }

    progress
      ..break$()
      ..barMax = inputFiles.length
      ..barValue = 0
      ..label = 'Converting'
      ..incrementStep()
      ..restartTimer()
      ..startAutoRender();

    for (int i = 0; i < inputFiles.length; i++) {
      final inputFile = inputFiles[i];
      final outputFile = outputFiles[i];

      outputFile.parent.createSync(recursive: true);
      _imageToTgc(inputFile, outputFile);

      progress.incrementBar();
    }

    progress.break$();
    print('Wrote TGCs to: ${p.normalize(p.absolute(outputPath))}');
  }
}

Future<void> _tgcToImage(File inputFile, File outputFile) async {
  final tgc = readTgc(inputFile.readAsBytesSync());

  if (p.extension(outputFile.path).toLowerCase() == '.tga') {
    final imageDataBottomToTop =
        imageVerticalFlip(tgc.imageBytes, tgc.header.width, tgc.header.height);
    final tga = make16BitTarga(imageDataBottomToTop, tgc.header.width, tgc.header.height);

    outputFile.writeAsBytesSync(tga);
  } else {
    final rgba32 = argb1555ToRgba8888(tgc.imageBytes);

    final image = img.Image.fromBytes(
        width: tgc.header.width,
        height: tgc.header.height,
        bytes: rgba32.buffer,
        format: img.Format.uint8,
        numChannels: 4,
        order: img.ChannelOrder.rgba);

    await img.encodeImageFile(outputFile.path, image);
  }
}

void _imageToTgc(File inputFile, File outputFile) {
  var image = img.decodeNamedImage(inputFile.path, inputFile.readAsBytesSync());
  if (image == null) {
    print(
        'ERR: Could not find decoder for: ${p.normalize(p.absolute(inputFile.path))}');
    exit(-1);
  }

  if (image.numChannels != 3 && image.numChannels != 4) {
    print('ERR: Input image must have 3 or 4 channels.');
    exit(-1);
  }

  image = image.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
  image.remapChannels(img.ChannelOrder.rgba);

  final Uint8List argb1555 = rgba8888ToArgb1555(image.toUint8List());
  final header = TgcHeader(image.width, image.height);
  final tgcBytes = makeTgc(header, argb1555);

  outputFile.writeAsBytesSync(tgcBytes);
}
