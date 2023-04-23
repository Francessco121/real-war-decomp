import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ansicolor/ansicolor.dart';
import 'package:collection/collection.dart';
import 'package:dart_console/dart_console.dart';
import 'package:diff/build.dart';
import 'package:diff/diff.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe_coff.dart';
import 'package:rw_yaml/rw_yaml.dart';
import 'package:watcher/watcher.dart';

/*
  1. find address of requested symbol and determine which obj file to look at
  2. disassemble exe at the symbol address up until the RET
  3. disassemble obj at the symbol address in the obj up until the RET
  4. assign each unique instruction an id (for diffing, do exe instructions just once)
  5. diff id lists
  6. using diff edits, reconstruct instruction lists
  7. create per-line diffs (comparing mnemonic, register, value, etc. differences)
  8. render! (keep previous scroll position)
  9. on source file changed, recompile obj, and repeat from 3.
*/

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    print('Usage: diff.dart <func symbol name>');
    return;
  }

  // Assume we're ran from the diff package dir
  final String projectDir = p.normalize(p.join(p.current, '../../'));

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Figure out symbol address and related obj path
  final String symbolName = args[0];
  final int? virtualAddress = rw.symbols[symbolName];
  if (virtualAddress == null) {
    print('Cannot locate symbol address: $symbolName');
    return;
  }
  final String? objPath =
      rw.segments.firstWhereOrNull((s) => s.address >= virtualAddress)?.objPath;
  if (objPath == null) {
    print('Symbol not mapped to an object file: $symbolName');
    return;
  }

  // Compute paths
  final String exeFilePath = p.join(projectDir, rw.config.exePath);
  final String objFilePath =
      p.join(projectDir, rw.config.buildDir, 'obj', '$objPath.obj');
  final String srcDirPath = p.join(projectDir, rw.config.srcDir);
  final String cFilePath = p.join(srcDirPath, '$objPath.c');

  // Compute physical (file) address of the symbol in the base exe
  final int physicalAddress =
      virtualAddress - 0x400000; // 0x400000 == imageBase

  // Init capstone
  final capstoneDll = ffi.DynamicLibrary.open('../capstone.dll');
  final disassembler = FunctionDisassembler.init(capstoneDll);

  print('Loading...');
  
  try {
    // Disassemble base exe function
    final List<Instruction> exeInsts =
        _loadExeInstructions(exeFilePath, physicalAddress, disassembler);

    // Build config
    final builder = Builder(rw);

    // Init console
    final console = Console();

    List<DiffLine> lines = [];
    int scrollPosition = 0;

    bool refreshing = false;
    bool waitingForRefresh = false;
    Completer<void>? refreshCompleter;

    void refresh() {
      // Clamp scroll position
      scrollPosition = max(min(scrollPosition, lines.length - 1), 0);

      // Update screen
      _displayDiff(console, lines, scrollPosition);
    }

    Future<void> recompileAndRefresh() async {
      if (refreshing) {
        if (waitingForRefresh) {
          return;
        }

        waitingForRefresh = true;
        await refreshCompleter!.future;
        waitingForRefresh = false;
      }

      refreshing = true;
      refreshCompleter = Completer();

      console.cursorPosition = Coordinate(0, console.windowWidth - 'Compiling...'.length);
      console.write('Compiling...');

      // Compile
      bool error = false;
      try {
        await builder.compile(cFilePath);
      } on BuildException catch (ex) {
        _displayError(console, ex.message);
        error = true;
      }

      if (!error) {
        // Disassemble
        final List<Instruction> objInsts =
            _loadObjInstructions(objFilePath, symbolName, disassembler);

        // Diff
        lines = _diff(exeInsts, objInsts);
        
        // Refresh
        refresh();
      }

      refreshing = false;
      refreshCompleter!.complete();
    }

    // Listen for src directory changes
    final subscription = DirectoryWatcher(srcDirPath.replaceAll('/', '\\')).events.listen((event) {
      final ext = p.extension(event.path).toLowerCase();
      if (ext != '.c' && ext != '.h') {
        return;
      }

      if (event.type == ChangeType.ADD || event.type == ChangeType.MODIFY) {
        recompileAndRefresh();
      }
    });

    // Initial display
    await recompileAndRefresh();

    // Input loop
    try {
      console.rawMode = true;
      console.hideCursor();

      final consoleReader = await ConsoleReadIsolate.init();

      try {
        while (true) {
          final key = await consoleReader.readKey();
          if (key.char == 'q' || key.controlChar == ControlCharacter.ctrlC) {
            console.clearScreen();
            break;
          }

          if (key.controlChar == ControlCharacter.arrowDown) {
            scrollPosition++;
            refresh();
          } else if (key.controlChar == ControlCharacter.arrowUp) {
            scrollPosition--;
            refresh();
          } else if (key.controlChar == ControlCharacter.pageDown) {
            scrollPosition += (console.windowHeight - 1);
            refresh();
          } else if (key.controlChar == ControlCharacter.pageUp) {
            scrollPosition -= (console.windowHeight - 1);
            refresh();
          } else if (key.controlChar == ControlCharacter.home) {
            scrollPosition = 0;
            refresh();
          } else if (key.controlChar == ControlCharacter.home) {
            scrollPosition = 0;
            refresh();
          } else if (key.controlChar == ControlCharacter.end) {
            scrollPosition = lines.length - (console.windowHeight - 2);
            refresh();
          }
        }
      } finally {
        consoleReader.dispose();
      }
    } finally {
      subscription.cancel();
      console.showCursor();
      console.rawMode = false;
    }
  } finally {
    disassembler.dispose();
  }
}

