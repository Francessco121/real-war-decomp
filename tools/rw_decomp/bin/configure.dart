import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:ninja_syntax/ninja_syntax.dart' as ninja;
import 'package:rw_decomp/rw_yaml.dart';

const _vsDir = 'C:\\Program Files (x86)\\Microsoft Visual Studio';
const _dxDir = 'C:\\dx8sdk';

/// Generates build.ninja for the Real War decompilation project.
void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);
  
  final outputExeName = 'RealWar.exe';

  // Collect list of files to compile
  final compilationUnits = <String>[];

  final srcDir = Directory(p.join(projectDir, rw.config.srcDir));
  for (final file in srcDir.listSync(recursive: true)) {
    if (file is! File) {
      continue;
    }
    final ext = p.extension(file.path);
    if (ext != '.c' && ext != '.cpp') {
      continue;
    }

    compilationUnits.add(p.relative(file.absolute.path, from: srcDir.absolute.path));
  }

  // Write ninja build file  
  final buffer = StringBuffer();
  final writer = ninja.Writer(buffer);

  writer.comment('Variables');
  writer.variable('VS_DIR', _vsDir);
  writer.variable('DX_DIR', _dxDir);
  writer.variable('SRC_DIR', p.normalize(rw.config.srcDir));
  writer.variable('BUILD_DIR', p.normalize(rw.config.buildDir));
  writer.variable('CL_FLAGS', [
    '/W4', // warning level 4
    '/Og', // global opt
    '/Oi', // intrinsics
    '/Ot', // favor fast code
    '/Oy', // frame pointer omission
    '/Ob1', // expand __inline marked functions
    '/Gs', // only insert stack probes when over 4k
    '/Gf', // eliminate duplicate strings (pool to writable .data)
    '/Gy', // function-level linking (COMDAT)
  ].join(','));
  writer.variable('INCLUDES', [
    '-I "${p.normalize(rw.config.includeDir)}"',
    r'-L "$DX_DIR\include"',
    r'-L "$VS_DIR\VC98\Include"',
  ].join(' '));

  writer.newline();
  writer.comment('Tools');
  writer.variable('CL', 
      r'tools/rw_decomp/build/cl_wrapper.exe --vsdir="$VS_DIR" --no-library-warnings --emit-deps');
  writer.variable('LINK', 'tools/rw_decomp/build/link.exe');

  writer.newline();
  writer.comment('Rules');
  writer.rule('cl', r'$CL $INCLUDES --flag="$CL_FLAGS" -o $out -i $in',
      depfile: r'$out.d', deps: 'gcc', 
      description: r'Compiling $in...');
  writer.rule('link', '\$LINK --no-success-message', 
      description: 'Linking \$BUILD_DIR\\$outputExeName...');

  writer.newline();
  writer.comment('Compilation');
  for (final name in compilationUnits) {
    final normalizedName = p.normalize(name);
    final objName = p.setExtension(normalizedName, '.obj');
    writer.build('\$BUILD_DIR\\obj\\$objName', 'cl', inputs: '\$SRC_DIR\\$normalizedName');
  }

  writer.newline();
  writer.comment('Linking');
  writer.build('\$BUILD_DIR\\$outputExeName', 'link', 
      implicit: compilationUnits.map((n) => '\$BUILD_DIR\\obj\\${p.setExtension(p.normalize(n), '.obj')}'));

  // Write file
  final buildFile = File(p.join(projectDir, 'build.ninja'));
  buildFile.writeAsStringSync(buffer.toString());

  print('Created ${p.relative(buildFile.path, from: projectDir)}');
}
