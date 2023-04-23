import 'package:yaml/yaml.dart';

class RealWarYaml {
  final String dir;
  final RealWarYamlConfig config;
  final List<RealWarYamlSegment> segments;
  final Map<String, int> symbols;

  RealWarYaml._({
    required this.dir,
    required this.config,
    required this.segments,
    required this.symbols,
  });

  factory RealWarYaml.load(String contents, {required String dir}) {
    final yaml = loadYaml(contents);

    final config = RealWarYamlConfig._(yaml['config']);

    final segments = <RealWarYamlSegment>[];
    int lastSegmentAddress = 0;
    for (final segment in yaml['segments']) {
      final seg = RealWarYamlSegment._(segment);
      segments.add(seg);

      if (seg.address <= lastSegmentAddress) {
        throw Exception('Segment addresses must be in ascending order. '
            '(last = $lastSegmentAddress, cur = ${seg.address})');
      }

      lastSegmentAddress = seg.address;
    }

    final symbols = <String, int>{};
    for (final MapEntry entry in yaml['symbols'].entries) {
      symbols[entry.key] = entry.value;
    }

    return RealWarYaml._(
      dir: dir,
      config: config,
      segments: segments,
      symbols: symbols,
    );
  }
}

class RealWarYamlConfig {
  final String exePath;
  final String buildDir;
  final String includeDir;
  final String srcDir;
  final String asmDir;

  RealWarYamlConfig._(YamlMap map)
      : exePath = map['exePath'],
        buildDir = map['buildDir'],
        includeDir = map['includeDir'],
        srcDir = map['srcDir'],
        asmDir = map['asmDir'];
}

class RealWarYamlSegment {
  final int address;
  final String? objPath;

  RealWarYamlSegment._(YamlList list)
      : address = list[0],
        objPath = list[1];
}
