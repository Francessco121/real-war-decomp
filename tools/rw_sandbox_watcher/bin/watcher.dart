import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pe_coff/coff.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/symbol_utils.dart';
import 'package:watcher/watcher.dart';
import 'package:x86_analyzer/functions.dart';

const vsPath = 'C:\\Program Files (x86)\\Microsoft Visual Studio';
const dxPath = 'C:\\dx8sdk';
final workingDirectory = p.current;
final projectDir = p.normalize(p.join(workingDirectory, '..'));
final clWrapperExePath = p.join(projectDir, 'tools/rw_decomp/build/cl_wrapper.exe');
final srcPath = p.join(p.current, 'src');
final objPath = p.join(p.current, 'obj');

final capstoneDll = DynamicLibrary.open(p.join(projectDir, 'tools/capstone.dll'));
final functionDisassembler = FunctionDisassembler.init(capstoneDll);

String cleanPath(String path) => p.relative(path, from: workingDirectory).replaceAll('/', '\\');
String makeObjPath(String cPath) => p.join(
  'obj',
  p.dirname(p.relative(cPath, from: srcPath)),
  p.basenameWithoutExtension(cPath) + '.obj'
);
String makePdbPath(String cPath) => p.join(
  'obj',
  p.dirname(p.relative(cPath, from: srcPath)),
  p.basenameWithoutExtension(cPath) + '.pdb'
);
String makeDisasmPath(String cPath) => p.join(
  p.dirname(cPath),
  p.basenameWithoutExtension(cPath) + '.disasm.s'
);

const fakeTextAddressStart = 0x1000000;
const fakeDataAddressStart = 0x2000000;
const fakeBssAddressStart = 0x3000000;
final memAddressRegex = RegExp(r'(0x[0-9a-fA-F]{4,})');

String replaceAddressesWithSymbols(String str, Map<int, String> symbols) {
  return str.replaceAllMapped(memAddressRegex, (match) {
    final raw = match.group(1)!;
    final address = int.parse(raw);
    
    String? name = symbols[address];
    if (name == null && address >= fakeDataAddressStart) {
      // Within fake data address range but we don't have an exact match,
      // display the closest symbol with an offset
      final closest = symbols.keys.fold(-1, (best, addr) => 
          addr < address && (addr - address).abs() < (best - address).abs() 
            ? addr 
            : best);
      
      if (closest >= 0) {
        final closestName = symbols[closest];
        final dist = address - closest;
        if (dist < 0x1000) {
          name = '$closestName + 0x${dist.toRadixString(16)}';
        }
      }
    }

    return name ?? raw;
  });
}

Future<void> compile(String cPath) async {
  // Build command
  cPath = p.relative(cPath, from: workingDirectory).replaceAll('/', '\\');

  final String objPath = p.normalize(makeObjPath(cPath));
  final String pdbPath = p.normalize(makePdbPath(cPath));
  final String disasmPath = p.normalize(makeDisasmPath(cPath));

  final args = [
    '--vsdir=$vsPath',
    '--no-library-warnings',
    // Standard flags used by the decomp
    '--flag=/W4,/Og,/Oi,/Ot,/Oy,/Ob1,/Gs,/Gf,/Gy',
    // Additional debug info for sandbox
    '--flag=/Fd$pdbPath,/Zi',
    '-L', '$dxPath\\include',
    '-L', '$vsPath\\VC98\\Include',
    '-o', objPath,
    '-i', cPath
  ];

  print('[${DateTime.now()}] cl_wrapper ${args.join(' ')}');

  // Ensure obj directory exists
  await Directory(p.dirname(objPath)).create();

  // Compile
  final result = await Process.run(clWrapperExePath, args,
    workingDirectory: workingDirectory,
  );

  final disasmFile = File(disasmPath);
  final writer = disasmFile.openWrite();
  
  if (result.exitCode == 0) {
    // Success, disassemble the obj
    await disassemble(writer, objPath);

    // Append compile warnings/errors if any
    final stdout = result.stdout as String;
    if (stdout.isNotEmpty) {
      writer.writeln();
      writer.writeln('# cl_wrapper stdout:');
      writer.writeln(LineSplitter.split(stdout).map((l) => '# $l').join('\n'));
    }

    final stderr = result.stderr as String;
    if (stderr.isNotEmpty) {
      writer.writeln();
      writer.writeln('# cl_wrapper stderr:');
      writer.writeln(LineSplitter.split(stderr).map((l) => '# $l').join('\n'));
    }
  } else {
    // Failed to compile, write error
    writer.writeln(result.stdout);
    writer.writeln(result.stderr);
  }

  await writer.flush();
  await writer.close();
}

