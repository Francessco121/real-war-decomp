import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

const clExePath = 'C:\\Program Files (x86)\\Microsoft Visual Studio\\VC98\\Bin\\CL.EXE';
const clIncludePath = 'C:\\Program Files (x86)\\Microsoft Visual Studio\\VC98\\Include';
const dumpbinExePath = 'C:\\Program Files (x86)\\Microsoft Visual Studio\\VC98\\Bin\\DUMPBIN.EXE';
final envPath = [
  'C:\\Program Files (x86)\\Microsoft Visual Studio\\VC98\\Bin',
  'C:\\Program Files (x86)\\Microsoft Visual Studio\\Common\\MSDev98\\Bin',
  'C:\\Program Files (x86)\\Microsoft Visual Studio\\VC98\\Lib',
  Platform.environment['PATH']
].join(';');
final workingDirectory = p.current;
final srcPath = p.join(p.current, 'src');

Future<void> compile(String path) async {
  // Build command
  path = p.relative(path, from: workingDirectory).replaceAll('/', '\\');

  final inputPath = path;
  final objPath = p.join(p.dirname(p.dirname(path)), 'obj', p.basenameWithoutExtension(path) + '.obj');
  final outputPath = p.join(p.dirname(path), p.basenameWithoutExtension(path) + '.disasm.txt');

  final args = ['/nologo', '/c', '/I', clIncludePath, '/Fo$objPath', '/O1', inputPath];
  print('[${DateTime.now()}] cl ${args.join(' ')}');

  // Compile
  final result = await Process.run(clExePath, args,
    environment: {'PATH': envPath},
    workingDirectory: workingDirectory,
  );
  
  final outputFile = File(outputPath);
  final writer = outputFile.openWrite();
  
  if (result.exitCode == -1073741515) {
    // Env is incorrect
    writer.writeln('CL.EXE returned STATUS_DLL_NOT_FOUND. Is PATH correct?');
  } else if (result.exitCode == 0) {
    // Success, disassemble the obj
    final dumpResult = await Process.run(dumpbinExePath, ['/DISASM', '/RELOCATIONS', objPath],
      environment: {'PATH': envPath},
      workingDirectory: workingDirectory,
    );

    // Skip copywrite header
    final dumpOut = dumpResult.stdout as String;
    int actualStart = dumpOut.indexOf('Dump of');
    actualStart = dumpOut.indexOf('\n', actualStart) + 3;

    writer.writeln(dumpOut.substring(actualStart));
    writer.writeln(dumpResult.stderr);
  } else {
    // Failed to compile, write error
    writer.writeln(result.stdout);
    writer.writeln(result.stderr);
  }

  await writer.flush();
  await writer.close();
}

Future<bool> isOutdated(String path) async {
  path = p.relative(path, from: workingDirectory).replaceAll('/', '\\');

  final inputPath = path;
  final outputPath = p.join(p.dirname(path), p.basenameWithoutExtension(path) + '.disasm.txt');

  final inFile = File(inputPath);
  final outFile = File(outputPath);

  if (!outFile.existsSync()) {
    return true;
  }

  return (await inFile.lastModified()).isAfter((await outFile.lastModified()));
}

Future<void> main() async {
  await for (final entity in Directory(srcPath).list(recursive: true)) {
    if (entity is File && p.extension(entity.path) == '.c' && (await isOutdated(entity.path))) {
      await compile(entity.path);
    }
  }

  DirectoryWatcher(srcPath).events.listen((event) {
    if (event.type == ChangeType.ADD || event.type == ChangeType.MODIFY) {
      if (p.extension(event.path) == '.c') {
        compile(event.path);
      }
    }
  });

  print('Watching...');
}
