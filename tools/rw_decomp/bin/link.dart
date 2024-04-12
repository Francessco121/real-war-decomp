import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';
import 'package:pe_coff/pe.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';

class LinkException implements Exception {
  final String message;

  LinkException(this.message);
}

void main(List<String> args) {
  final argParser = ArgParser()
      ..addOption('root')
      ..addFlag('no-success-message', defaultsTo: false, negatable: false,
          help: 'Don\'t write to stdout on success.');

  final argResult = argParser.parse(args);
  final bool noSuccessMessage = argResult['no-success-message'];
  final String projectDir = p.absolute(argResult['root'] ?? p.current);

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Parse base exe
  final String baseExeFilePath = p.join(projectDir, rw.config.exePath);
  final baseExeBytes = File(baseExeFilePath).readAsBytesSync();
  final baseExe = PeFile.fromList(baseExeBytes);
  
  // Setup
  final String srcDirPath = p.join(projectDir, rw.config.srcDir);
  final String buildDirPath = p.join(projectDir, rw.config.buildDir);
  final String buildObjDirPath = p.join(projectDir, rw.config.buildDir, 'obj');

  Directory(buildDirPath).createSync();

  try {
    // Collect functions to patch in from built object files
    final List<ObjFunction> objFunctions = _loadObjs(rw, 
        srcDirPath: srcDirPath, 
        buildObjDirPath: buildObjDirPath);
    
    // Link
    final funcMapping = <MappingEntry>[];

    final imageBase = rw.exe.imageBase;

    final baseTextStartVA = imageBase + rw.exe.textVirtualAddress;
    final baseTextEndVA = imageBase + rw.exe.rdataVirtualAddress;
    final baseTextStartPA = rw.exe.textFileOffset;

    final hoistedTextBuilder = BytesBuilder(copy: false);
    final hoistedBaseVA = _sectionAlign(_getLastSectionEndVA(baseExe), baseExe);

    for (final func in objFunctions) {
      // Double check that this symbol is even within .text
      if (func.symbolAddress < baseTextStartVA || func.symbolAddress >= baseTextEndVA) {
        throw LinkException('Function symbol ${func.symbolName} is not within the .text section. '
            'Address: 0x${func.symbolAddress.toRadixString(16)}');
      }

      try {
        final funcPA = (func.symbolAddress - baseTextStartVA) + baseTextStartPA;

        if (func.objSectionBytes.lengthInBytes <= func.expectedSize) {
          // Recompiled function fits within its base exe location, patch it in
          relocateSection(func.obj, func.objSection, func.objSectionBytes, 
              targetVirtualAddress: func.symbolAddress, 
              symbolLookup: (sym) => rw.lookupSymbol(unmangle(sym)));

          baseExeBytes.setRange(funcPA, funcPA + func.objSectionBytes.lengthInBytes, func.objSectionBytes);

          if (func.objSectionBytes.lengthInBytes < func.expectedSize) {
            // Function is too small, pad with nops
            for (int i = func.objSectionBytes.lengthInBytes; i < func.expectedSize; i++) {
              baseExeBytes[funcPA + i] = 0x90; // 0x90 = x86 1-byte NOP
            }
          }

          funcMapping.add(MappingEntry(
            physicalAddress: funcPA,
            size: func.expectedSize,
            symbolName: func.symbolName,
            srcName: func.objName,
            hoistedPhysicalAddress: null
          ));
        } else {
          // Function is too big, move it into the hoisted .text section
          final hoistedVA = hoistedBaseVA + imageBase + hoistedTextBuilder.length;
          final hoistedPA = baseExeBytes.length + hoistedTextBuilder.length;
          relocateSection(func.obj, func.objSection, func.objSectionBytes, 
              targetVirtualAddress: hoistedVA, 
              symbolLookup: (sym) => rw.lookupSymbol(unmangle(sym)));
          
          hoistedTextBuilder.add(func.objSectionBytes);

          // Patch in relative jump to the moved function + nop padding in its place
          final jumpInst = ByteData(5);
          final operand = hoistedVA - func.symbolAddress - 5;
          jumpInst.setUint8(0, 0xE9);
          jumpInst.setUint32(1, operand, Endian.little);

          baseExeBytes.setRange(funcPA, funcPA + 5, jumpInst.buffer.asUint8List());
          baseExeBytes[funcPA + 5] = 0xC3; // unreachable RET to help disassemblers detect the function end
          for (int i = 6; i < func.expectedSize; i++) {
            baseExeBytes[funcPA + i] = 0x90; // 0x90 = x86 1-byte NOP
          }

          funcMapping.add(MappingEntry(
            physicalAddress: funcPA,
            size: func.expectedSize,
            symbolName: func.symbolName,
            srcName: func.objName,
            hoistedPhysicalAddress: hoistedPA
          ));
        }
      } on RelocationException catch (ex) {
        throw LinkException('${func.objName}: ${ex.message}');
      }
    }

    // Build new exe bytes
    final hoistedTextSize = hoistedTextBuilder.length;
    final Uint8List exeBytes;

    if (hoistedTextBuilder.isEmpty) {
      exeBytes = baseExeBytes;
    } else {
      final builder = BytesBuilder(copy: false)
          ..add(baseExeBytes)
          ..add(hoistedTextBuilder.takeBytes());
      
      final expectedTextEnd = _fileAlign(builder.length, baseExe);
      final padding = expectedTextEnd - builder.length;
      builder.add(Uint8List(padding));

      exeBytes = builder.takeBytes();
    }

    // If we have a hoisted .text section, add the section header and patch the
    // section count and image size
    if (hoistedTextSize > 0) {
      final textHeader = SectionHeader(
        name: '.text',
        virtualSize: hoistedTextSize,
        virtualAddress: hoistedBaseVA,
        sizeOfRawData: hoistedTextSize,
        pointerToRawData: baseExeBytes.lengthInBytes,
        pointerToRelocations: 0,
        pointerToLineNumbers: 0,
        numberOfRelocations: 0,
        numberOfLineNumbers: 0,
        flags: SectionFlags(
          SectionFlagValues.cntCode | 
          SectionFlagValues.memExecute | 
          SectionFlagValues.memRead),
      );

      exeBytes.setRange(
          0x00000278, 
          0x00000278 + SectionHeader.byteSize, 
          textHeader.toBytes());
      
      final newDataLength = hoistedTextSize;
      final exeData = ByteData.sublistView(exeBytes);
      exeData
        ..setUint16(0x000000E6, baseExe.coffHeader.numberOfSections + 1, Endian.little)
        ..setUint32(0x00000130, 
            baseExe.optionalHeader!.windows!.sizeOfImage + _sectionAlign(newDataLength, baseExe), 
            Endian.little);
    }

    // Write exe file
    final String outExeFilePath = p.join(projectDir, rw.config.buildDir, 'RealWar.exe');
    File(outExeFilePath).writeAsBytesSync(exeBytes);

    // Write mapping file
    _writeMappingFile(
        File(p.join(projectDir, rw.config.buildDir, 'RealWar.funcmap')),
        funcMapping);

    if (!noSuccessMessage) {
      print('Linked: ${p.relative(outExeFilePath, from: projectDir)}.');
    }
  } on LinkException catch (ex) {
    print('ERR: ${ex.message}');
    exit(-1);
  }
}

