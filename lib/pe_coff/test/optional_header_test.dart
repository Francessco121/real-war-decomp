import 'dart:convert';
import 'dart:typed_data';

import 'package:pe_coff/coff.dart';
import 'package:pe_coff/src/structured_file_reader.dart';
import 'package:test/test.dart';

void main() {
  test('can parse header for PE32 image file', () {
    final data = base64.decode(
        'CwEGAACADgAAAGwBAAAAAG8fDgAAEAAAAJAOAAAAQAAAEAAAABAAAAQAAAAAAAAABAAAA'
        'AAAAAAAkHoBABAAAAAAAAACAAAAAAAQAAAQAAAAABAAABAAAAAAAAAQAAAAAAAAAAAAAA'
        'Cgrg4AtAAAAABgegFAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJAOAIwBAAAAAAAAAAAA'
        'AAAAAAAAAAAAAAAAAAAAAAA=');

    final reader = StructuredFileReader.list(data, endian: Endian.little);
    final header = OptionalHeader.fromReader(reader, 224);

    expect(header.magic, equals(PEFormat.pe32));
    expect(header.majorLinkerVersion, equals(6));
    expect(header.minorLinkerVersion, equals(0));
    expect(header.sizeOfCode, equals(950272));
    expect(header.sizeOfInitializedData, equals(23855104));
    expect(header.sizeOfUninitializedData, equals(0));
    expect(header.addressOfEntryPoint, equals(0x000E1F6F));
    expect(header.baseOfCode, equals(0x00001000));
    expect(header.baseOfData, equals(0x000E9000));
    
    expect(header.windows, isNotNull);
    final windows = header.windows!;

    expect(windows.imageBase, equals(0x00400000));
    expect(windows.sectionAlignment, equals(4096));
    expect(windows.fileAlignment, equals(4096));
    expect(windows.majorOperatingSystemVersion, equals(4));
    expect(windows.minorOperatingSystemVersion, equals(0));
    expect(windows.majorImageVersion, equals(0));
    expect(windows.minorImageVersion, equals(0));
    expect(windows.majorSubsystemVersion, equals(4));
    expect(windows.minorSubsystemVersion, equals(0));
    expect(windows.win32VersionValue, equals(0));
    expect(windows.sizeOfImage, equals(24809472));
    expect(windows.sizeOfHeaders, equals(4096));
    expect(windows.checkSum, equals(0));
    expect(windows.subsystem, equals(SubsystemType.windowsGui));
    expect(windows.dllCharacteristics.rawValue, equals(0));
    expect(windows.sizeOfStackReserve, equals(1048576));
    expect(windows.sizeOfStackCommit, equals(4096));
    expect(windows.sizeOfHeapReserve, equals(1048576));
    expect(windows.sizeOfHeapCommit, equals(4096));
    expect(windows.loaderFlags, equals(0));
    expect(windows.numberOfRvaAndSizes, equals(16));

    expect(header.dataDirectories.length, equals(windows.numberOfRvaAndSizes));
    final dir = header.dataDirectories[DataDirectory.importTable];
    expect(dir.virtualAddress, equals(0x000EAEA0));
    expect(dir.size, equals(180));
  });
}
