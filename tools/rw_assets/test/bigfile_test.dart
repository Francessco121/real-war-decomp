import 'package:rw_assets/bigfile.dart';
import 'package:test/test.dart';

void main() {
  group('computeBigfileEntryPathHash', () {
    test('backslash separator', () {
      expect(computeBigfileEntryPathHash(r'DATA\CREDITS.TXT'), equals(50994964));
    });

    test('forward slash separator', () {
      expect(computeBigfileEntryPathHash(r'DATA/CREDITS.TXT'), equals(50994964));
    });

    test('colon separator', () {
      expect(computeBigfileEntryPathHash(r'DATA:CREDITS.TXT'), equals(50994964));
    });

    test('lowercase', () {
      expect(computeBigfileEntryPathHash(r'data\credits.txt'), equals(50994964));
    });
  });
}
