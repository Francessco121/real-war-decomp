import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rw_decomp/rw_yaml.dart';

class BuildException implements Exception {
  final String message;

  BuildException(this.message);
}

class Builder {
  final String _projectDir;

  Builder(RealWarYaml rw)
      : _projectDir = p.absolute(rw.dir);

  /// Runs ninja to build a single file.
  /// 
  /// Throws a [BuildException] on error.
  Future<void> compile(String objPath) async {
    // Build command
    objPath = p.relative(objPath, from: _projectDir);

    // Compile
    final result = await Process.run('ninja', [objPath],
      workingDirectory: _projectDir,
    );

    if (result.exitCode != 0) {
      // Failed to compile
      final buffer = StringBuffer();
      buffer.writeln(result.stdout);
      buffer.writeln(result.stderr);

      throw BuildException(buffer.toString());
    }
  }
}
