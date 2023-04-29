// See https://github.com/ninja-build/ninja/blob/master/misc/ninja_syntax.py

import 'package:textwrap/textwrap.dart';

class Writer {
  final StringBuffer _output;
  final int _width;

  Writer(StringBuffer output, {int width = 78})
      : _output = output,
        _width = width;

  void newline() {
    _output.write('\n');
  }

  void comment(String text) {
    for (final line in wrap(text,
        width: _width - 2, breakLongWords: false, breakOnHyphens: false)) {
      _output.write('# $line\n');
    }
  }

  void variable(String key, Object? value, {int indent = 0}) {
    if (value == null) {
      return;
    }

    if (value is List) {
      // Filter out empty strings
      value = value.where((e) => e != null).join(' ');
    }

    _line('$key = $value', indent: indent);
  }

  void pool(String name, {required int depth}) {
    _line('pool $name');
    variable('depth', depth, indent: 1);
  }

  void rule(
    String name,
    String command, {
    String? description,
    String? depfile,
    bool generator = false,
    String? pool,
    bool restat = false,
    String? rspfile,
    String? rspfileContent,
    String? deps,
  }) {
    _line('rule $name');
    variable('command', command, indent: 1);

    if (description != null) {
      variable('description', description, indent: 1);
    }
    if (depfile != null) {
      variable('depfile', depfile, indent: 1);
    }
    if (generator) {
      variable('generator', '1', indent: 1);
    }
    if (pool != null) {
      variable('pool', pool, indent: 1);
    }
    if (restat) {
      variable('restat', '1', indent: 1);
    }
    if (rspfile != null) {
      variable('rspfile', rspfile, indent: 1);
    }
    if (rspfileContent != null) {
      variable('rspfile_content', rspfileContent, indent: 1);
    }
    if (deps != null) {
      variable('deps', deps, indent: 1);
    }
  }

  List<String> build(
    dynamic outputs,
    String rule, {
    dynamic inputs,
    dynamic implicit,
    dynamic orderOnly,
    Map<String, Object?>? variables,
    dynamic implicitOutputs,
    String? pool,
    String? dyndep,
  }) {
    final outputsList = _asList(outputs);
    final outOutputs = outputsList.map((x) => _escapePath(x)).toList();
    final allInputs = _asList(inputs).map((x) => _escapePath(x)).toList();

    if (implicit != null) {
      final implicitList = _asList(implicit).map((x) => _escapePath(x));
      allInputs.add('|');
      allInputs.addAll(implicitList);
    }

    if (orderOnly != null) {
      final orderOnlyList = _asList(orderOnly).map((x) => _escapePath(x));
      allInputs.add('||');
      allInputs.addAll(orderOnlyList);
    }

    if (implicitOutputs != null) {
      final implicitOutputsList =
          _asList(implicitOutputs).map((x) => _escapePath(x));
      outOutputs.add('|');
      outOutputs.addAll(implicitOutputsList);
    }

    _line('build ${outOutputs.join(' ')}: ${([rule] + allInputs).join(' ')}');

    if (pool != null) {
      _line('  pool = $pool');
    }
    if (dyndep != null) {
      _line('  dyndep = $dyndep');
    }

    if (variables != null) {
      for (final entry in variables.entries) {
        variable(entry.key, entry.value, indent: 1);
      }
    }

    return outputsList;
  }

  void include(String path) {
    _line('include $path');
  }

  void subninja(String path) {
    _line('subninja $path');
  }

  void $default(/* String | Iterable<String> | null */ dynamic paths) {
    _line('default ${_asList(paths).join(' ')}');
  }

  /// Returns the number of '$' characters right in front of `str[index]`.
  int _countDollarsBeforeIndex(String str, int index) {
    const $ = 36; // '$'

    int dollarCount = 0;
    int dollarIndex = index - 1;
    while (dollarIndex > 0 && str.codeUnitAt(dollarIndex) == $) {
      dollarCount++;
      dollarIndex--;
    }

    return dollarCount;
  }

  /// Writes [text] word-wrapped at [_width] characters.
  void _line(String text, {int indent = 0}) {
    var leadingSpace = '  ' * indent;

    while (leadingSpace.length + text.length > _width) {
      // The text is too width; wrap if possible

      // Find the rightmost space that would obey our width constraint and
      // that's not an escaped space
      final availableSpace = _width - leadingSpace.length - ' \$'.length;
      var space = availableSpace;
      while (true) {
        space = text.substring(0, space).lastIndexOf(' ');
        if (space < 0 || _countDollarsBeforeIndex(text, space) % 2 == 0) {
          break;
        }
      }

      if (space < 0) {
        // No such space; just use the first unescaped space we can find
        space = availableSpace - 1;
        while (true) {
          space = text.indexOf(' ', space + 1);
          if (space < 0 || _countDollarsBeforeIndex(text, space) % 2 == 0) {
            break;
          }
        }
      }

      if (space < 0) {
        // Give up on breaking
        break;
      }

      _output.write('$leadingSpace${text.substring(0, space)} \$\n');
      text = text.substring(space + 1);

      // Subsequent lines are continuations, so indent them
      leadingSpace = '  ' * (indent + 2);
    }

    _output.write('$leadingSpace$text\n');
  }
}

String _escapePath(String word) {
  return word
      .replaceAll('\$ ', '\$\$ ')
      .replaceAll(' ', '\$ ')
      .replaceAll(':', '\$:');
}

List<String> _asList(/*String | Iterable<String> | null*/ dynamic input) {
  if (input == null) {
    return [];
  } else if (input is List<String>) {
    return input;
  } else if (input is Iterable<String>) {
    return input.toList();
  } else if (input is String) {
    return [input];
  } else {
    throw ArgumentError.value(
        input, 'input', 'Input must be a String, List<String>, or null.');
  }
}

/// Escape a string such that it can be embedded into a Ninja file without
/// further interpretation.
String escape(String str) {
  if (str.contains('\n')) {
    throw ArgumentError.value(
        str, 'str', 'Ninja syntax does not allow newlines.');
  }

  // We only have one special metacharacter: '$'
  return str.replaceAll('\$', '\$\$');
}

/// Expand a string containing $vars as Ninja would.
///
/// Note: doesn't handle the full Ninja variable syntax, but it's enough
/// to make configure.py's use of it work.
String expand(String str, Map<String, String> vars,
    [Map<String, String> localVars = const {}]) {
  return str.replaceAllMapped(r'\$(\$|\w*)', (match) {
    final varName = match.group(1);
    if (varName == '\$') {
      return '\$';
    }

    return localVars[varName] ?? vars[varName] ?? '';
  });
}
