import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:rw_assets/bigfile.dart';
import 'package:rw_assets/console_utils.dart';

void main(List<String> args) {
  CommandRunner('bigfile',
      'Tool for packing/unpacking Real War\'s bigfile.dat asset file.')
    ..addCommand(PackCommand())
    ..addCommand(UnpackCommand())
    ..run(args);
}

class UnpackCommand extends Command {
  @override
  final name = 'unpack';

  @override
  final description = 'Unpack all files in a bigfile.dat into a directory.';

  UnpackCommand() {
    argParser
      ..addOption('input',
          abbr: 'i', help: 'The bigfile.dat to unpack.', mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The directory to unpack the files into.',
          mandatory: true)
      ..addFlag('ignore-duplicates',
          help: 'Whether duplicate files should be ignored.', defaultsTo: true)
      ..addFlag('force',
          abbr: 'f',
          help: 'Whether existing files should be overwritten.',
          defaultsTo: false);
  }

  @override
  void run() {
    final String inputPath = argResults!['input'];
    final String outputPath = argResults!['output'];
    final bool ignoreDuplicates = argResults!['ignore-duplicates'];
    final bool force = argResults!['force'];

    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      print(
          'ERR: Could not find input file at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    final sigintSubscription =
        ProcessSignal.sigint.watch().listen((event) => exit(-1));

    final Uint8List bigfileBytes = inputFile.readAsBytesSync();

    final Bigfile bigfile;
    try {
      bigfile = Bigfile.fromBytes(bigfileBytes);
    } on Exception catch (ex) {
      print('ERR: Failed to parse bigfile: $ex');
      exit(-1);
    }

    final progress = ConsoleProgress()
      ..label = 'Unpacking'
      ..timer = true
      ..barMax = bigfile.entries.length
      ..barValue = 0
      ..startTimer()
      ..startAutoRender();

    final paths = <String>{};
    entryLoop:
    for (final entry in bigfile.entries) {
      String path = entry.path;
      while (paths.contains(path)) {
        if (ignoreDuplicates) {
          continue entryLoop;
        } else {
          path = '$path.duplicate';
        }
      }
      paths.add(path);

      final file = File(p.normalize(p.join(outputPath, path)));
      if (file.existsSync() && !force) {
        progress.break$();
        print(
            'ERR: File already exists at: ${p.normalize(p.absolute(file.path))}');
        exit(-1);
      }

      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(Uint8List.sublistView(
          bigfileBytes, entry.byteOffset, entry.byteOffset + entry.sizeBytes));

      progress.incrementBar();
    }

    progress.break$();
    print('Unpacked files to: ${p.normalize(p.absolute(outputPath))}');
    sigintSubscription.cancel();
  }
}

class PackCommand extends Command {
  @override
  final name = 'pack';

  @override
  final description = 'Pack a directory into a new bigfile.dat file.';

  PackCommand() {
    argParser
      ..addOption('input',
          abbr: 'i',
          help:
              'The directory to pack. Ideally should contain a DATA directory.',
          mandatory: true)
      ..addOption('output',
          abbr: 'o',
          help: 'The path/filename of the output bigfile to create.',
          mandatory: true)
      ..addFlag('force',
          abbr: 'f',
          help: 'Whether an existing output file should be overwritten.',
          defaultsTo: false);
  }

  @override
  void run() {
    final String inputPath = argResults!['input'];
    final String outputPath = argResults!['output'];
    final bool force = argResults!['force'];

    final outputFile = File(outputPath);
    if (outputFile.existsSync() && !force) {
      print(
          'ERR: File already exists at: ${p.normalize(p.absolute(outputPath))}');
      exit(-1);
    }

    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      print(
          'ERR: Could not find input directory at: ${p.normalize(p.absolute(inputPath))}');
      exit(-1);
    }

    final sigintSubscription =
        ProcessSignal.sigint.watch().listen((event) => exit(-1));

    final progress = ConsoleProgress()
      ..label = 'Scanning'
      ..timer = true
      ..steps = 3
      ..step = 1
      ..startTimer()
      ..startAutoRender();

    final files = <File>[];
    for (final file in inputDir.listSync(recursive: true)) {
      if (file is! File) {
        continue;
      }

      files.add(file);
    }

    progress
      ..break$()
      ..barMax = files.length
      ..barValue = 0
      ..label = 'Computing header'
      ..incrementStep()
      ..restartTimer()
      ..startAutoRender();

    final headerSize = files.length * BigfileEntry.headerSize + 4;
    final entries = <BigfileEntry>[];
    int dataOffset = headerSize;

    for (final file in files) {
      final fileSize = file.statSync().size;

      String path = p.normalize(p.relative(file.path, from: inputPath));
      // bigfile supports paths with forward slash and colon separators as well as
      // mixed case, but the game expects backlash separators and all uppercase
      path = path.replaceAll(RegExp(r'[/|:]'), '\\').toUpperCase();

      if (path.length > BigfileEntry.maxPathLength) {
        progress.break$();
        print('ERR: Path $path is too long!');
        exit(-1);
      }

      entries.add(BigfileEntry(
          path: path,
          pathHash: computeBigfileEntryPathHash(path),
          byteOffset: dataOffset,
          sizeBytes: fileSize));

      dataOffset += fileSize;

      progress.incrementBar();
    }

    progress
      ..break$()
      ..barMax = entries.length
      ..barValue = 0
      ..label = 'Packing'
      ..incrementStep()
      ..restartTimer()
      ..startAutoRender();

    int i = 0;

    final builder = BytesBuilder(copy: false);
    builder.add((ByteData(4)..setUint32(0, entries.length, Endian.little))
        .buffer
        .asUint8List());

    for (final entry in entries) {
      builder.add(entry.toBytes());

      if ((i++) % 2 == 0) {
        progress.incrementBar();
      }
    }

    for (final file in files) {
      builder.add(file.readAsBytesSync());

      if ((i++) % 2 == 0) {
        progress.incrementBar();
      }
    }

    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsBytesSync(builder.takeBytes());

    progress.break$();
    print('Packed files into: ${p.normalize(p.absolute(outputFile.path))}');

    sigintSubscription.cancel();
  }
}
