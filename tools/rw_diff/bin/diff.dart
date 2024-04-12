import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:dart_console/dart_console.dart';
import 'package:path/path.dart' as p;
import 'package:pe_coff/pe_coff.dart';
import 'package:rw_decomp/diff.dart';
import 'package:rw_decomp/levenshtein.dart';
import 'package:rw_decomp/relocate.dart';
import 'package:rw_decomp/rw_yaml.dart';
import 'package:rw_decomp/symbol_utils.dart';
import 'package:rw_decomp/verify.dart';
import 'package:rw_diff/rw_diff.dart';
import 'package:watcher/watcher.dart';
import 'package:x86_analyzer/functions.dart';

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
  final argParser = ArgParser()
      ..addOption('root');

  final argResult = argParser.parse(args);
  final String projectDir = p.absolute(argResult['root'] ?? p.current);
  
  if (argResult.rest.length != 1) {
    print('Usage: diff.dart <func symbol name>');
    return;
  }

  // Load project config
  final rw = RealWarYaml.load(
      File(p.join(projectDir, 'rw.yaml')).readAsStringSync(),
      dir: projectDir);

  // Figure out symbol address and related obj path
  final String symbolName = argResult.rest[0];
  final int? virtualAddress = rw.symbols[symbolName]?.address;
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

  // Compute physical (file) address of the symbol in the base exe
  final int physicalAddress =
      virtualAddress - (rw.exe.imageBase + rw.exe.textVirtualAddress);

  // Init capstone
  final capstoneDll = ffi.DynamicLibrary.open(p.join(projectDir, 'tools', 'capstone.dll'));
  final disassembler = FunctionDisassembler.init(capstoneDll);

  // Create equality func for diffing instructions
  final diffEquality = InstructionDiffEquality(imageBase: rw.exe.imageBase);

  print('Loading...');

  try {
    // Disassemble base exe function
    final DisassembledFunction exeFunc =
        _loadExeFunction(exeFilePath, symbolName, physicalAddress, virtualAddress, disassembler, rw);

    // Init builder
    final builder = Builder(rw);

    // Init console
    final console = Console();
    _eraseScrollback(console);

    int lastWindowWidth = console.windowWidth;
    int lastWindowHeight = console.windowHeight;

    DisassembledFunction? objFunc;
    List<DiffLine<Instruction>> lines = [];
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
      _displayDiff(console, lines, scrollPosition, exeFunc, objFunc!, symbolName, rw);
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
        await builder.compile(objFilePath);
      } on BuildException catch (ex) {
        _displayError(console, ex.message);
        error = true;
      }

      try {
        if (!error) {
          // Disassemble
          objFunc = _loadObjFunction(objFilePath, symbolName, disassembler,
              virtualAddress, rw);

          // Diff
          lines = runDiff(exeFunc.instructions, objFunc!.instructions, diffEquality);

          // Refresh
          refresh();
        }
      } on LoadException catch (ex) {
        _displayError(console, ex.message);
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
      if (ext != '.c'&& ext != '.cpp' && ext != '.h') {
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

class LoadException implements Exception {
  final String message;

  LoadException(this.message);
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

final _memAddressRegex = RegExp(r'(0x[0-9a-fA-F]{4,})');

String _replaceAddressesWithSymbols(String str, RealWarYaml rw) {
  return str.replaceAllMapped(_memAddressRegex, (match) {
    final raw = match.group(1)!;
    final address = int.parse(raw);

    final sym = rw.symbolsByAddress[address];
    if (sym != null) {
      return sym.name;
    }

    final literalSym = rw.literalSymbolsByAddress[address];
    if (literalSym != null) {
      return literalSym.displayName;
    }

    return raw;
  });
}

void _displayDiff(Console console, List<DiffLine<Instruction>> lines, int scrollPosition,
    DisassembledFunction targetFunc, DisassembledFunction srcFunc,
    String symbolName, RealWarYaml rw) {
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

  // Assign color to each unique branch
  final targetBranchColors = <int, AnsiPen>{};
  final sourceBranchColors = <int, AnsiPen>{};
  (targetFunc.branchTargets.toList()..sort()).forEachIndexed((i, addr) {
    targetBranchColors[addr] = branchPens[i % branchPens.length];
  });
  (srcFunc.branchTargets.toList()..sort()).forEachIndexed((i, addr) {
    sourceBranchColors[addr] = branchPens[i % branchPens.length];
  });

  // Determine exact differences
  int differenceCount = 0;
  final linesWithDifferences = lines
      .map((l) {
        final diffType = _determineDifference(l, rw);
        if (diffType != DifferenceType.none) {
          differenceCount++;
        }

        return (l, diffType);
      })
      .toList();

  console.resetCursorPosition();

  console.eraseLine();
  console.write('${'TARGET'.padRight(targColumnWidth)}   CURRENT');

  int spaceLeft = console.windowHeight - 2;
  final visibleLines =
      linesWithDifferences.skip(scrollPosition).take(console.windowHeight - 2);

  for (final (line, diffType) in visibleLines) {
    spaceLeft--;

    // this is an abomination
    final targInBranchPen =
        line.target != null ? targetBranchColors[line.target!.address] : null;
    final srcInBranchPen =
        line.source != null ? sourceBranchColors[line.source!.address] : null;

    final targInBranch = targInBranchPen != null ? targInBranchPen('~>') : '  ';
    final srcInBranch = srcInBranchPen != null ? srcInBranchPen('~>') : '  ';

    final targOutBranchPen = (line.target != null && line.target!.isRelativeJump)
        ? targetBranchColors[line.target!.operands[0].imm!]
        : null;
    final srcOutBranchPen = (line.source != null && line.source!.isRelativeJump)
        ? sourceBranchColors[line.source!.operands[0].imm!]
        : null;

    final targOutBranch =
        targOutBranchPen != null ? targOutBranchPen(' ~>') : '';
    final srcOutBranch = srcOutBranchPen != null ? srcOutBranchPen(' ~>') : '';

    final Instruction? targ = line.target;
    final AnsiPen? targAddressColor;
    final AnsiPen? targMnemonicColor;
    final AnsiPen? targOpColor;

    final Instruction? src = line.source;
    final String srcSymbol;
    final AnsiPen? srcAddressColor;
    final AnsiPen? srcMnemonicColor;
    final AnsiPen? srcOpColor;
    final AnsiPen? srcSymbolColor;

    switch (diffType) {
      case DifferenceType.none:
        targAddressColor = null;
        targMnemonicColor = null;
        targOpColor = null;
        srcSymbol = ' ';
        srcAddressColor = null;
        srcMnemonicColor = null;
        srcOpColor = null;
        srcSymbolColor = null;
      case DifferenceType.bytes:
        targAddressColor = byteDiffPen;
        targMnemonicColor = byteDiffPen;
        targOpColor = byteDiffPen;
        srcSymbol = 'b';
        srcAddressColor = byteDiffPen;
        srcMnemonicColor = byteDiffPen;
        srcOpColor = byteDiffPen;
        srcSymbolColor = byteDiffPen;
      case DifferenceType.mnemonic:
        targAddressColor = mnemonicDiffPen;
        targMnemonicColor = mnemonicDiffPen;
        targOpColor = mnemonicDiffPen;
        srcSymbol = '|';
        srcAddressColor = mnemonicDiffPen;
        srcMnemonicColor = mnemonicDiffPen;
        srcOpColor = mnemonicDiffPen;
        srcSymbolColor = mnemonicDiffPen;
      case DifferenceType.operands:
        targAddressColor = opDiffPen;
        targMnemonicColor = null;
        targOpColor = opDiffPen;
        srcSymbol = 'o';
        srcAddressColor = opDiffPen;
        srcMnemonicColor = null;
        srcOpColor = opDiffPen;
        srcSymbolColor = opDiffPen;
      case DifferenceType.insertion:
        targAddressColor = null;
        targMnemonicColor = null;
        targOpColor = null;
        srcSymbol = '>';
        srcAddressColor = addPen;
        srcMnemonicColor = addPen;
        srcOpColor = addPen;
        srcSymbolColor = addPen;
      case DifferenceType.deletion:
        targAddressColor = delPen;
        targMnemonicColor = delPen;
        targOpColor = delPen;
        srcSymbol = '<';
        srcAddressColor = null;
        srcMnemonicColor = null;
        srcOpColor = null;
        srcSymbolColor = delPen;
    }

    // Replace addresses with symbol names where possible
    var targOp = targ == null ? null : _replaceAddressesWithSymbols(targ.opStr, rw);
    var srcOp = src == null ? null : _replaceAddressesWithSymbols(src.opStr, rw);

    // Only color differing operands when that's the main difference
    List<OperandDiff>? targOpColors;
    List<OperandDiff>? srcOpColors;
    if (targ != null && src != null && diffType == DifferenceType.operands) {
      final targOps = targOp!.split(',');
      final srcOps = srcOp!.split(',');

      targOpColors = [];
      srcOpColors = [];

      for (int i = 0; i < targOps.length; i++) {
        final t = targOps[i];
        final s = srcOps[i];
        final equal = t == s;

        targOpColors.add(OperandDiff(t, equal));
        srcOpColors.add(OperandDiff(s, equal));
      }
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
      if (targOpColors == null || targOpColor == null) {
        targBuffer.write(targOpColor == null ? targOp! : targOpColor(targOp!));
      } else {
        for (int i = 0; i < targOpColors.length; i++) {
          final opColor = targOpColors[i];
          if (i > 0) {
            targBuffer.write(',');
          }
          targBuffer.write(opColor.equal ? opColor.operand : targOpColor(opColor.operand));
        }
      }
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
      if (srcOpColors == null || srcOpColor == null) {
        srcBuffer.write(srcOpColor == null ? srcOp! : srcOpColor(srcOp!));
      } else {
        for (int i = 0; i < srcOpColors.length; i++) {
          final opColor = srcOpColors[i];
          if (i > 0) {
            srcBuffer.write(',');
          }
          srcBuffer.write(opColor.equal ? opColor.operand : srcOpColor(opColor.operand));
        }
      }
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

DifferenceType _determineDifference(DiffLine<Instruction> line, RealWarYaml rw) {
  final targ = line.target;
  final src = line.source;
  
  switch (line.diffType) {
    case DiffEditType.equal:
      // Compare exact bytes with the exception of literal references
      if (targ == src || doInstructionsMatchViaLiteralSymbol(rw, targ!, src!)) {
        return DifferenceType.none;
      } else if (targ.opStr != src.opStr) {
        // Diff considered lines equal but the operands are not exactly equal
        return DifferenceType.operands;
      } else {
        // Shouldn't happen, but if it does it needs to be obvious
        return DifferenceType.bytes;
      }
    case DiffEditType.substitute:
      if (targ!.mnemonic != src!.mnemonic) {
        return DifferenceType.mnemonic;
      } else if (doInstructionsMatchViaLiteralSymbol(rw, targ, src)) {
        // Instructions only differ by a literal reference for the same literal value
        return DifferenceType.none;
      } else {
        return DifferenceType.operands;
      }
    case DiffEditType.insert:
      return DifferenceType.insertion;
    case DiffEditType.delete:
      return DifferenceType.deletion;
  }
}

enum DifferenceType {
  none,
  bytes,
  operands,
  mnemonic,
  insertion,
  deletion
}

class OperandDiff {
  final String operand;
  final bool equal;

  OperandDiff(this.operand, this.equal);
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

DisassembledFunction _loadExeFunction(String filePath, String symbolName, int physicalAddress, 
    int virtualAddress, FunctionDisassembler disassembler, RealWarYaml rw) {
  final file = File(filePath).openSync();
  final FileData data;

  try {
    // load .text
    data = FileData.read(file, rw.exe.textFileOffset, rw.exe.textPhysicalSize);

    try {
      return disassembler.disassembleFunction(data, physicalAddress,
          address: virtualAddress, name: symbolName);
    } finally {
      data.free();
    }
  } finally {
    file.closeSync();
  }
}

DisassembledFunction _loadObjFunction(
    String filePath, String symbolName, FunctionDisassembler disassembler, 
    int virtualAddress, RealWarYaml rw) {
  final bytes = File(filePath).readAsBytesSync();
  final obj = CoffFile.fromList(bytes);

  final SymbolTableEntry? symbol = obj.symbolTable!.values.firstWhereOrNull((sym) {
    final name =
        sym.name.shortName ?? obj.stringTable!.strings[sym.name.offset]!;
    return symbolName == unmangle(name);
  });

  if (symbol == null) {
    throw LoadException('Could not find symbol \'$symbolName\' in $filePath');
  }

  // Relocate function .text COMDAT section
  final section = obj.sections[symbol.sectionNumber - 1];
  final filePtr = section.header.pointerToRawData;
  final funcSize = section.header.sizeOfRawData;
  final sectionBytes = Uint8List.sublistView(bytes, filePtr, filePtr + funcSize);

  try {
    relocateSection(obj, section, 
        sectionBytes, 
        targetVirtualAddress: virtualAddress, 
        symbolLookup: (sym) => rw.lookupSymbol(unmangle(sym)));
  } on RelocationException catch (ex) {
    throw LoadException(ex.message);
  }

  // Disassemble
  final objData = FileData.fromList(sectionBytes);

  try {
    return disassembler.disassembleFunction(objData, 0,
        address: virtualAddress, 
        name: symbolName,
        endAddressHint: virtualAddress + funcSize);
  } finally {
    objData.free();
  }
}
