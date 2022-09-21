import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

const vsPath = 'C:\\Program Files (x86)\\Microsoft Visual Studio';
const clExePath = '$vsPath\\VC98\\Bin\\CL.EXE';
const clIncludePath = '$vsPath\\VC98\\Include';
const dumpbinExePath = '$vsPath\\VC98\\Bin\\DUMPBIN.EXE';
final envPath = [
  '$vsPath\\VC98\\Bin',
  '$vsPath\\Common\\MSDev98\\Bin',
  '$vsPath\\VC98\\Lib',
  Platform.environment['PATH']
].join(';');
final workingDirectory = p.current;
final srcPath = p.join(p.current, 'src');
final objPath = p.join(p.current, 'obj');

String cleanPath(String path) => p.relative(path, from: workingDirectory).replaceAll('/', '\\');
String makeObjPath(String cPath) => p.join(
  'obj',
  p.dirname(p.relative(cPath, from: srcPath)),
  p.basenameWithoutExtension(cPath) + '.obj'
);
String makePdbPath(String cPath) => p.join(
  'obj',
  p.dirname(p.relative(cPath, from: srcPath)),
  p.basenameWithoutExtension(cPath) + '.pdb'
);
String makeDisasmPath(String cPath) => p.join(
  p.dirname(cPath),
  p.basenameWithoutExtension(cPath) + '.disasm.txt'
);

Future<void> compile(String cPath) async {
  // Build command
  cPath = p.relative(cPath, from: workingDirectory).replaceAll('/', '\\');

  final String objPath = makeObjPath(cPath);
  final String pdbPath = makePdbPath(cPath);
  final String disasmPath = makeDisasmPath(cPath);

  final args = ['/nologo', '/c', '/I', clIncludePath, '/Fo$objPath', '/Fd$pdbPath', '/O2', '/Zi', cPath];
  print('[${DateTime.now()}] cl ${args.join(' ')}');

  // Ensure obj directory exists
  await Directory(p.dirname(objPath)).create();

  // Compile
  final result = await Process.run(clExePath, args,
    environment: {'PATH': envPath},
    workingDirectory: workingDirectory,
  );
  
  final disasmFile = File(disasmPath);
  final writer = disasmFile.openWrite();
  
  if (result.exitCode == -1073741515) {
    // Env is incorrect
    writer.writeln('CL.EXE returned STATUS_DLL_NOT_FOUND. Is PATH correct?');
  } else if (result.exitCode == 0) {
    // Success, disassemble the obj
    final dumpResult = await Process.run(dumpbinExePath, ['/DISASM', '/RELOCATIONS', '/LINENUMBERS', objPath],
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

Future<bool> isOutdated(String cPath) async {
  final String disasmPath = makeDisasmPath(cPath);

  final cFile = File(cPath);
  final disasmFile = File(disasmPath);

  if (!disasmFile.existsSync()) {
    return true;
  }

  return (await cFile.lastModified()).isAfter((await disasmFile.lastModified()));
}

Future<void> removeDisasmResult(String cPath) async {
  final String objPath = makeObjPath(cPath);
  final String disasmPath = makeDisasmPath(cPath);

  final objFile = File(objPath);
  final disasmFile = File(disasmPath);

  if (objFile.existsSync()) {
    print('[${DateTime.now()}] rm $objPath');
    await objFile.delete();
  }

  if (disasmFile.existsSync()) {
    print('[${DateTime.now()}] rm $disasmPath');
    await disasmFile.delete();
  }
}

Future<void> main() async {
  // Compile outdated files
  await for (final entity in Directory(srcPath).list(recursive: true)) {
    if (entity is File && p.extension(entity.path) == '.c' && (await isOutdated(entity.path))) {
      await compile(entity.path);
    }
  }

  // Listen for source file changes
  final subscription = DirectoryWatcher(srcPath).events.listen((event) {
    if (p.extension(event.path) != '.c') {
      return;
    }

    final String cleanedPath = cleanPath(event.path);

    if (event.type == ChangeType.ADD || event.type == ChangeType.MODIFY) {
      compile(cleanedPath);
    } else if (event.type == ChangeType.REMOVE) {
      removeDisasmResult(cleanedPath);
    }
  });

  print('Watching...');
  
  // Let user enter 'q' to gracefully exit (if in terminal)
  if (stdin.hasTerminal) {
    print('Press q to exit.');

    stdin.echoMode = false;
    stdin.lineMode =false;

    await stdin.where((bytes) => utf8.decode(bytes).startsWith('q')).first;

    print('Shutting down...');
    subscription.cancel();
  }
}
