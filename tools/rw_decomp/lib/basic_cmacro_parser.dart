/// Iterates lines of a C file while doing very basic parsing of C #if macros.
/// 
/// For each returned line, a boolean will specify whether that line is "skipped"
/// by an #if macro (i.e. it's in a block that didn't meet the #if condition).
/// 
/// Supports #if, #ifdef, #ifndef, #elif, and #else. Only supports conditions
/// that check for the existence of a define (i.e. #if SOME_DEFINE) or simple
/// #if 0/#if 1 conditions. Math expressions are not supported.
Iterable<(int i, String line, bool skipped)> iterateLinesWithCIfMacroContext(
  Iterable<String> lines,
  Set<String> defines
) sync* {
  List<bool> skipStack = [];
  bool skipping = false;

  bool evaluate(String expr) {
    final number = int.tryParse(expr);
    if (number != null) {
      return number != 0;
    }

    return defines.contains(expr);
  }

  String arg(String line, int idx) {
    final parts = line.split(' ');
    if ((idx + 1) < parts.length) {
      return parts[idx + 1];
    } else {
      return '';
    }
  }

  String rest(String line) {
    final spaceIdx = line.indexOf(' ');
    if (spaceIdx < 0) {
      return '';
    } else {
      return line.substring(spaceIdx + 1);
    }
  }

  void push(bool skip) {
    skipStack.add(skipping);
    skipping = skip;
  }

  void pop() {
    skipping = skipStack.removeLast();
  }

  for (final (int i, String line) in lines.indexed) {
    final trimmed = line.trim();

    if (trimmed.startsWith('#if')) {
      push(!evaluate(rest(trimmed)));
    } else if (trimmed.startsWith('#ifdef')) {
      push(!defines.contains(arg(trimmed, 0)));
    } else if (trimmed.startsWith('#ifndef')) {
      push(defines.contains(arg(trimmed, 0)));
    } else if (trimmed.startsWith('#elif')) {
      pop();
      push(!evaluate(rest(trimmed)));
    } else if (trimmed.startsWith('#else')) {
      skipping = !skipping;
    } else if (trimmed.startsWith('#endif')) {
      pop();
    }

    yield (i, line, skipping);
  }
}