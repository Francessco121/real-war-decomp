import 'dart:io';

/// Exports symbols from funcmap.txt to yaml for rw.yaml
void main() {
  final file = File('funcmap.txt');
  final lines = file.readAsLinesSync();

  final outFile = File('exported_func_symbols.yaml');
  final buffer = StringBuffer();
  buffer.writeln('symbols:');

  for (final line in lines) {
    final tabIndex1 = line.indexOf('\t');
    final tabIndex2 = line.indexOf('\t', tabIndex1 + 1);
    final name = line.substring(0, tabIndex1);
    final addr = int.parse(line.substring(tabIndex1 + 1, tabIndex2), radix: 16);
    
    buffer.writeln('  $name: 0x${addr.toRadixString(16)}');
  }

  outFile.writeAsStringSync(buffer.toString());
}