Future<void> disassemble(IOSink writer, String objPath) async {
  // Parse compiled COFF file
  Uint8List coffBytes = await File(objPath).readAsBytes();
  final coff = CoffFile.fromList(coffBytes);

  // Disassemble each function
  int functions = 0;
  int funcVA = 0;

  // We want to display actual symbols names in the disassembly, but these are only able
  // to be looked up from the code itself *after* relocation. Rather than do the job of
  // a real linker (or try to run one), assign a fake symbol address for each symbol as
  // referenced by each section relocation. We'll use these later to replace address operands
  // with their corresponding symbol name.
  int nextFakeTextAddr = fakeTextAddressStart;
  int nextFakeDataAddr = fakeDataAddressStart;
  int nextFakeBssAddr = fakeBssAddressStart;

  final fakeSymAddrsToSyms = <int, String>{};
  final symsToFakeSymAddrs = <String, int>{};

  for (final (i, section) in coff.sections.indexed) {
    if (section.header.name != '.text') {
      continue;
    }

    // Get section bytes
    final sectionBytes = Uint8List.sublistView(coffBytes, 
        section.header.pointerToRawData, 
        section.header.pointerToRawData + section.header.sizeOfRawData);
    
    final sectionData = ByteData.sublistView(sectionBytes);

    // Apply relocations
    for (final reloc in section.relocations) {
      final symbol = coff.symbolTable![reloc.symbolTableIndex]!;
      assert(symbol.storageClass != StorageClass.section);

      final symbolName = symbol.name.shortName ??
          coff.stringTable!.strings[symbol.name.offset!]!;
      
      int? symbolAddress = symsToFakeSymAddrs[symbolName];
      if (symbolAddress == null) {
        final sectionName = symbol.sectionNumber == 0
          ? '.bss'
          : coff.sections[symbol.sectionNumber - 1].header.name;

        switch (sectionName) {
          case '.text':
            symbolAddress = nextFakeTextAddr;
            nextFakeTextAddr += max(4, symbol.value);
          case '.data':
            symbolAddress = nextFakeDataAddr;
            nextFakeDataAddr += max(4, symbol.value);
          case '.bss':
            symbolAddress = nextFakeBssAddr;
            nextFakeBssAddr += max(4, symbol.value);
          default:
            throw UnimplementedError();
        }

        fakeSymAddrsToSyms[symbolAddress] = unmangle(symbolName);
        symsToFakeSymAddrs[symbolName] = symbolAddress;
      }

      applyRelocation(reloc, sectionData, funcVA, symbolAddress);
    }

    // Get function name (assumes we compiled with COMDATs enabled)
    final funcSymbol = coff.symbolTable!.values
        .firstWhere((s) => s.type == 0x20 && s.value == 0 && s.sectionNumber == (i + 1));
    final funcName = unmangle(funcSymbol.name.shortName
        ?? coff.stringTable!.strings[funcSymbol.name.offset!]!);
    
    // Disassemble the function
    final func = functionDisassembler.disassembleFunction(
        FileData.fromList(sectionBytes), 0, 
        address: funcVA, 
        name: funcName,
        endAddressHint: funcVA + sectionBytes.length);

    if (functions > 0) {
      writer.writeln();
      writer.writeln();
    }
    
    writer.writeln('${func.name}:');

    for (final inst in func.instructions) {
      if (func.branchTargets.contains(inst.address)) {
        writer.write(makeBranchLabel(inst.address));
        writer.writeln(':');
      }

      writer.write('/* ${inst.address.toRadixString(16)}:  ${inst.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} */'.padRight(32));
      writer.write(inst.mnemonic.padRight(10));
      writer.write(' ');
      // Replace branch addresses with symbols where possible
      if (inst.isRelativeJump) {
        if (inst.operands.length == 1 && inst.operands[0].imm != null && 
            inst.operands[0].imm! < fakeTextAddressStart) {
          writer.write(makeBranchLabel(inst.operands[0].imm!));
        } else {
          writer.write(replaceAddressesWithSymbols(inst.opStr, fakeSymAddrsToSyms));
        }
      } else {
        writer.write(replaceAddressesWithSymbols(inst.opStr, fakeSymAddrsToSyms));
      }
      writer.writeln();
    }

    functions += 1;
    funcVA += section.header.sizeOfRawData;
  }

  if (functions > 0) {
    writer.writeln();
    writer.writeln();
  }

  writer.writeln('# RELOCATED SYMBOL MAPPING:');
  final fakeSyms = fakeSymAddrsToSyms.entries.toList();
  fakeSyms.sort((a, b) => a.key.compareTo(b.key));

  for (final entry in fakeSyms) {
    writer.writeln('# ${entry.value} = 0x${entry.key.toRadixString(16)}');
  }
}

Future<bool> isOutdated(String cPath) async {
  final String disasmPath = makeDisasmPath(cPath);

  final cFile = File(cPath);
  final disasmFile = File(disasmPath);

  if (!disasmFile.existsSync()) {
    return true;
  }

  return (await cFile.lastModified()).isAfter((await disasmFile.lastModified()));
}

Future<void> removeDisasmResult(String cPath) async {
  final String objPath = makeObjPath(cPath);
  final String disasmPath = makeDisasmPath(cPath);

  final objFile = File(objPath);
  final disasmFile = File(disasmPath);

  if (objFile.existsSync()) {
    print('[${DateTime.now()}] rm $objPath');
    await objFile.delete();
  }

  if (disasmFile.existsSync()) {
    print('[${DateTime.now()}] rm $disasmPath');
    await disasmFile.delete();
  }
}

Future<void> main() async {
  // Compile outdated files
  await for (final entity in Directory(srcPath).list(recursive: true)) {
    if (entity is File && 
        (p.extension(entity.path) == '.c' || p.extension(entity.path) == '.cpp') && 
        (await isOutdated(entity.path))) {
      await compile(entity.path);
    }
  }

  // Listen for source file changes
  final subscription = DirectoryWatcher(srcPath).events.listen((event) {
    final ext = p.extension(event.path);
    if (ext != '.c' && ext != '.cpp') {
      return;
    }

    final String cleanedPath = cleanPath(event.path);

    if (event.type == ChangeType.ADD || event.type == ChangeType.MODIFY) {
      compile(cleanedPath);
    } else if (event.type == ChangeType.REMOVE) {
      removeDisasmResult(cleanedPath);
    }
  });

  print('Watching...');
  
  // Let user enter 'q' to gracefully exit (if in terminal)
  if (stdin.hasTerminal) {
    print('Press q to exit.');

    stdin.echoMode = false;
    stdin.lineMode =false;

    await stdin.where((bytes) => utf8.decode(bytes).startsWith('q')).first;

    print('Shutting down...');
    subscription.cancel();

    functionDisassembler.dispose();
    capstoneDll.close();
  }
}
