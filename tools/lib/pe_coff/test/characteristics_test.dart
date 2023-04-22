import 'package:pe_coff/coff.dart';
import 'package:test/test.dart';

void main() {
  test('can parse', () {
    final characteristics = Characteristics(0x010F);

    expect(characteristics.relocsStripped, equals(true));
    expect(characteristics.executableImage, equals(true));
    expect(characteristics.lineNumsStripped, equals(true));
    expect(characteristics.localSymsStripped, equals(true));
    expect(characteristics.aggressiveWsTrim, equals(false));
    expect(characteristics.largeAddressAware, equals(false));
    expect(characteristics.$16BitMachine, equals(false));
    expect(characteristics.bytesReversedLo, equals(false));
    expect(characteristics.$32BitMachine, equals(true));
    expect(characteristics.debugStripped, equals(false));
    expect(characteristics.removableRunFromSwap, equals(false));
    expect(characteristics.netRunFromSwap, equals(false));
    expect(characteristics.system, equals(false));
    expect(characteristics.dll, equals(false));
    expect(characteristics.upSystemOnly, equals(false));
    expect(characteristics.bytesReversedHi, equals(false));
  });
}
