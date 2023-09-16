import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:charcode/ascii.dart';

void clearConsoleLine() {
  stdout.writeCharCode(13);
  stdout.write(' ' * stdout.terminalColumns);
  stdout.writeCharCode(13);
}

(int, int) getConsoleCusorPosition() {
  final buf = StringBuffer();

  // Ask terminal for cursor position
  stdout.write('\u001B[6n');

  // Skip to cursor position escape
  while (stdin.readByteSync() != $esc || stdin.readByteSync() != $openBracket) { }

  // Read row
  while (true) {
    final c = stdin.readByteSync();
    if (c == $semicolon) {
      break;
    }

    buf.writeCharCode(c);
  }

  final row = int.parse(buf.toString());
  buf.clear();

  // Read col
  while (true) {
    final c = stdin.readByteSync();
    if (c == $R) {
      break;
    }

    buf.writeCharCode(c);
  }

  final col = int.parse(buf.toString());

  return (row, col);
}

/// Updatable progress indicator for the CLI.
class ConsoleProgress {
  /// Arbitrary label for progress indicator.
  String? label;

  /// Max number of steps. Null for no steps.
  int? steps;
  /// Current step. Null for no steps.
  int? step;

  /// Max value of progress bar. Null for no progress bar.
  int? get barMax => _barMax;
  set barMax(int? value) {
    if (value != null && value <= 0) {
      throw ArgumentError.value(value, 'barMax', 'barMax must be null or greater than zero.');
    }
    if (value == null || (_barValue != null && value <= _barValue!)) {
      _stopwatch.stop();
      stopAutoRender();
    }

    _barMax = value;
  }

  /// Current value of progress bar. Null for no progress bar.
  int? get barValue => _barValue;
  set barValue(int? value) {
    if (value != null && value < 0) {
      throw ArgumentError.value(value, 'barValue', 'barValue must be null or greater than or equal to zero.');
    }
    if (value == null || (_barMax != null && value >= _barMax!)) {
      _stopwatch.stop();
      stopAutoRender();
    }

    _barValue = value;
  }

  /// Whether to show elapsed time and ETA.
  bool timer = false;

  int? _barMax;
  int? _barValue;

  Timer? _autoRenderTimer;
  
  final _stopwatch = Stopwatch();

  void incrementBar() {
    if (_barMax == null || _barValue == null) {
      throw StateError('Cannot increment non-existent progress bar.');
    }

    barValue = min(_barMax!, _barValue! + 1);
    render();
  }

  void incrementStep() {
    if (steps == null || step == null) {
      throw StateError('Cannot increment undefined step counter.');
    }

    step = min(steps!, step! + 1);
    render();
  }

  void startTimer() {
    timer = true;

    _stopwatch.start();
  }

  void restartTimer() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  void stopTimer() {
    _stopwatch.stop();
  }

  void resetTimer() {
    _stopwatch.reset();
  }

  void startAutoRender() {
    render();
    _autoRenderTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) { 
      render();
    });
  }

  void stopAutoRender() {
    _autoRenderTimer?.cancel();
    _autoRenderTimer = null;
  }

  void break$() {
    stopTimer();
    stopAutoRender();
    clearConsoleLine();
  }

  void render() {
    if (!stdout.hasTerminal) {
      return;
    }

    final termColumns = stdout.terminalColumns - 1;

    final progress = (_barMax != null && _barValue != null)
        ? max(0, min(1, _barValue! / _barMax!))
        : null;

    // Left of progress bar
    final leftBuffer = StringBuffer();
    if (label != null) {
      leftBuffer.write(label);
      leftBuffer.writeCharCode($space);
    }

    if (steps != null && step != null) {
      leftBuffer.writeCharCode($openParen);
      leftBuffer.write(step);
      leftBuffer.writeCharCode($slash);
      leftBuffer.write(steps);
      leftBuffer.writeCharCode($closeParen);
      leftBuffer.writeCharCode($space);
    }

    // Right of progress bar
    final rightBuffer = StringBuffer();
    if (progress != null) {
      final maxStr = _barMax.toString();
      rightBuffer.write(_barValue.toString().padLeft(maxStr.length));
      rightBuffer.writeCharCode($slash);
      rightBuffer.write(maxStr);
      rightBuffer.writeCharCode($space);
      final pct = ((_barValue! / _barMax!) * 100);
      if (pct >= 100) {
        rightBuffer.write(' 100');
      } else {
        rightBuffer.write(pct.toStringAsFixed(1).padLeft(4));
      }
      rightBuffer.writeCharCode($percent);
      rightBuffer.writeCharCode($space);
    }

    if (timer && progress != null) {
      rightBuffer.write('ETA ');
      
      final rate = _stopwatch.elapsedMicroseconds / (_barValue! == 0 ? 1 : _barValue!);
      final eta = Duration(microseconds: ((_barMax! - _barValue!) * rate).truncate());
      rightBuffer.write(_durationToString(eta));
      rightBuffer.writeCharCode($space);
    }

    if (timer) {
      rightBuffer.write('ELP ');
      rightBuffer.write(_durationToString(_stopwatch.elapsed));
    }

    // Progress bar
    final barBuffer = StringBuffer();
    final barLength = termColumns - (leftBuffer.length + rightBuffer.length + 3);
    if (progress != null && barLength > 0) {
      barBuffer.writeCharCode($openBracket);
      
      final cols = (progress * barLength).round();
      barBuffer.write('■' * cols);
      barBuffer.write('·' * (barLength - cols));

      barBuffer.writeCharCode($closeBracket);
      barBuffer.writeCharCode($space);
    } else {
      final spaceToFill = termColumns - (leftBuffer.length + rightBuffer.length);
      if (spaceToFill > 0) {
        barBuffer.write(' ' * spaceToFill);
      }
    }

    final lineBuffer = StringBuffer(leftBuffer);
    lineBuffer.write(barBuffer);
    lineBuffer.write(rightBuffer);

    var line = lineBuffer.toString();
    if (line.length > termColumns) {
      line = line.substring(0, termColumns);
    }

    stdout.writeCharCode($cr);
    stdout.write(line);
  }

  String _durationToString(Duration duration) {
    final buffer = StringBuffer();
    if (duration.inHours > 0) {
      buffer.write(duration.inHours.toString().padLeft(2, '0'));
      buffer.writeCharCode($colon);
    }

    final minutes = duration.inMinutes % 60;
    buffer.write(minutes.toString().padLeft(2, '0'));
    buffer.writeCharCode($colon);

    final seconds = duration.inSeconds % 60;
    buffer.write(seconds.toString().padLeft(2, '0'));

    return buffer.toString();
  }
}
