import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:console_bars/console_bars.dart';
import 'package:path/path.dart' as p;
import 'package:rw_assets/bigfile.dart';

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

    final progress = FillingBar(
        desc: "Unpacking",
        total: bigfile.entries.length,
        time: false,
        percentage: true);

    final paths = <String>{};
    entryLoop:
    for (final entry in bigfile.entries) {
      progress.increment();

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
        _clearConsoleLine();
        print(
            'ERR: File already exists at: ${p.normalize(p.absolute(file.path))}');
        exit(-1);
      }

      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(Uint8List.sublistView(
          bigfileBytes, entry.byteOffset, entry.byteOffset + entry.sizeBytes));
    }

    _clearConsoleLine();
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
      print('File already exists at: ${p.normalize(p.absolute(outputPath))}');
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

    stdout.write('Scanning (1/3)...');

    final files = <File>[];
    for (final file in inputDir.listSync(recursive: true)) {
      if (file is! File) {
        continue;
      }

      files.add(file);
    }

    _clearConsoleLine();
    var progress = FillingBar(
        desc: "Computing header (2/3)",
        total: files.length,
        time: true,
        percentage: true);

    final headerSize = files.length * BigfileEntry.headerSize + 4;
    final entries = <BigfileEntry>[];
    int dataOffset = headerSize;

    for (final file in files) {
      progress.increment();

      final fileSize = file.statSync().size;

      String path = p.normalize(p.relative(file.path, from: inputPath));
      // bigfile supports paths with forward slash and colon separators as well as
      // mixed case, but the game expects backlash separators and all uppercase
      path = path.replaceAll(RegExp(r'[/|:]'), '\\').toUpperCase();

      if (path.length > BigfileEntry.maxPathLength) {
        _clearConsoleLine();
        print('ERR: Path $path is too long!');
        exit(-1);
      }

      entries.add(BigfileEntry(
          path: path,
          pathHash: computeBigfileEntryPathHash(path),
          byteOffset: dataOffset,
          sizeBytes: fileSize));

      dataOffset += fileSize;
    }

    _clearConsoleLine();
    progress = FillingBar(
        desc: "Packing (3/3)",
        total: entries.length,
        time: true,
        percentage: true);
    int i = 0;

    final builder = BytesBuilder(copy: false);
    builder.add((ByteData(4)..setUint32(0, entries.length, Endian.little))
        .buffer
        .asUint8List());

    for (final entry in entries) {
      if ((i++) % 2 == 0) {
        progress.increment();
      }

      builder.add(entry.toBytes());
    }

    for (final file in files) {
      if ((i++) % 2 == 0) {
        progress.increment();
      }

      builder.add(file.readAsBytesSync());
    }

    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsBytesSync(builder.takeBytes());

    _clearConsoleLine();
    print('Packed files into: ${p.normalize(p.absolute(outputFile.path))}');

    sigintSubscription.cancel();
  }
}

void _clearConsoleLine() {
  stdout.writeCharCode(13);
  stdout.write(' ' * stdout.terminalColumns);
  stdout.writeCharCode(13);
}
