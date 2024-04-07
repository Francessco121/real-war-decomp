import 'package:yaml/yaml.dart';

class RealWarYaml {
  Map<int, RealWarYamlSymbol> get symbolsByAddress {
    _symbolsByAddress ??= symbols.map((key, value) => MapEntry(value.address, value));
    return _symbolsByAddress!;
  }

  Map<int, RealWarYamlLiteralSymbol> get literalSymbolsByAddress {
    _literalSymbolsByAddress ??= Map.fromEntries(literalSymbols.entries.expand((e) => 
        [for (final a in e.value.addresses) MapEntry(a, e.value)]));
    return _literalSymbolsByAddress!;
  }

  Map<int, RealWarYamlSymbol>? _symbolsByAddress;
  Map<int, RealWarYamlLiteralSymbol>? _literalSymbolsByAddress;

  final String dir;
  final RealWarYamlConfig config;
  final RealWarYamlExe exe;
  final List<RealWarYamlSegment> segments;
  final Map<String, RealWarYamlSymbol> symbols;
  final Map<String, RealWarYamlLiteralSymbol> literalSymbols;

  RealWarYaml._({
    required this.dir,
    required this.config,
    required this.exe,
    required this.segments,
    required this.symbols,
    required this.literalSymbols,
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

    final symbols = <String, RealWarYamlSymbol>{};
    for (final MapEntry entry in yaml['symbols'].entries) {
      symbols[entry.key] = RealWarYamlSymbol._(entry.key, entry.value);
    }

    final literalSymbols = <String, RealWarYamlLiteralSymbol>{};
    for (final MapEntry entry in yaml['literalSymbols'].entries) {
      literalSymbols[entry.key] = RealWarYamlLiteralSymbol._(entry.key, entry.value);
    }

    return RealWarYaml._(
      dir: dir,
      config: config,
      exe: exe,
      segments: segments,
      symbols: symbols,
      literalSymbols: literalSymbols,
    );
  }

  int? lookupSymbol(String name) {
    return symbols[name]?.address ?? literalSymbols[name]?.addresses.first;
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

class RealWarYamlSymbol {
  final String name;
  final int address;
  final int? size;

  RealWarYamlSymbol._value(this.name, this.address) 
      : size = null;
  RealWarYamlSymbol._list(this.name, YamlList list)
      : address = list[0],
        size = list[1];

  factory RealWarYamlSymbol._(String name, dynamic yaml) {
    if (yaml is YamlList) {
      return RealWarYamlSymbol._list(name, yaml);
    } else {
      return RealWarYamlSymbol._value(name, yaml);
    }
  }
}

class RealWarYamlLiteralSymbol {
  final String name;
  final String displayName;
  final int size;
  final List<int> addresses;

  RealWarYamlLiteralSymbol._(this.name, YamlList list)
      : displayName = list[0],
        size = list[1],
        addresses = list.skip(2).cast<int>().toList();
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
  /// File offset of the .rdata section data.
  final int rdataFileOffset;
  /// Virtual address of the .rdata section in memory relative to [imageBase].
  final int rdataVirtualAddress;
  /// File offset of the .data section data.
  final int dataFileOffset;
  /// Virtual address of the .data section in memory relative to [imageBase].
  final int dataVirtualAddress;
  /// Virtual address of the .data section, where uninitialized memory start, 
  /// in memory relative to [imageBase].
  final int bssVirtualAddress;

  RealWarYamlExe._(YamlMap map)
      : imageBase = map['imageBase'],
        textFileOffset = map['textFileOffset'],
        textVirtualAddress = map['textVirtualAddress'],
        textPhysicalSize = map['textPhysicalSize'],
        rdataFileOffset = map['rdataFileOffset'],
        rdataVirtualAddress = map['rdataVirtualAddress'],
        dataFileOffset = map['dataFileOffset'],
        dataVirtualAddress = map['dataVirtualAddress'],
        bssVirtualAddress = map['bssVirtualAddress'];
}

class RealWarYamlSegment {
  final int address;
  final String type;
  final String? name;

  RealWarYamlSegment._(YamlList list)
      : address = list[0],
        type = list[1],
        name = list.length >= 3 ? list[2] : null;
}

String makeDefaultSegmentName(int address) {
  return 'segment_${address.toRadixString(16)}'; 
}
