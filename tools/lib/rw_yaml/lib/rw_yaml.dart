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
    for (final segment in yaml['segments']) {
      segments.add(RealWarYamlSegment._(segment));
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

  RealWarYamlConfig._(YamlMap map)
      : exePath = map['exePath'],
        buildDir = map['buildDir'],
        includeDir = map['includeDir'],
        srcDir = map['srcDir'];
}

class RealWarYamlSegment {
  final int address;
  final String? objPath;

  RealWarYamlSegment._(YamlList list)
      : address = list[0],
        objPath = list[1];
}
