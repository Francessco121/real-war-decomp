import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_mod/rwmod_yaml.dart';
import 'package:x86_analyzer/functions.dart';

/// Extracts functions as .obj files for each listed function clone in rwmod.yaml.
void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('decomp-root', mandatory: true, help: 'Path to the root of the decomp project.')
      ..addOption('mod-root', mandatory: true, help: 'Path to the root of the mod project.')
      ..addOption('capstone', help: 'Path to capstone.dll.');

  final argResult = argParser.parse(args);
  final String decompDir = p.absolute(argResult['decomp-root'] ?? p.current);
  final String modDir = p.absolute(argResult['mod-root'] ?? p.current);
  final String? capstonePath = argResult['capstone'];

  // Load configs
  final rw = RealWarYaml.load(
      File(p.join(decompDir, 'rw.yaml')).readAsStringSync(),
      dir: decompDir);

  final rwmod = RealWarModYaml.load(
      File(p.join(modDir, 'rwmod.yaml')).readAsStringSync());
  
  // Init disassembler
  final capstoneDll = ffi.DynamicLibrary.open(capstonePath ?? 'capstone.dll');
  final disassembler = FunctionDisassembler.init(capstoneDll);
  
  // Parse exe
  final String exeFilePath = p.join(decompDir, rw.config.exePath);
  final exeBytes = File(exeFilePath).readAsBytesSync();
  final exe = PeFile.fromList(exeBytes);

  // Setup
  final String binDirPath = p.join(modDir, 'bin');
  Directory(binDirPath).createSync();

  // Extract
  final imageBase = exe.optionalHeader!.windows!.imageBase;
  final textSection = exe.sections.firstWhere((s) => s.header.name == '.text');
  final textVA = textSection.header.virtualAddress;
  final textPA = textSection.header.pointerToRawData;
  final exeData = FileData.fromList(exeBytes);

  for (final clone in rwmod.funcClones.entries) {
    final baseFuncName = clone.key;
    final cloneFuncName = clone.value;

    final funcVA = rw.symbols[baseFuncName];
    if (funcVA == null) {
      throw Exception('Cannot clone/extract non-existent function: $baseFuncName');
    }

    final funcPA = textPA + (funcVA - textVA - imageBase);
    
    // Determine function size
    final func = disassembler.disassembleFunction(
        exeData, funcPA, address: funcVA, name: baseFuncName);

    // Create symbol for function
    final strings = StringTableBuilder();
    final symbols = <SymbolTableEntry>[];

    final mangledFuncName = '_$cloneFuncName';
    symbols.add(SymbolTableEntry(
        name: mangledFuncName.length <= 8 
            ? SymbolName.short(mangledFuncName)
            : SymbolName.long(strings.add(mangledFuncName)), 
        value: 0, 
        sectionNumber: 1, 
        type: 2 << 4, 
        storageClass: 3, 
        auxSymbols: const []));
    
    // Generate relocations
    final relocations = <RelocationEntry>[];

    _generateRelocations(func, relocations, symbols, strings, funcVA);

    // Build string table
    final StringTable stringTable = strings.build();

    // Figure out where to put everything
    const headerSize = 20;
    const sectionTableSize = 40;
    final relocationTableSize = 10 * relocations.length;

    // Generate section table
    final textSection = SectionHeader(
        name: '.text', 
        virtualSize: 0, 
        virtualAddress: 0, 
        sizeOfRawData: func.size, 
        pointerToRawData: headerSize + sectionTableSize, 
        pointerToRelocations: headerSize + sectionTableSize + func.size, 
        pointerToLineNumbers: 0, 
        numberOfRelocations: relocations.length, 
        numberOfLineNumbers: 0, 
        flags: SectionFlags(secContainsCode | secExecute | secRead));
    
    // Generate COFF header
    final coffHeader = CoffHeader(
        machine: 0x14C, // IMAGE_FILE_MACHINE_I386
        numberOfSections: 1, 
        timeDateStamp: DateTime.now(), 
        pointerToSymbolTable: headerSize + sectionTableSize + func.size + relocationTableSize, 
        numberOfSymbols: symbols.length, 
        sizeOfOptionalHeader: 0, 
        characteristics: Characteristics(0));
    
    // Build object file
    final builder = BytesBuilder(copy: false);
    builder.add(_coffHeaderToBytes(coffHeader));
    builder.add(_sectionHeaderToBytes(textSection));
    builder.add(Uint8ClampedList.sublistView(exeBytes, funcPA, funcPA + func.size));
    builder.add(_relocationTableToBytes(relocations));
    builder.add(_symbolTableToBytes(symbols));
    builder.add(_stringTableToBytes(stringTable));
    
    // Write binary
    final binFilePath = p.join(binDirPath, '$cloneFuncName.obj');
    File(binFilePath).writeAsBytesSync(builder.takeBytes());
  }
  
  print('Done.');
}

