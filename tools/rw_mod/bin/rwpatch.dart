import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe_coff.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';

/// Patches custom object files into an existing RealWar.exe.
Future<void> main(List<String> args) async {
  final argParser = ArgParser()
      ..addOption('rwyaml', mandatory: true, help: 'Path to rw.yaml.')
      ..addOption('baseexe', mandatory: true, help: 'Path to the base RealWar.exe.')
      ..addOption('output', mandatory: true, abbr: 'o', help: 'Output exe.');
  
  if (args.isEmpty) {
    print('rwpatch.dart [options...] objfile...');
    print(argParser.usage);
    exit(-1);
  }

  final argResult = argParser.parse(args);

  final String rwyamlPath = argResult['rwyaml'];
  final String baseExePath = argResult['baseexe'];
  final String outputPath = argResult['output'];
  final List<String> inputs = argResult.rest;

  // Load rw.yaml
  final rw = RealWarYaml.load(
      await File(rwyamlPath).readAsString(),
      dir: p.dirname(rwyamlPath));

  // Open base exe
  final baseExeBytes = await File(baseExePath).readAsBytes();
  final baseExe = PeFile.fromList(baseExeBytes);

  final imageBase = baseExe.optionalHeader!.windows!.imageBase;

  // Merge sections from input files and map them to relative addresses
  final combinedSectionByteBuilders = <String, BytesBuilder>{};
  final combinedSectionBytes = <String, Uint8List>{};
  final combinedSectionLengths = <String, int>{};
  final objSectionMappings = <CoffFile, Map<int, MappedSection>>{};
  final sectionFlags = <String, SectionFlags>{};
  final sectionNames = <String>[];

  for (final path in inputs) {
    final objBytes = await File(path).readAsBytes();
    final obj = CoffFile.fromList(objBytes);

    for (int i = 0; i < obj.sections.length; i++) {
      final section = obj.sections[i];

      if (!const ['.text', '.data', '.rdata', '.bss'].contains(section.header.name)) {
        continue;
      }

      if (!sectionNames.contains(section.header.name)) {
        sectionNames.add(section.header.name);
      }

      // Calculate byte offset of where to merge this section into the larger single new section
      final currentCombinedSectionLength = combinedSectionLengths.putIfAbsent(section.header.name, () => 0);

      // Copy bytes into combined buffer, if any
      if (section.header.pointerToRawData > 0) {
        final combinedBytes = combinedSectionByteBuilders
            .putIfAbsent(section.header.name, () => BytesBuilder(copy: false));

        combinedBytes.add(Uint8List.sublistView(objBytes, 
            section.header.pointerToRawData, section.header.pointerToRawData + section.header.sizeOfRawData));
      }

      // Map object section to combined section
      final mapList = objSectionMappings.putIfAbsent(obj, () => {});
      mapList[i] = MappedSection(obj, section, i, currentCombinedSectionLength);
      
      // Note: Even if there wasn't real bytes to copy, we need to track the virtual size of the section 
      // so we can support uninitialized data sections
      combinedSectionLengths[section.header.name] = currentCombinedSectionLength + section.header.sizeOfRawData;

      // Store section flags for later section header creation
      sectionFlags.putIfAbsent(section.header.name, () => section.header.flags);
    }
  }

  for (final entry in combinedSectionByteBuilders.entries) {
    combinedSectionBytes[entry.key] = entry.value.takeBytes();
  }

  // Calculate section addresses and details
  final newSections = <String, NewSection>{};
  int lastSectionEndPA = baseExeBytes.length;
  int lastSectionEndVA = _getLastSectionEndVA(baseExe);

  for (final name in sectionNames) {
    final bytes = combinedSectionBytes[name];
    final physicalSize = bytes?.length ?? 0;
    final virtualSize = combinedSectionLengths[name]!;
    final flags = sectionFlags[name]!;

    final virtualAddress = _sectionAlign(lastSectionEndVA, baseExe);
    final physicalAddress = bytes == null ? 0 : _fileAlign(lastSectionEndPA, baseExe);

    newSections[name] = NewSection(name, flags, virtualSize, physicalSize, virtualAddress, physicalAddress);

    lastSectionEndVA = virtualAddress + virtualSize;
    if (bytes != null) {
      lastSectionEndPA = physicalAddress + physicalSize;
    }
  }

  // Calculate symbol addresses and determine trampolines
  final symbolAddresses = <String, int>{};
  final trampolines = <TrampolinePatch>[];
  for (final entry in objSectionMappings.entries) {
    final obj = entry.key;
    final newSectionMap = entry.value;

    if (obj.symbolTable == null) {
      continue;
    }

    for (final symbol in obj.symbolTable!.values) {
      if (symbol.sectionNumber <= 0) {
        continue;
      }

      final objMappedSection = newSectionMap[symbol.sectionNumber - 1];
      if (objMappedSection == null) {
        // Probably an excluded section
        continue;
      }

      final newSection = newSections[objMappedSection.section.header.name]!;

      final symbolVirtualAddress = imageBase
          + newSection.virtualAddress 
          + objMappedSection.mappedOffset 
          + symbol.value;
      
      final name = symbol.name.shortName 
          ?? obj.stringTable!.strings[symbol.name.offset]!;
      final unmangledName = unmangle(name);
      
      final isFunction = (symbol.type >> 4) == 2;
      
      if (rw.symbols.containsKey(unmangledName)) {
        if (isFunction) {
          trampolines.add(TrampolinePatch(unmangledName, symbolVirtualAddress));
        } else {
          throw Exception('Symbol already defined in base executable: $unmangledName');
        }
      }
    
      symbolAddresses[name] = symbolVirtualAddress;
    }
  }

  // Relocate objects
  for (final section in objSectionMappings.values.expand((m) => m.values)) {
    if (section.section.relocations.isEmpty) {
      continue;
    }

    final newSection = newSections[section.section.header.name]!;

    final virtualAddress = imageBase + newSection.virtualAddress + section.mappedOffset;

    final bytes = Uint8List.sublistView(combinedSectionBytes[section.section.header.name]!,
        section.mappedOffset, section.mappedOffset + section.section.header.sizeOfRawData);

    _relocateSection(
      bytes: bytes, 
      section: section.section, 
      coff: section.coff, 
      rw: rw, 
      newSymbols: symbolAddresses, 
      sectionVirtualAddress: virtualAddress,
    );
  }

  // Patch in trampolines
  final baseExeData = ByteData.sublistView(baseExeBytes);
  for (final trampoline in trampolines) {
    final funcVA = rw.symbols[trampoline.functionName]!;
    final funcPA = funcVA - imageBase;

    print('Converting base executable function ${trampoline.functionName} into trampoline.');

    // Encode as near rel32 jump
    final operand = trampoline.targetVirtualAddress - funcVA - 5;
    baseExeData.setUint8(funcPA, 0xE9);
    baseExeData.setUint32(funcPA + 1, operand, Endian.little);
  }

  // Write new section headers
  final newSectionList = newSections.values.toList();
  for (int i = 0; i < newSectionList.length; i++) {
    final newSection = newSectionList[i];

    final header = SectionHeader(
      name: newSection.name,
      virtualSize: newSection.virtualSize,
      virtualAddress: newSection.virtualAddress,
      sizeOfRawData: newSection.physicalSize,
      pointerToRawData: newSection.physicalAddress,
      pointerToRelocations: 0,
      pointerToLineNumbers: 0,
      numberOfRelocations: 0,
      numberOfLineNumbers: 0,
      flags: newSection.flags,
    );

    baseExeBytes.setRange(0x00000278 + (i * 40), 0x00000278 + ((i + 1) * 40), _sectionHeaderToBytes(header));
  }

  // Update section count and image size
  final newDataLength = lastSectionEndVA - baseExeBytes.length;
  baseExeData
    ..setUint16(0x000000E6, baseExe.coffHeader.numberOfSections + newSectionList.length, Endian.little)
    ..setUint32(0x00000130, 
        baseExe.optionalHeader!.windows!.sizeOfImage + _sectionAlign(newDataLength, baseExe), 
        Endian.little);

  // Append bytes
  final newExeBytes = BytesBuilder(copy: false);
  newExeBytes.add(baseExeBytes);

  for (final newSection in newSectionList) {
    if (newSection.physicalAddress == 0) {
      continue;
    }

    final padding = newSection.physicalAddress - newExeBytes.length;
    newExeBytes.add(Uint8List(padding));
    newExeBytes.add(combinedSectionBytes[newSection.name]!);
  }

  // Write new exe
  await File(outputPath).writeAsBytes(newExeBytes.takeBytes());
}

