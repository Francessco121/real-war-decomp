import 'package:yaml/yaml.dart';

class RealWarYaml {
  Map<int, String> get addressesToSymbols {
    _addressesToSymbols ??= symbols.map((key, value) => MapEntry(value, key));
    return _addressesToSymbols!;
  }

  Map<int, String> get addressesToStrings {
    _addressesToStrings ??= strings.map((key, value) => MapEntry(value, key));
    return _addressesToStrings!;
  }

  Map<int, String>? _addressesToSymbols;
  Map<int, String>? _addressesToStrings;

  final String dir;
  final RealWarYamlConfig config;
  final RealWarYamlExe exe;
  final List<RealWarYamlSegment> segments;
  final Map<String, int> symbols;
  final Map<String, int> strings;

  RealWarYaml._({
    required this.dir,
    required this.config,
    required this.exe,
    required this.segments,
    required this.symbols,
    required this.strings,
  });

  factory RealWarYaml.load(String contents, {required String dir}) {
    final yaml = loadYaml(contents);

    final config = RealWarYamlConfig._(yaml['config']);
    final exe = RealWarYamlExe._(yaml['exe']);

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

    final strings = <String, int>{};
    for (final MapEntry entry in yaml['strings'].entries) {
      strings[entry.key] = entry.value;
    }

    return RealWarYaml._(
      dir: dir,
      config: config,
      exe: exe,
      segments: segments,
      symbols: symbols,
      strings: strings,
    );
  }

  int? lookupSymbolOrString(String name) {
    return symbols[name] ?? strings[name];
  }

  RealWarYamlSegment? findSegmentOfAddress(int virtualAddress) {
    RealWarYamlSegment? lastSeg;

    for (final segment in segments) {
      if (segment.address <= virtualAddress) {
        lastSeg = segment;
      } else {
        break;
      }
    }

    return lastSeg;
  }
}

class RealWarYamlConfig {
  final String exePath;
  final String buildDir;
  final String includeDir;
  final String srcDir;
  final String asmDir;
  final String binDir;

  RealWarYamlConfig._(YamlMap map)
      : exePath = map['exePath'],
        buildDir = map['buildDir'],
        includeDir = map['includeDir'],
        srcDir = map['srcDir'],
        asmDir = map['asmDir'],
        binDir = map['binDir'];
}

class RealWarYamlExe {
  /// Address of first byte in memory when exe is loaded into memory.
  final int imageBase;
  /// File offset of the .text section data.
  final int textFileOffset;
  /// Virtual address of the .text section in memory relative to [imageBase].
  final int textVirtualAddress;
  /// Size (in bytes) of the .text section within the exe file.
  final int textPhysicalSize;

  RealWarYamlExe._(YamlMap map)
      : imageBase = map['imageBase'],
        textFileOffset = map['textFileOffset'],
        textVirtualAddress = map['textVirtualAddress'],
        textPhysicalSize = map['textPhysicalSize'];
}

class RealWarYamlSegment {
  final int address;
  final String type;
  final String name;

  RealWarYamlSegment._(YamlList list)
      : address = list[0],
        type = list[1],
        name = list[2] ?? 'segment_${list[0].toRadixString(16)}';
}