/// An unfortuante hack to get around console reads locking up the whole thread.
/// 
/// Trying to do [Console.readKey] in the main isolate will prevent the directory
/// watcher from working correctly.
class ConsoleReadIsolate {
  final Stream _readStream;
  final ReceivePort _readPort;
  final SendPort _cmdPort;

  final Isolate isolate;

  ConsoleReadIsolate._(this.isolate, this._readStream, this._readPort, this._cmdPort);

  static Future<ConsoleReadIsolate> init() async {
    final readPort = ReceivePort();

    final isolate = await Isolate.spawn((responsePort) {
      final cmdPort = ReceivePort();
      responsePort.send(cmdPort.sendPort);

      final console = Console();
      cmdPort.listen((message) {
        if (message == 'key') {
          responsePort.send(console.readKey());
        } else {
          throw UnimplementedError();
        }
      });
    }, readPort.sendPort);

    final readStream = readPort.asBroadcastStream();
    final SendPort cmdPort = await readStream.first;

    return ConsoleReadIsolate._(isolate, readStream, readPort, cmdPort);
  }

  Future<Key> readKey() async {
    _cmdPort.send('key');
    return await _readStream.first;
  }

  void dispose() {
    _readPort.close();
    isolate.kill();
  }
}

void _displayError(Console console, String error) {
  console.clearScreen();
  console.resetCursorPosition();
  console.writeErrorLine(error);
}

void _displayDiff(Console console, List<DiffLine> lines, int scrollPosition) {
  final mnemonicDiffPen = AnsiPen()..xterm(12);
  final opDiffPen = AnsiPen()..xterm(3);
  final addPen = AnsiPen()..xterm(10);
  final delPen = AnsiPen()..xterm(9);

  const columnWidth = 55;

  console.resetCursorPosition();

  console.eraseLine();
  console.write('${'TARGET'.padRight(columnWidth)} CURRENT');

  int spaceLeft = console.windowHeight - 1;

  for (final line in lines.skip(scrollPosition).take(console.windowHeight - 1)) {
    spaceLeft--;

    final String targLine;
    final String srcLine;

    if (line.diffType == DiffEditType.equal) {
      final targ = line.target!;
      final src = line.source!;
      if (targ.opStr == src.opStr) {
        targLine =
            '${targ.address.toRadixString(16).padLeft(2)}:    ${targ.mnemonic.padRight(10)} ${targ.opStr}';
        srcLine =
            '  ${src.address.toRadixString(16).padLeft(2)}:    ${src.mnemonic.padRight(10)} ${src.opStr}';
      } else {
        targLine =
            '${opDiffPen('${targ.address.toRadixString(16).padLeft(2)}:')}    ${targ.mnemonic.padRight(10)} ${opDiffPen(targ.opStr)}';
        srcLine =
            '${opDiffPen('o ${src.address.toRadixString(16).padLeft(2)}:')}    ${src.mnemonic.padRight(10)} ${opDiffPen(src.opStr)}';
      }
    } else if (line.diffType == DiffEditType.substitute) {
      final targ = line.target!;
      final src = line.source!;
      targLine = mnemonicDiffPen(
          '${targ.address.toRadixString(16).padLeft(2)}:    ${targ.mnemonic.padRight(10)} ${targ.opStr}');
      srcLine = mnemonicDiffPen(
          '| ${src.address.toRadixString(16).padLeft(2)}:    ${src.mnemonic.padRight(10)} ${src.opStr}');
    } else if (line.diffType == DiffEditType.insert) {
      final src = line.source!;
      targLine = '';
      srcLine = addPen(
          '> ${src.address.toRadixString(16).padLeft(2)}:    ${src.mnemonic.padRight(10)} ${src.opStr}');
    } else if (line.diffType == DiffEditType.delete) {
      final targ = line.target!;
      targLine = delPen(
          '${targ.address.toRadixString(16).padLeft(2)}:    ${targ.mnemonic.padRight(10)} ${targ.opStr}');
      srcLine = delPen('<');
    } else {
      throw UnimplementedError();
    }

    console.writeLine();
    console.eraseLine();
    console.write('${_ansiAwarePadRight(targLine, columnWidth)} $srcLine');
  }

  if (spaceLeft > 0) {
    spaceLeft--;
    console.writeLine();
    console.eraseLine();
    console.write('END');
  }

  while (spaceLeft-- > 0) {
    console.writeLine();
    console.eraseLine();
  }
}

