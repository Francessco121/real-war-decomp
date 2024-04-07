/// Finds the start and end of a top-level YAML list.
(int, int) findYamlList(List<String> lines, String name) {
  final prefix = '$name:';
  final start = lines.indexWhere((l) => l.startsWith(prefix));
  var end = lines.indexWhere((l) {
    if (l.startsWith('  ')) {
      return false;
    }

    final trimmed = l.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      return false;
    }

    return true;
  }, start + 1);

  if (end < 0) {
    end = lines.length;
  }

  return (start, end);
}

/// Finds an appropriate index to insert the [targetValue] into a YAML list in [lines]
/// by following the existing sort order of the list.
/// 
/// The [targetValue] will be compared to the value of each line parsed by [getLineValue]
/// through the given [comparator].
/// 
/// The given [lines] must contain a pre-sorted YAML list.
(int, bool) findSortedInsertOrUpdateIndex<T>(List<String> lines, {
  int startOffset = 0, 
  required Comparator<T> comparator,
  required T Function(String line) getLineValue,
  required T targetValue,
  bool Function(T value)? shouldContinue,
}) {
  int i = startOffset;
  int insertIdx = i;
  bool alreadyExists = false;

  while (i < lines.length) {
    i += 1;

    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final value = getLineValue(line);
    final comparison = comparator(value, targetValue);
    if (comparison < 0) {
      insertIdx = i;
    } else if (comparison == 0) {
      alreadyExists = true;
      insertIdx = i;
      break;
    } else {
      break;
    }

    if (shouldContinue != null && !shouldContinue(value)) {
      break;
    }
  }

  return (insertIdx, alreadyExists);
}
