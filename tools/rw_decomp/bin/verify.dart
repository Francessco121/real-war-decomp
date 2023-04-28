import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

int main(List<String> args) {
  // Assume we're ran from the package dir
  final String projectDir = p.normalize(p.join(p.current, '../../'));

  // Get expected MD5
  final md5FilePath = p.join(projectDir, 'rw.md5');
  final expectedMd5 = File(md5FilePath).readAsStringSync().split(' ').first;

  // Check
  if (args.isNotEmpty && args.first == 'base') {
    return _check(expectedMd5, p.join('game', 'RealWar.exe'), projectDir);
  } else {
    return _check(expectedMd5, p.join('build', 'RealWar.exe'), projectDir);
  }
}

int _check(String expectedMd5, String filePath, String projectDir) {
  final file = File(p.join(projectDir, filePath));
  if (!file.existsSync()) {
    print('Could not find $file');
    return -1;
  }

  final digest = md5.convert(file.readAsBytesSync());
  final builtExeMd5 = digest.toString();

  if (expectedMd5 == builtExeMd5) {
    print('${p.relative(file.path, from: projectDir)}: OK');
    return 0;
  } else {
    print('${p.relative(file.path, from: projectDir)}: FAILED');
    return 1;
  }
}
