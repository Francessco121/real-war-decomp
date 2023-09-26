import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:ninja_syntax/ninja_syntax.dart' as ninja;
import 'package:rw_decomp/rw_yaml.dart';

const _vsDir = 'C:\\Program Files (x86)\\Microsoft Visual Studio';
const _dxDir = 'C:\\dx7sdk';

/// Generates build.ninja for the Real War decompilation project.
void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root')
      ..addFlag('non-matching', abbr: 'n', 
          help: 'Build a non-matching executable.', 
          defaultsTo: false);

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);
  final bool nonMatching = argResult['non-matching'];

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);
  
  final outputExeName = nonMatching ? 'RealWarNonMatching.exe' : 'RealWar.exe';

  // Collect list of files to compile
  final compilationUnits = <String>[];
  final binarySegments = <String>[];

  for (final segment in rw.segments) {
    if (segment.type == 'c') {
      compilationUnits.add(segment.name);
    } else if (segment.type == 'bin') {
      binarySegments.add(segment.name);
    }
  }

  // Write ninja build file  
  final buffer = StringBuffer();
  final writer = ninja.Writer(buffer);

  writer.comment('Variables');
  writer.variable('VS_DIR', _vsDir);
  writer.variable('DX_DIR', _dxDir);
  writer.variable('SRC_DIR', p.normalize(rw.config.srcDir));
  writer.variable('BUILD_DIR', p.normalize(rw.config.buildDir));
  writer.variable('BIN_DIR', p.normalize(rw.config.binDir));
  writer.variable('CL_FLAGS', [
    '/W3', // warning level 3
    '/Og', // global opt
    '/Oi', // intrinsics
    '/Ot', // favor fast code
    '/Oy', // frame pointer omission
    '/Ob1', // expand __inline marked functions
    '/Gs', // only insert stack probes when over 4k
    //'/Gf', // eliminate duplicate strings (pool to writable .data) (leave off since
    //          it makes it harder to match data sections and isn't necessary)
    '/Gy', // function-level linking (COMDAT)
    if (nonMatching)
      '/DNON_MATCHING',
  ].join(','));
  writer.variable('INCLUDES', [
    '-I "${p.normalize(rw.config.includeDir)}"',
    r'-I "$DX_DIR\include"',
    r'-I "$VS_DIR\VC98\Include"',
  ].join(' '));

  writer.newline();
  writer.comment('Tools');
  writer.variable('CL', r'tools/rw_decomp/build/cl_wrapper.exe --vsdir="$VS_DIR" --asmfuncdir="$BIN_DIR\_funcs"');
  writer.variable('LINK', 'tools/rw_decomp/build/link.exe');

  writer.newline();
  writer.comment('Rules');
  writer.rule('cl', r'$CL $INCLUDES --flag="$CL_FLAGS" -o $out -i $in',
      depfile: r'$out.d', deps: 'gcc', 
      description: r'Compiling $in...');
  writer.rule('link', '\$LINK --no-success-message${nonMatching ? ' --non-matching' : ''}', 
      description: 'Linking \$BUILD_DIR\\$outputExeName...');

  writer.newline();
  writer.comment('Compilation');
  for (final name in compilationUnits) {
    final normalizedName = p.normalize(name);
    writer.build('\$BUILD_DIR\\obj\\$normalizedName.obj', 'cl', inputs: '\$SRC_DIR\\$normalizedName.c');
  }

  writer.newline();
  writer.comment('Linking');
  writer.build('\$BUILD_DIR\\$outputExeName', 'link', 
      implicit: [
        ...compilationUnits.map((n) => '\$BUILD_DIR\\obj\\${p.normalize(n)}.obj'),
        ...binarySegments.map((n) => '\$BIN_DIR\\${p.normalize(n)}.bin')
      ]);

  // Write file
  final buildFile = File(p.join(projectDir, 'build.ninja'));
  buildFile.writeAsStringSync(buffer.toString());

  print('Created ${p.relative(buildFile.path, from: projectDir)}');
}
