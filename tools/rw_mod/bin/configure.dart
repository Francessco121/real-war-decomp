import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:ninja_syntax/ninja_syntax.dart' as ninja;
import 'package:rw_mod/rwmod_yaml.dart';

const _vsDir = 'C:\\Program Files (x86)\\Microsoft Visual Studio';
const _dxDir = 'C:\\dx7sdk';

/// Generates build.ninja for the mod project.
Future<void> main(List<String> args) async {
  final argParser = ArgParser()
      ..addOption('decomp-root', help: 'Path to the root of the decomp project.')
      ..addOption('mod-root', help: 'Path to the root of the mod project. Should contain a src directory.')
      ..addFlag('non-matching', abbr: 'n', 
          help: 'Whether to use a non-matching build as the base executable.', 
          defaultsTo: false);
  
  final argResult = argParser.parse(args);
  final String decompDir = p.absolute(argResult['decomp-root'] ?? p.current);
  final String modDir = p.absolute(argResult['mod-root'] ?? p.current);
  final bool nonMatching = argResult['non-matching'];

  final modSrcDir = p.join(modDir, 'src');

  // Load rwmod.yaml
  final rwmod = RealWarModYaml.load(
      await File(p.join(modDir, 'rwmod.yaml')).readAsString());
  
  // Collect list of clone function obj's to link
  final cloneObjs = rwmod.funcClones.values.toList();

  // Collect list of files to compile
  final compilationUnits = <String>[];

  await for (final file in Directory(modSrcDir).list(recursive: true)) {
    if (file is File) {
      final basename = p.basenameWithoutExtension(file.path);
      final dir = p.dirname(file.path);
      final relativePath = p.join(
        p.relative(dir, from: modSrcDir),
        basename,
      );

      compilationUnits.add(relativePath);
    }
  }

  // Write ninja build file  
  final buffer = StringBuffer();
  final writer = ninja.Writer(buffer);

  writer.comment('Variables');
  writer.variable('VS_DIR', _vsDir);
  writer.variable('DX_DIR', _dxDir);
  writer.variable('DECOMP_DIR', p.normalize(decompDir));
  writer.variable('BIN_DIR', 'bin');
  writer.variable('SRC_DIR', 'src');
  writer.variable('BUILD_DIR', 'build');
  writer.variable('BASE_EXE', nonMatching
      ? p.normalize(p.join(decompDir, 'build', 'RealWarNonMatching.exe'))
      : p.normalize(p.join(decompDir, 'game', 'RealWar.exe')));
  writer.variable('OUT_GAME_DIR', 'game');
  writer.variable('OPT_FLAGS', [
    '/W3', // warning level 3
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
    '-I "include"',
    r'-I "$DECOMP_DIR\rw\include"',
    r'-I "$DX_DIR\include"',
    r'-I "$VS_DIR\VC98\Include"',
  ].join(' '));

  writer.newline();
  writer.comment('Tools');
  writer.variable('CL', r'$DECOMP_DIR/tools/rw_decomp/build/cl_wrapper.exe --vsdir="$VS_DIR"');
  writer.variable('RWPATCH', 
      r'dart run $DECOMP_DIR/tools/rw_mod/bin/rwpatch.dart '
      r'--rwyaml="$DECOMP_DIR\rw.yaml" '
      r'--rwmodyaml="rwmod.yaml" '
      r'--baseexe="$BASE_EXE"');
  
  writer.newline();
  writer.comment('Rules');
  writer.rule('cl', r'$CL $INCLUDES --flag="$OPT_FLAGS" -o $out -i $in',
      depfile: r'$out.d', deps: 'gcc', 
      description: r'Compiling $in...');
  writer.rule('rwpatch', r'$RWPATCH -o $out $in',
      description: nonMatching 
        ? r'Patching new executable from non-matching...' 
        : r'Patching new executable from base game...');
    
  writer.newline();
  writer.comment('Compilation');
  for (final name in compilationUnits) {
    final normalizedName = p.normalize(name);
    writer.build('\$BUILD_DIR\\obj\\$normalizedName.obj', 'cl', inputs: '\$SRC_DIR\\$normalizedName.c');
  }
  
  if (cloneObjs.isNotEmpty) {
    writer.newline();
    writer.comment('Cloned function phony rules');
    for (final name in cloneObjs) {
      writer.build(
          nonMatching ? '\$BIN_DIR\\nonmatching\\$name.obj' : '\$BIN_DIR\\$name.obj', 
          'phony');
    }
  }

  writer.newline();
  writer.comment('Patching');
  writer.build(r'$OUT_GAME_DIR\RealWar.exe', 'rwpatch', 
      inputs: [
        ...compilationUnits.map((n) => '\$BUILD_DIR\\obj\\${p.normalize(n)}.obj'),
        ...cloneObjs.map((n) => nonMatching ? '\$BIN_DIR\\nonmatching\\$n.obj' : '\$BIN_DIR\\$n.obj')
      ],
      implicit: nonMatching ? r'$BASE_EXE' : null);

  // Write file
  final buildFile = File(p.join(modDir, 'build.ninja'));
  buildFile.writeAsStringSync(buffer.toString());

  print('Created ${p.relative(buildFile.path, from: modDir)}');
}
