// Adapted from: https://github.com/ajmalsiddiqui/levenshtein-diff

import 'dart:math';

import 'package:tuple/tuple.dart';

const _int64Max = 9223372036854775807;

enum DiffEditType {
  /// Items at indexes are equal
  equal,
  /// Delete item at src index
  delete, 
  /// Insert the item at target index at src index
  insert, 
  /// Substitute item at src index with item at target index
  substitute
}

class DiffEdit {
  final DiffEditType type;
  /// 1-based index from source sequence.
  final int sourceIndex;
  /// 1-based index from target sequence.
  final int? targetIndex;

  DiffEdit.delete(this.sourceIndex)
      : type = DiffEditType.delete,
        targetIndex = null;
  DiffEdit.insert(this.sourceIndex, this.targetIndex) : type = DiffEditType.insert;
  DiffEdit.substitute(this.sourceIndex, this.targetIndex) : type = DiffEditType.substitute;
  DiffEdit.equal(this.sourceIndex, this.targetIndex) : type = DiffEditType.equal;

  @override
  String toString() => type.name;
}

/// Returns the Levenshtein distance and distance matrix between [source] and [target].
Tuple2<int, List<List<int>>> levenshtein<T>(List<T> source, List<T> target) {
  int m = source.length;
  int n = target.length;

  final distances = _getDistanceTable(m, n);

  for (int i = 1; i < distances.length; i++) {
    for (int j = 1; j < distances[0].length; j++) {
      if (source[i - 1] == target[j - 1]) {
        distances[i][j] = distances[i - 1][j - 1];
        continue;
      }

      final delete = distances[i - 1][j] + 1;
      final insert = distances[i][j - 1] + 1;
      final substitute = distances[i - 1][j - 1] + 1;

      distances[i][j] = min(min(delete, insert), substitute);
    }
  }

  return Tuple2(distances[m][n], distances);
}

/// Generates a list of edits that, when applied to the source sequence,
/// transform it into the target sequence from a precomputed [distances] matrix.
List<DiffEdit> generateLevenshteinEdits<T>(List<List<int>> distances) {
  int sourceIndex = distances.length - 1;
  int targetIndex = distances[0].length - 1;

  final edits = <DiffEdit>[];

  while (sourceIndex != 0 || targetIndex != 0) {
    final currentItem = distances[sourceIndex][targetIndex];

    final substitute = (sourceIndex > 0 && targetIndex > 0)
        ? distances[sourceIndex - 1][targetIndex - 1]
        : _int64Max;

    final delete = sourceIndex > 0
        ? distances[sourceIndex - 1][targetIndex]
        : _int64Max;
    
    final insert = targetIndex > 0
        ? distances[sourceIndex][targetIndex - 1]
        : _int64Max;
    
    final $min = min(min(insert, delete), substitute);

    if ($min == currentItem) {
      // Items are identical
      edits.add(DiffEdit.equal(sourceIndex, targetIndex));
      sourceIndex--;
      targetIndex--;
    } else if ($min == currentItem - 1) {
      if ($min == insert) {
        edits.add(DiffEdit.insert(sourceIndex, targetIndex));
        targetIndex--;
      } else if ($min == delete) {
        edits.add(DiffEdit.delete(sourceIndex));
        sourceIndex--;
      } else if ($min == substitute) {
        edits.add(DiffEdit.substitute(sourceIndex, targetIndex));
        sourceIndex--;
        targetIndex--;
      } else {
        throw ArgumentError.value(distances, 'distances', 'Invalid distance matrix.');
      }
    } else {
      throw ArgumentError.value(distances, 'distances', 'Invalid distance matrix.');
    }
  }

  return edits;
}

/// Returns a distance matrix of dimensions m+1 * n+1.
///
/// All values are [_int64Max] except for:
/// - First row which is 0..n+1
/// - First column which is 0..m+1
List<List<int>> _getDistanceTable(int m, int n) {
  final distances =
      List<List<int>>.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

  for (int i = 0; i < n + 1; i++) {
    distances[0][i] = i;
  }

  for (int i = 1; i < m + 1; i++) {
    distances[i][0] = i;
  }

  return distances;
}