final _ansiSequenceRegex = RegExp(r'\x1B\[[0-9;]+m');

String _ansiAwarePadRight(String str, int width) {
  final stripped = str.replaceAll(_ansiSequenceRegex, '');
  if (stripped.length >= width) {
    return str;
  } else {
    final buffer = StringBuffer(str);
    for (int i = 0; i < (width - stripped.length); i++) {
      buffer.writeCharCode(32);
    }

    return buffer.toString();
  }
}

class DiffLine {
  final DiffEditType diffType;

  /// Target (base exe)
  final Instruction? target;

  /// Source (obj)
  final Instruction? source;

  DiffLine(this.diffType, this.target, this.source);
}

List<DiffLine> _diff(List<Instruction> target, List<Instruction> source) {
  // Diff mnemonics only, we'll diff operands on a same-line basis
  final diffTarget = target.map((i) => i.mnemonic).toList();
  final diffSource = source.map((i) => i.mnemonic).toList();

  // Run diff
  // Note: run diff backwards, we want changes from source (the obj file) to target (the exe file)
  // i swear it's not confusing...
  final result = levenshtein(diffTarget, diffSource);
  final edits = generateLevenshteinEdits(result.item2);

  // Note: target/source in the diff lines represent our original definition of target/source,
  // where target = exe, source = obj. This is backwards from the diff's definition since we're
  // trying to generate a list of changes to go from the base exe to the obj file.
  final lines = <DiffLine>[];

  for (int i = edits.length - 1; i >= 0; i--) {
    final edit = edits[i];

    if (edit.type == DiffEditType.equal ||
        edit.type == DiffEditType.substitute) {
      lines.add(DiffLine(edit.type, target[edit.sourceIndex - 1],
          source[edit.targetIndex! - 1]));
    } else if (edit.type == DiffEditType.insert) {
      lines.add(DiffLine(edit.type, null, source[edit.targetIndex! - 1]));
    } else if (edit.type == DiffEditType.delete) {
      lines.add(DiffLine(edit.type, target[edit.sourceIndex - 1], null));
    } else {
      throw UnimplementedError();
    }
  }

  return lines;
}

List<Instruction> _loadExeInstructions(
    String filePath, int physicalAddress, FunctionDisassembler disassembler) {
  final file = File(filePath).openSync();
  final FileData data;

  try {
    data = FileData.read(file, 0x1000, 950272); // load .text

    try {
      return disassembler.disassembleFunction(data, physicalAddress - 0x1000,
          address: 0x0);
    } finally {
      data.free();
    }
  } finally {
    file.closeSync();
  }
}

List<Instruction> _loadObjInstructions(
    String filePath, String symbolName, FunctionDisassembler disassembler) {
  final symbolNameVariations = [
    symbolName,
    '_$symbolName'
  ]; // why do functions get an underscore in the obj file?
  final bytes = File(filePath).readAsBytesSync();
  final obj = CoffFile.fromList(bytes);

  final int textFileAddress = obj.sections
      .firstWhere((s) => s.header.name == '.text')
      .header
      .pointerToRawData;
  final int symbolValue = obj.symbolTable!.firstWhere((sym) {
    final name =
        sym.name.shortName ?? obj.stringTable!.strings[sym.name.offset]!;
    return symbolNameVariations.contains(name);
  }).value;

  final int funcFileAddress = textFileAddress + symbolValue;

  final objData = FileData.fromList(bytes);

  try {
    return disassembler.disassembleFunction(objData, funcFileAddress,
        address: 0x0);
  } finally {
    objData.free();
  }
}