const secContainsCode = 0x00000020;
const secExecute = 0x20000000;
const secRead = 0x40000000;

const int32Max = 2147483647;
const int32Min = -2147483648;

class NewSection {
  final String name;
  final SectionFlags flags;
  final int virtualSize;
  final int physicalSize;
  final int virtualAddress;
  final int physicalAddress;

  NewSection(this.name, this.flags, this.virtualSize, this.physicalSize, this.virtualAddress, this.physicalAddress);
}

/// A section from an input object file that was merged into the larger new section.
class MappedSection {
  final CoffFile coff;
  final Section section;
  final int sectionIndex;
  /// Byte offset of the section relative to the start of the new section.
  final int mappedOffset;

  MappedSection(this.coff, this.section, this.sectionIndex, this.mappedOffset);
}

/// Record to patch a base executable function into a trampoline that jumps to another virtual address
/// instead of continuing with the original function code.
class TrampolinePatch {
  final String functionName;
  final int targetVirtualAddress;

  TrampolinePatch(this.functionName, this.targetVirtualAddress);
}

void _relocateSection(
    {required Uint8List bytes,
    required Section section,
    required CoffFile coff,
    required RealWarYaml rw,
    required Map<String, int> newSymbols,
    required int sectionVirtualAddress}) {
  final data = ByteData.sublistView(bytes);

  for (final reloc in section.relocations) {
    final symbol = coff.symbolTable![reloc.symbolTableIndex]!;
    assert(symbol.storageClass != 104);

    final symbolName = symbol.name.shortName ??
        coff.stringTable!.strings[symbol.name.offset!]!;
    
    final symbolAddress = newSymbols[symbolName] ?? rw.symbols[unmangle(symbolName)];

    if (symbolAddress == null) {
      final virtualAddress = sectionVirtualAddress + reloc.virtualAddress;
      throw Exception('Unknown symbol: $symbolName @ 0x${virtualAddress.toRadixString(16)}');
    }

    final physicalAddress = reloc.virtualAddress;

    switch (reloc.type) {
      case RelocationTypeI386.dir32:
        final curValue = data.getInt32(physicalAddress, Endian.little);
        final newOp = symbolAddress + curValue;
        if (newOp < int32Min || newOp > int32Max) {
          throw Exception('32-bit relocation generated an operand larger than 32-bits.');
        }
        data.setInt32(physicalAddress, newOp, Endian.little);
        break;
      case RelocationTypeI386.rel32:
        final curValue = data.getInt32(physicalAddress, Endian.little);
        final base = sectionVirtualAddress + reloc.virtualAddress;
        final disp = symbolAddress - base - 4; // why - 4?
        final newOp = disp + curValue;
        if (newOp < int32Min || newOp > int32Max) {
          throw Exception('32-bit relocation generated an operand larger than 32-bits.');
        }
        data.setInt32(physicalAddress, newOp, Endian.little);
        break;
      default:
        throw UnimplementedError(
            'Unimplemented relocation type: ${reloc.type}');
    }
  }
}

