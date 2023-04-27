import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:ansicolor/ansicolor.dart';
import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dart_console/dart_console.dart';
import 'package:diff/build.dart';
import 'package:diff/diff.dart';
import 'package:diff/relocate.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe_coff.dart';
import 'package:rw_analyzer/functions.dart';
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
  final RealWarYamlSegment? segment = rw.findSegmentOfAddress(virtualAddress);
  final String? objPath = segment?.name;
  if (segment == null || objPath == null) {
    print('Symbol not mapped to an object file: $symbolName');
    return;
  }

  // Compute paths
  final String exeFilePath = p.join(projectDir, rw.config.exePath);
  final String objFilePath =
      p.join(projectDir, rw.config.buildDir, 'obj', '$objPath.obj');
  final String srcDirPath = p.join(projectDir, rw.config.srcDir);
  final String incDirPath = p.join(projectDir, rw.config.includeDir);
  final String cFilePath = p.join(srcDirPath, '$objPath.c');

  // Compute physical (file) address of the symbol in the base exe
  final int physicalAddress =
      virtualAddress - (rw.exe.imageBase + rw.exe.textVirtualAddress);

  // Init capstone
  final capstoneDll = ffi.DynamicLibrary.open('../capstone.dll');
  final disassembler = FunctionDisassembler.init(capstoneDll);

  print('Loading...');

  try {
    // Disassemble base exe function
    final DisassembledFunction exeFunc =
        _loadExeFunction(exeFilePath, physicalAddress, virtualAddress, disassembler, rw);

    // Build config
    final builder = Builder(rw);

    // Init console
    final console = Console();
    _eraseScrollback(console);

    int lastWindowWidth = console.windowWidth;
    int lastWindowHeight = console.windowHeight;

    DisassembledFunction? objFunc;
    List<DiffLine> lines = [];
    int scrollPosition = 0;

    bool refreshing = false;
    bool waitingForRefresh = false;
    Completer<void>? refreshCompleter;

    void refresh() {
      // Resizing the window can cause the scrollback to build up, which is kinda jank
      if (lastWindowWidth != console.windowWidth || 
          lastWindowHeight != console.windowHeight) {
        _eraseScrollback(console);
        lastWindowWidth = console.windowWidth;
        lastWindowHeight = console.windowHeight;
      }
      
      // Clamp scroll position
      scrollPosition = max(min(scrollPosition, lines.length - 1), 0);

      // Update screen
      _displayDiff(console, lines, scrollPosition, exeFunc, objFunc!, symbolName);
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

      console.cursorPosition =
          Coordinate(0, console.windowWidth - 'Compiling...'.length);
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
        objFunc = _loadObjFunction(objFilePath, symbolName, disassembler,
            virtualAddress, rw, segment.address);

        // Diff
        lines = _diff(exeFunc.instructions, objFunc!.instructions);

        // Refresh
        refresh();
      }

      refreshing = false;
      refreshCompleter!.complete();
    }

    // Listen for src directory changes
    final srcWatcher = DirectoryWatcher(srcDirPath.replaceAll('/', '\\'));
    final incWatcher = DirectoryWatcher(incDirPath.replaceAll('/', '\\'));
    final watcherSubscription =
        StreamGroup.merge([srcWatcher.events, incWatcher.events])
            .listen((event) {
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
          if (key.char == 'q' || 
              key.controlChar == ControlCharacter.ctrlC || 
              key.controlChar == ControlCharacter.escape) {
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
          } else if (key.controlChar == ControlCharacter.ctrlR) {
            refresh();
          }
        }
      } finally {
        consoleReader.dispose();
      }
    } finally {
      watcherSubscription.cancel();
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

  ConsoleReadIsolate._(
      this.isolate, this._readStream, this._readPort, this._cmdPort);

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

void _eraseScrollback(Console console) {
  console.write('\x1b[3J');
}

void _displayError(Console console, String error) {
  console.clearScreen();
  console.resetCursorPosition();
  console.writeErrorLine(error);
}

void _displayDiff(Console console, List<DiffLine> lines, int scrollPosition,
    DisassembledFunction targetFunc, DisassembledFunction srcFunc,
    String symbolName) {
  final bottomBarPen = AnsiPen()..white()..gray(level: 0.1, bg: true);
  final bottomDiffPen = AnsiPen()..black()..xterm(3, bg: true);
  final bottomOkPen = AnsiPen()..black()..xterm(10, bg: true);

  final mnemonicDiffPen = AnsiPen()..xterm(12);
  final opDiffPen = AnsiPen()..xterm(3);
  final byteDiffPen = AnsiPen()..xterm(13);
  final addPen = AnsiPen()..xterm(10);
  final delPen = AnsiPen()..xterm(9);
  final branchPens = [
    AnsiPen()..xterm(14), // cyan
    AnsiPen()..xterm(200), // purple
    AnsiPen()..xterm(33), // blue
    AnsiPen()..xterm(46), // green
    AnsiPen()..xterm(226), // yellow
    AnsiPen()..xterm(9), // red
  ];

  //const columnWidth = 58;
  final targColumnWidth = (console.windowWidth ~/ 2) - 1;
  final srcColumnWidth = (console.windowWidth - targColumnWidth) - 1;

  final differenceCount = lines.fold(0, (sum, l) {
    if (l.diffType != DiffEditType.equal) {
      return sum + 1;
    } else {
      return l.source == l.target ? sum : (sum + 1);
    }
  });

  // Assign color to each unique branch
  final targetBranchColors = <int, AnsiPen>{};
  final sourceBranchColors = <int, AnsiPen>{};
  targetFunc.branchTargets.forEachIndexed((i, addr) {
    targetBranchColors[addr] = branchPens[i % branchPens.length];
  });
  srcFunc.branchTargets.forEachIndexed((i, addr) {
    sourceBranchColors[addr] = branchPens[i % branchPens.length];
  });

  console.resetCursorPosition();

  console.eraseLine();
  console.write('${'TARGET'.padRight(targColumnWidth)}   CURRENT');

  int spaceLeft = console.windowHeight - 2;
  final visibleLines =
      lines.skip(scrollPosition).take(console.windowHeight - 2);

  for (final line in visibleLines) {
    spaceLeft--;

    // this is an abomination
    final targInBranchPen =
        line.target != null ? targetBranchColors[line.target!.address] : null;
    final srcInBranchPen =
        line.source != null ? sourceBranchColors[line.source!.address] : null;

    final targInBranch = targInBranchPen != null ? targInBranchPen('~>') : '  ';
    final srcInBranch = srcInBranchPen != null ? srcInBranchPen('~>') : '  ';

    final targOutBranchPen = (line.target != null && line.target!.isLocalBranch)
        ? targetBranchColors[line.target!.operands[0].imm!]
        : null;
    final srcOutBranchPen = (line.source != null && line.source!.isLocalBranch)
        ? sourceBranchColors[line.source!.operands[0].imm!]
        : null;

    final targOutBranch =
        targOutBranchPen != null ? targOutBranchPen(' ~>') : '';
    final srcOutBranch = srcOutBranchPen != null ? srcOutBranchPen(' ~>') : '';

    final Instruction? targ;
    final AnsiPen? targAddressColor;
    final AnsiPen? targMnemonicColor;
    final AnsiPen? targOpColor;

    final Instruction? src;
    final String srcSymbol;
    final AnsiPen? srcAddressColor;
    final AnsiPen? srcMnemonicColor;
    final AnsiPen? srcOpColor;
    final AnsiPen? srcSymbolColor;

    if (line.diffType == DiffEditType.equal) {
      targ = line.target!;
      src = line.source!;
      if (targ.opStr == src.opStr) {
        // compare exact bytes to be sure
        if (targ == src) {
          targAddressColor = null;
          targMnemonicColor = null;
          targOpColor = null;
          srcSymbol = ' ';
          srcAddressColor = null;
          srcMnemonicColor = null;
          srcOpColor = null;
          srcSymbolColor = null;
        } else {
          // Shouldn't happen, but if it does it needs to be obvious
          targAddressColor = byteDiffPen;
          targMnemonicColor = byteDiffPen;
          targOpColor = byteDiffPen;
          srcSymbol = 'b';
          srcAddressColor = byteDiffPen;
          srcMnemonicColor = byteDiffPen;
          srcOpColor = byteDiffPen;
          srcSymbolColor = byteDiffPen;
        }
      } else {
        targAddressColor = opDiffPen;
        targMnemonicColor = null;
        targOpColor = opDiffPen;
        srcSymbol = 'o';
        srcAddressColor = opDiffPen;
        srcMnemonicColor = null;
        srcOpColor = opDiffPen;
        srcSymbolColor = opDiffPen;
      }
    } else if (line.diffType == DiffEditType.substitute) {
      targ = line.target!;
      src = line.source!;

      targAddressColor = mnemonicDiffPen;
      targMnemonicColor = mnemonicDiffPen;
      targOpColor = mnemonicDiffPen;
      srcSymbol = '|';
      srcAddressColor = mnemonicDiffPen;
      srcMnemonicColor = mnemonicDiffPen;
      srcOpColor = mnemonicDiffPen;
      srcSymbolColor = mnemonicDiffPen;
    } else if (line.diffType == DiffEditType.insert) {
      targ = null;
      src = line.source!;

      targAddressColor = null;
      targMnemonicColor = null;
      targOpColor = null;
      srcSymbol = '>';
      srcAddressColor = addPen;
      srcMnemonicColor = addPen;
      srcOpColor = addPen;
      srcSymbolColor = addPen;
    } else if (line.diffType == DiffEditType.delete) {
      targ = line.target!;
      src = null;

      targAddressColor = delPen;
      targMnemonicColor = delPen;
      targOpColor = delPen;
      srcSymbol = '<';
      srcAddressColor = null;
      srcMnemonicColor = null;
      srcOpColor = null;
      srcSymbolColor = delPen;
    } else {
      throw UnimplementedError();
    }

    final targBuffer = StringBuffer();
    if (targ != null) {
      final addr = '${targ.address.toRadixString(16).padLeft(2)}: ';
      final mnemonic = targ.mnemonic.padRight(10);
      targBuffer.write(targAddressColor == null ? addr : targAddressColor(addr));
      targBuffer.write(targInBranch);
      targBuffer.write(' ');
      targBuffer.write(targMnemonicColor == null ? mnemonic : targMnemonicColor(mnemonic));
      targBuffer.write(' ');
      targBuffer.write(targOpColor == null ? targ.opStr : targOpColor(targ.opStr));
      targBuffer.write(targOutBranch);
    }

    final srcBuffer = StringBuffer();
    if (src != null) {
      final addr = '${src.address.toRadixString(16).padLeft(2)}: ';
      final mnemonic = src.mnemonic.padRight(10);
      srcBuffer.write(srcSymbolColor == null ? srcSymbol : srcSymbolColor(srcSymbol));
      srcBuffer.write(' ');
      srcBuffer.write(srcAddressColor == null ? addr : srcAddressColor(addr));
      srcBuffer.write(srcInBranch);
      srcBuffer.write(' ');
      srcBuffer.write(srcMnemonicColor == null ? mnemonic : srcMnemonicColor(mnemonic));
      srcBuffer.write(' ');
      srcBuffer.write(srcOpColor == null ? src.opStr : srcOpColor(src.opStr));
      srcBuffer.write(srcOutBranch);
    } else {
      srcBuffer.write(srcSymbolColor == null ? srcSymbol : srcSymbolColor(srcSymbol));
    }

    console.writeLine();
    console.eraseLine();

    String targCol = _ansiAwarePadRight(targBuffer.toString(), targColumnWidth);
    String srcCol = srcBuffer.toString();
    if (targCol.length > targColumnWidth) {
      targCol = _ansiAwareCropRight(targCol, targColumnWidth);
    }
    if (srcCol.length > srcColumnWidth) {
      srcCol = _ansiAwareCropRight(srcCol, srcColumnWidth);
    }
    console.write('$targCol $srcCol');
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

  // Draw bottom bar
  console.writeLine();
  final diffText = differenceCount == 0 
      ? bottomOkPen(' OK ') 
      : bottomDiffPen(' DIFF: $differenceCount ');
  final lineNumText = bottomBarPen('${scrollPosition + 1}-${scrollPosition + visibleLines.length}/${lines.length}');
  final diffTextLen = diffText.displayWidth;
  final lineNumTextLen = lineNumText.displayWidth;
  console.write(lineNumText);
  var nameStartIndex = (console.windowWidth ~/ 2) - (symbolName.length ~/ 2);
  var nameEndIndex = nameStartIndex + symbolName.length;
  if (nameStartIndex < (lineNumTextLen + 1) || 
      nameEndIndex > (console.windowWidth - diffTextLen - 1)) {
    symbolName = '...';
    nameStartIndex = (console.windowWidth ~/ 2) - 1;
    nameEndIndex = nameStartIndex + 3;
  }
  console.write(bottomBarPen(''.padRight(nameStartIndex - lineNumTextLen)));
  console.write(bottomBarPen(symbolName));
  console.write(bottomBarPen(''.padRight(console.windowWidth - nameEndIndex - diffTextLen)));
  console.write(diffText);
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

final _ansiEscapeChar = '\x1B'.codeUnitAt(0);
final _mChar = 'm'.codeUnitAt(0);

String _ansiAwareCropRight(String str, int width) {
  if (str.displayWidth <= width) {
    return str;
  }

  final buffer = StringBuffer();
  final units = str.codeUnits;
  
  int i = 0;
  int displayWidth = 0;
  while (displayWidth < (width - 1) && i < units.length) {
    if (units[i] == _ansiEscapeChar) {
      final ansiEscapeEnd = units.indexOf(_mChar, i + 1);
      for (int j = i; j <= ansiEscapeEnd; j++) {
        buffer.writeCharCode(units[j]);
      }
      i += ((ansiEscapeEnd + 1) - i);
    } else {
      buffer.writeCharCode(units[i]);
      i++;
      displayWidth++;
    }
  }

  buffer.write(ansiDefault);
  buffer.write('█');

  return buffer.toString();
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

DisassembledFunction _loadExeFunction(String filePath, int physicalAddress, int virtualAddress,
    FunctionDisassembler disassembler, RealWarYaml rw) {
  final file = File(filePath).openSync();
  final FileData data;

  try {
    // load .text
    data = FileData.read(file, rw.exe.textFileOffset, rw.exe.textPhysicalSize);

    try {
      return disassembler.disassembleFunction(data, physicalAddress,
          address: virtualAddress);
    } finally {
      data.free();
    }
  } finally {
    file.closeSync();
  }
}

DisassembledFunction _loadObjFunction(
    String filePath, String symbolName, FunctionDisassembler disassembler, 
    int virtualAddress,
    RealWarYaml rw, int segmentVirtualAddress) {
  final symbolNameVariations = [
    symbolName,
    '_$symbolName'
  ]; // why do functions get an underscore in the obj file?
  final bytes = File(filePath).readAsBytesSync();
  final obj = CoffFile.fromList(bytes);

  final SymbolTableEntry symbol = obj.symbolTable!.values.firstWhere((sym) {
    final name =
        sym.name.shortName ?? obj.stringTable!.strings[sym.name.offset]!;
    return symbolNameVariations.contains(name);
  });
  // NOTE: Functions may be compiled as COMDATs, so there's possibly more than one .text section.
  // The symbol specifies which section exactly and a relative offset within it.
  final int textFileAddress =
      obj.sections[symbol.sectionNumber - 1].header.pointerToRawData;

  final int funcFileAddress = textFileAddress + symbol.value;

  // Apply relocations
  relocateObject(bytes, obj, rw, segmentVirtualAddress);

  final objData = FileData.fromList(bytes);

  try {
    return disassembler.disassembleFunction(objData, funcFileAddress,
        address: virtualAddress);
  } finally {
    objData.free();
  }
}
