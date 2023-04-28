import 'dart:io';

import 'package:path/path.dart' as p;

import 'rw_yaml.dart';

const _vsPath = 'C:\\Program Files (x86)\\Microsoft Visual Studio';
const _dxPath = 'C:\\dx7sdk';
const _clExePath = '$_vsPath\\VC98\\Bin\\CL.EXE';
const _clIncludePaths = [
  '$_dxPath\\include',
  '$_vsPath\\VC98\\Include'
];
final _envPath = [
  '$_vsPath\\VC98\\Bin',
  '$_vsPath\\Common\\MSDev98\\Bin',
  '$_vsPath\\VC98\\Lib',
  Platform.environment['PATH']
].join(';');

class BuildException implements Exception {
  final String message;

  BuildException(this.message);
}

class Builder {
  final String _srcDir;
  final String _includeDir;
  final String _buildDir;

  Builder(RealWarYaml rw)
      : _srcDir = p.join(rw.dir, rw.config.srcDir),
        _includeDir = p.join(rw.dir, rw.config.includeDir),
        _buildDir = p.join(rw.dir, rw.config.buildDir);

  /// Compile a single source file.
  /// 
  /// Throws a [BuildException] on error.
  Future<void> compile(String cPath) async {
    // Build command
    final String objPath = _makeObjPath(cPath);

    final args = [
      '/nologo', 
      '/c', 
      ...['/I', _includeDir],
      for (final incPath in _clIncludePaths)
        ...[
          '/I',
          incPath
        ],
      '/Fo$objPath', 
      '/Og', // global opt
      '/Oi', // intrinsics
      '/Ot', // favor fast code
      '/Oy', // frame pointer omission
      '/Ob1', // expand __inline marked functions
      '/Gs', // only insert stack probes when over 4k
      //'/Gf', // eliminate duplicate strings (pool to writable .data) (leave off since
      //          it makes it harder to match data sections and isn't necessary)
      '/Gy', // function-level linking (COMDAT)
      cPath,
    ];

    // Ensure obj directory exists
    await Directory(p.dirname(objPath)).create(recursive: true);

    // Compile
    final result = await Process.run(_clExePath, args,
      environment: {'PATH': _envPath},
      workingDirectory: p.current,
    );

    if (result.exitCode == -1073741515) {
      // Env is incorrect
      throw BuildException('CL.EXE returned STATUS_DLL_NOT_FOUND. Is PATH correct?');
    } else if (result.exitCode != 0) {
      // Failed to compile
      final buffer = StringBuffer();
      buffer.writeln(result.stdout);
      buffer.writeln(result.stderr);

      throw BuildException(buffer.toString());
    }
  }

  String _makeObjPath(String cPath) => p.normalize(p.join(
    _buildDir,
    'obj',
    p.dirname(p.relative(cPath, from: _srcDir)),
    '${p.basenameWithoutExtension(cPath)}.obj'
  ));
}