int _getLastSectionEndVA(PeFile exe) {
  final lastSec = exe.sections.last.header;

  return lastSec.virtualAddress + lastSec.virtualSize;
}

int _sectionAlign(int value, PeFile exe) {
  final sectionAlignment = exe.optionalHeader!.windows!.sectionAlignment;
  
  return (value / sectionAlignment).ceil() * sectionAlignment;
}

int _fileAlign(int value, PeFile exe) {
  final fileAlignment = exe.optionalHeader!.windows!.fileAlignment;
  
  return (value / fileAlignment).ceil() * fileAlignment;
}

Uint8List _sectionHeaderToBytes(SectionHeader header) {
  final data = ByteData(40);
  
  final nameChars = header.name.codeUnits;
  for (int i = 0; i < 8 && i < nameChars.length; i++) {
    data.setUint8(i, nameChars[i]);
  }
  for (int i = 0; i < (8 - nameChars.length); i++) {
    data.setUint8(i + nameChars.length, 0);
  }

  data.setUint32(8, header.virtualSize, Endian.little);
  data.setUint32(12, header.virtualAddress, Endian.little);
  data.setUint32(16, header.sizeOfRawData, Endian.little);
  data.setUint32(20, header.pointerToRawData, Endian.little);
  data.setUint32(24, header.pointerToRelocations, Endian.little);
  data.setUint32(28, header.pointerToLineNumbers, Endian.little);
  data.setUint16(32, header.numberOfRelocations, Endian.little);
  data.setUint16(34, header.numberOfLineNumbers, Endian.little);
  data.setUint32(36, header.flags.rawValue, Endian.little);

  return data.buffer.asUint8List();
}