class ObjFunction {
  final CoffFile obj;
  final String objName;
  final Section objSection;
  final Uint8List objSectionBytes;
  final String symbolName;
  final int symbolAddress;
  final int expectedSize;

  ObjFunction({
    required this.obj, 
    required this.objName, 
    required this.objSection,
    required this.objSectionBytes,
    required this.symbolName, 
    required this.symbolAddress, 
    required this.expectedSize,
  });
}

List<ObjFunction> _loadObjs(RealWarYaml rw, 
    {required String srcDirPath, required String buildObjDirPath}) {
  final objFunctions = <ObjFunction>[];

  final srcDir = Directory(srcDirPath);
  for (final file in srcDir.listSync(recursive: true)) {
    if (file is! File) {
      continue;
    }
    final ext = p.extension(file.path);
    if (ext != '.c' && ext != '.cpp') {
      continue;
    }

    final objRelativePath = p.relative(p.setExtension(file.absolute.path, '.obj'), from: srcDir.absolute.path);
    final objFile = File(p.join(buildObjDirPath, objRelativePath));
    if (!objFile.existsSync()) {
      stderr.writeln('Could not find ${p.relative(objFile.path, from: rw.dir)}. Have you ran the build?');
      exit(-1);
    }

    final objBytes = objFile.readAsBytesSync();
    final obj = CoffFile.fromList(objBytes);

    objFunctions.addAll(_loadObjFunctions(obj, objBytes, objRelativePath, rw));
  }

  objFunctions.sort((a, b) => a.symbolAddress.compareTo(b.symbolAddress));

  return objFunctions;
}

