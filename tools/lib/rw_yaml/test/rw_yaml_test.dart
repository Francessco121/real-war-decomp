import 'dart:io';

import 'package:rw_yaml/rw_yaml.dart';
import 'package:test/test.dart';

void main() {
  test('parses', () {
    final contents = File('../../../rw.yaml').readAsStringSync();
    final yaml = RealWarYaml.load(contents, dir: '../../../');

    expect(yaml.config.exePath, 'game/RealWar.exe');
    expect(yaml.segments, isNotEmpty);
    expect(yaml.symbols, isNotEmpty);
  });
}