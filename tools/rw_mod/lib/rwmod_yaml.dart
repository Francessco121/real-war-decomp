import 'package:yaml/yaml.dart';

class RealWarModYaml {
  final Map<String, String> hooks;
  final Map<String, String> funcClones;

  RealWarModYaml._({
    required this.hooks,
    required this.funcClones,
  });

  factory RealWarModYaml.load(String contents) {
    final yaml = loadYaml(contents);

    final hooks = <String, String>{};
    for (final MapEntry entry in yaml['hooks'].entries) {
      hooks[entry.key] = entry.value;
    }

    final funcClones = <String, String>{};
    for (final MapEntry entry in yaml['func_clones'].entries) {
      funcClones[entry.key] = entry.value;
    }

    return RealWarModYaml._(
      hooks: hooks,
      funcClones: funcClones,
    );
  }
}
