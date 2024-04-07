import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/verify.dart';


Future<void> main(List<String> args) async {
  final argParser = ArgParser()
      ..addOption('root')
      ..addFlag('shields', 
          help: 'Regenerate docs/shields/*', 
          defaultsTo: false, 
          negatable: false)
      ..addFlag('help', negatable: false, defaultsTo: false);

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);
  final bool genShields = argResult['shields'];

  if (argResult['help']) {
    print('progress.dart [options]');
    print(argParser.usage);
    return;
  }

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  final textEndVA = rw.exe.imageBase + rw.exe.rdataVirtualAddress;

  // Load last verification run
  final verificationFile = File(p.join(projectDir, rw.config.buildDir, 'verification.json'));
  if (!verificationFile.existsSync()) {
    print('Could not find verification file. Did you run the build and verify it?');
    exit(-1);
  }

  final verification = VerificationResult.fromJson(json.decode(verificationFile.readAsStringSync()));

  // Determine progress
  int textTotalBytes = 0;
  int rdataTotalBytes = 0;
  int dataTotalBytes = 0;

  final textRanges = <(int, int)>[];

  for (final (i, segment) in rw.segments.indexed) {
    // Skip last entry since we can't infer its size (it's .rsrc anyway so it's fine)
    if (i == rw.segments.length - 1) {
      break;
    }

    final size = rw.segments[i + 1].address - segment.address;

    switch (segment.type) {
      case 'text':
        textTotalBytes += size;
        textRanges.add((segment.address, segment.address + size));
      case 'rdata':
        rdataTotalBytes += size;
      case 'data':
        dataTotalBytes += size;
    }
  }

  int stringLiteralTotalBytes = 0;
  for (final literal in rw.literalSymbols.values) {
    if (literal.name.startsWith('??_C@')) {
      stringLiteralTotalBytes += literal.size;
    }
  }

  final totalFunctions = rw.symbols.values
      .fold(0, (sum, s) => 
          (s.address < textEndVA && textRanges.any((r) => s.address >= r.$1 && s.address < r.$2)
            ? (sum + 1)
            : sum));

  final textMatchingBytes = verification.text.totalMatchingBytes;
  final rdataMatchingBytes = verification.rdata.totalMatchingBytes;
  final dataMatchingBytes = verification.data.totalMatchingBytes + stringLiteralTotalBytes;

  final equivalentFunctions = verification.text.symbols.length;

  // Display
  final totalBytes = textTotalBytes + rdataTotalBytes + dataTotalBytes;
  final totalMatchingBytes = textMatchingBytes + rdataMatchingBytes + dataMatchingBytes;

  final funcPercentage = ((equivalentFunctions / totalFunctions) * 100.0).toStringAsFixed(2);
  final textBytePercentage = ((textMatchingBytes / textTotalBytes) * 100.0).toStringAsFixed(2);
  final rdataBytePercentage = ((rdataMatchingBytes / rdataTotalBytes) * 100.0).toStringAsFixed(2);
  final dataBytePercentage = ((dataMatchingBytes / dataTotalBytes) * 100.0).toStringAsFixed(2);
  final totalBytePercentage = ((totalMatchingBytes / totalBytes) * 100.0).toStringAsFixed(2);

  print('total:');
  print('    bytes:      ${'$totalMatchingBytes/$totalBytes'.padLeft(14)} ($totalBytePercentage%)');
  print('.text:');
  print('    funcs:      ${'$equivalentFunctions/$totalFunctions'.padLeft(14)} ($funcPercentage%)');
  print('    bytes:      ${'$textMatchingBytes/$textTotalBytes'.padLeft(14)} ($textBytePercentage%)');
  print('.rdata:');
  print('    bytes:      ${'$rdataMatchingBytes/$rdataTotalBytes'.padLeft(14)} ($rdataBytePercentage%)');
  print('.data:');
  print('    bytes:      ${'$dataMatchingBytes/$dataTotalBytes'.padLeft(14)} ($dataBytePercentage%)');

  // Generate shields
  if (genShields) {
    final shieldsDir = p.join(rw.dir, 'docs', 'shields');

    Future<void> makeShield(String filename, String label, String content) async {
      final shieldSvg = await _getNewShield(label, content);
      final shieldFile = File(p.join(shieldsDir, filename));
      shieldFile.writeAsStringSync(shieldSvg);
    }

    await makeShield('total.svg', 'Total', '$totalBytePercentage%');
    await makeShield('funcs.svg', 'Functions', '$funcPercentage%');

    print('');
    print('Wrote new shields to $shieldsDir');
  }
}

Future<String> _getNewShield(String label, String text) async {
  final args = Uri.encodeComponent('$label-$text-blue');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse('https://img.shields.io/badge/$args'));
  final response = await request.close();
  final content = await utf8.decodeStream(response);
  client.close();

  if (response.statusCode >= 400) {
    throw Exception('Failed to get new shield: $content');
  }

  return content;
}