Iterable<ObjFunction> _loadObjFunctions(CoffFile obj, Uint8List objBytes, String objName, RealWarYaml rw) sync* {
  if (obj.symbolTable == null) {
    return;
  }

  for (final symbol in obj.symbolTable!.values) {
    // Symbol is a function defined in this object file if it has a section number and MSB == 2
    if (symbol.sectionNumber > 0 && (symbol.type >> 4) == 2) {
      final name = symbol.name.shortName ??
          obj.stringTable!.strings[symbol.name.offset]!;
      final unmangledName = unmangle(name);
      
      final Section section = obj.sections[symbol.sectionNumber - 1];

      // Assume COMDAT
      assert(section.header.flags.lnkComdat);

      // Look up symbol in rw.yaml
      final rwSymbol = rw.symbols[unmangledName];
      if (rwSymbol == null) {
        throw LinkException('Unknown function symbol: $unmangledName @ '
            '$objName/0x${section.header.pointerToRawData.toRadixString(16)}');
      }
      if (rwSymbol.size == null) {
        throw LinkException('Function symbol $unmangledName must have a defined size in rw.yaml!');
      }
      
      yield ObjFunction(
        obj: obj,
        objName: objName,
        objSection: section,
        objSectionBytes: Uint8List.sublistView(objBytes, 
            section.header.pointerToRawData, 
            section.header.pointerToRawData + section.header.sizeOfRawData),
        symbolName: unmangledName, 
        symbolAddress: rwSymbol.address,
        expectedSize: rwSymbol.size!
      );
    }
  }
}

const _asciiSpace = 32;

class MappingEntry {
  final int physicalAddress;
  final int size;
  final String symbolName;
  final String srcName;
  final int? hoistedPhysicalAddress;

  MappingEntry({
    required this.physicalAddress, 
    required this.size, 
    required this.symbolName, 
    required this.srcName, 
    required this.hoistedPhysicalAddress,
  });
}

void _writeMappingFile(File mapFile, List<MappingEntry> segmentMapping) {
  segmentMapping.sort((a, b) => a.physicalAddress.compareTo(b.physicalAddress));

  final int longestSymbolName = segmentMapping
      .fold(0, (longest, e) => max(e.symbolName.length, longest));
  
  final strBuffer = StringBuffer();
  strBuffer.write('Offset'.padRight(10));
  strBuffer.writeCharCode(_asciiSpace);
  strBuffer.write('Size'.padRight(10));
  strBuffer.writeCharCode(_asciiSpace);
  strBuffer.write('Hoist'.padRight(10));
  strBuffer.writeCharCode(_asciiSpace);
  strBuffer.write('Func'.padRight(longestSymbolName));
  strBuffer.writeCharCode(_asciiSpace);
  strBuffer.writeln('Source File');

  for (final entry in segmentMapping) {
    strBuffer.write('0x${entry.physicalAddress.toRadixString(16)}'.padLeft(10));
    strBuffer.writeCharCode(_asciiSpace);
    strBuffer.write('0x${entry.size.toRadixString(16)}'.padLeft(10));
    strBuffer.writeCharCode(_asciiSpace);
    if (entry.hoistedPhysicalAddress != null) {
      strBuffer.write('0x${entry.hoistedPhysicalAddress!.toRadixString(16)}'.padLeft(10));
    } else {
      strBuffer.write(''.padLeft(10));
    }
    strBuffer.writeCharCode(_asciiSpace);
    strBuffer.write(entry.symbolName.padRight(longestSymbolName));
    strBuffer.writeCharCode(_asciiSpace);
    strBuffer.writeln(entry.srcName);
  }

  mapFile.writeAsStringSync(strBuffer.toString());
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