const secContainsCode = 0x00000020;
const secExecute = 0x20000000;
const secRead = 0x40000000;

class StringTableBuilder {
  int _size = 0;
  final _strings = <int, String>{};

  int add(String string) {
    final index = _size + 4;
    _strings[index] = string;
    _size += string.length + 1;

    return index;
  }

  StringTable build() {
    return StringTable(size: _size, strings: _strings);
  }
}

Uint8List _coffHeaderToBytes(CoffHeader header) {
  final data = ByteData(20);
  data.setUint16(0, header.machine, Endian.little);
  data.setUint16(2, header.numberOfSections, Endian.little);
  data.setUint32(4, header.timeDateStamp.millisecondsSinceEpoch ~/ 1000, Endian.little);
  data.setUint32(8, header.pointerToSymbolTable, Endian.little);
  data.setUint32(12, header.numberOfSymbols, Endian.little);
  data.setUint16(16, header.sizeOfOptionalHeader, Endian.little);
  data.setUint16(18, header.characteristics.rawValue, Endian.little);

  return data.buffer.asUint8List();
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

Uint8List _relocationTableToBytes(List<RelocationEntry> relocations) {
  final builder = BytesBuilder(copy: false);

  for (final rel in relocations) {
    final data = ByteData(10);
    data.setInt32(0, rel.virtualAddress, Endian.little);
    data.setInt32(4, rel.symbolTableIndex, Endian.little);
    data.setInt16(8, rel.type, Endian.little);

    builder.add(data.buffer.asUint8List());
  }

  return builder.takeBytes();
}

Uint8List _symbolTableToBytes(List<SymbolTableEntry> symbols) {
  final builder = BytesBuilder(copy: false);

  for (final sym in symbols) {
    final data = ByteData(18);
    if (sym.name.shortName != null) {
      final nameChars = sym.name.shortName!.codeUnits;
      for (int i = 0; i < 8 && i < nameChars.length; i++) {
        data.setUint8(i, nameChars[i]);
      }
      for (int i = 0; i < (8 - nameChars.length); i++) {
        data.setUint8(i + nameChars.length, 0);
      }
    } else {
      data.setUint32(0, 0, Endian.little);
      data.setUint32(4, sym.name.offset!, Endian.little);
    }
    data.setUint32(8, sym.value, Endian.little);
    data.setInt16(12, sym.sectionNumber, Endian.little);
    data.setUint16(14, sym.type, Endian.little);
    data.setUint8(16, sym.storageClass);
    data.setUint8(17, sym.auxSymbols.length);
    assert(sym.auxSymbols.isEmpty);

    builder.add(data.buffer.asUint8List());
  }

  return builder.takeBytes();
}

Uint8List _stringTableToBytes(StringTable table) {
  final builder = BytesBuilder(copy: false);
  builder.add((ByteData(4)..setUint32(0, table.size, Endian.little)).buffer.asUint8List());

  final strings = table.strings.entries.toList();
  strings.sort((a, b) => a.key.compareTo(b.key));

  for (final string in strings.map((e) => e.value)) {
    for (final c in string.codeUnits) {
      builder.addByte(c);
    }
    builder.addByte(0);
  }

  return builder.takeBytes();
}

void _generateRelocations(DisassembledFunction func, 
    List<RelocationEntry> relocations, 
    List<SymbolTableEntry> symbols,
    StringTableBuilder strings,
    int funcVA) {
  for (final inst in func.instructions) {
    if (inst.mnemonic == 'call' && inst.bytes[0] == 0xE8) {
      // Add REL32 relocation such that the relocated value plus the address
      // that's already in the asm equals a displacement to the target func
      final symTableIndex = symbols.length;
      // NOTE: dont do the math here cause capstone already adjusted the address for us
      final targetFuncVA = inst.operands.first.imm!;
      symbols.add(SymbolTableEntry(
          name: SymbolName.long(strings.add('_base_exe_func_${targetFuncVA.toRadixString(16)}')), 
          value: inst.address + 5,
          sectionNumber: 0xFFFF, // -1 (symbol name isn't an address, but we have an absolute value instead)
          type: 0, 
          storageClass: 2, 
          auxSymbols: const []));

      relocations.add(RelocationEntry(
          virtualAddress: (inst.address + 1) - funcVA, 
          symbolTableIndex: symTableIndex, 
          type: RelocationTypeI386.rel32));
    }
  }
}
