import 'dart:io';

/// For each string symbol given separated by spaces, unmangles them, and prints them on separate lines.
void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: unmangle_string_symbol string...');
    exit(1);
  }

  print('${'Length'.padRight(8)} ${'Hash'.padRight(12)} String (first 32 chars)');
  for (final mangled in args) {
    final unmangled = _unmangle(mangled);
    if (unmangled != null) {
      print('${unmangled.length.toString().padRight(8)} ${unmangled.hash.toString().padRight(12)} ${unmangled.stringStart}');
    } else {
      print('${'Failed To Unmangle:'.padRight(8+12)} ${mangled}');
    }
  }
}

final _0 = '0'.codeUnitAt(0);
final _1 = '1'.codeUnitAt(0);
final _9 = '9'.codeUnitAt(0);
final _A = 'A'.codeUnitAt(0);
final _a = 'a'.codeUnitAt(0);
final _P = 'P'.codeUnitAt(0);
final _p = 'p'.codeUnitAt(0);
final _questionMark = '?'.codeUnitAt(0);
final _dollar = '\$'.codeUnitAt(0);

final _specialChars = [
  ','.codeUnitAt(0),
  '/'.codeUnitAt(0),
  '\\'.codeUnitAt(0),
  ':'.codeUnitAt(0),
  '.'.codeUnitAt(0),
  ' '.codeUnitAt(0),
  '\x0B'.codeUnitAt(0),
  '\n'.codeUnitAt(0),
  '\''.codeUnitAt(0),
  '-'.codeUnitAt(0),
  '"'.codeUnitAt(0),
];

class UnmangledString {
  /// Byte length of the full actual string.
  final int length;
  /// Hash of the string.
  final int hash;
  /// Up to the first 32 characters of the string.
  final String stringStart;

  UnmangledString(this.length, this.hash, this.stringStart);
}

// ??_C@_0L@IGEA@modlog?4txt?$AA@
// ??_C@_01LLF@w?$AA@
// ??_C@_0BL@BIFP@Failed?5to?5open?5modlog?4txt?4?$AA@
// ??_C@_05ONAE@?$FL?$CFx?$FN?5?$AA@
// ??_C@_0BN@PPGJ@Log?5print?5buffer?5overflow?5?3?$CI?$AA@
UnmangledString? _unmangle(String mangled) {
  int decodeHexString(String str) {
    final buffer = StringBuffer();
    for (final char in str.codeUnits) {
      final hexDigit = char - _A;
      if (hexDigit < 10) {
        buffer.writeCharCode(hexDigit + _0);
      } else {
        buffer.writeCharCode((hexDigit - 10) + _A);
      }
    }

    return int.parse(buffer.toString(), radix: 16);
  }

  // Check for string constant prefix
  final prefixIndex = mangled.indexOf('_C@_');
  if (prefixIndex < 0 || mangled.length < (prefixIndex + 6)) {
    // Not a mangled string symbol
    return null;
  }

  final chars = mangled.codeUnits;

  // Check whether the string is UTF-8 or UTF-16BE
  final isUtf16 = chars[prefixIndex + 4] == _1;
  if (isUtf16) {
    throw UnimplementedError('UTF-16BE string demangling is not implemented.');
  }

  // Parse string byte length
  final lengthIndex = prefixIndex + 5;
  final int length;
  final int hashIndex;

  if (chars[lengthIndex] >= _0 && chars[lengthIndex] <= _9) {
    // Length given as just a direct single digit
    length = (chars[lengthIndex] - _0) + 1;
    hashIndex = lengthIndex + 1;
  } else {
    // Length as encoded number
    hashIndex = mangled.indexOf('@', lengthIndex) + 1;
    if (hashIndex < 0) {
      return null;
    }
    length = decodeHexString(mangled.substring(lengthIndex, hashIndex - 1));
  }

  if (mangled.length < (hashIndex + 1)) {
    return null;
  }

  // Parse string hash
  final bytesIndex = mangled.indexOf('@', hashIndex) + 1;
  if (bytesIndex < 0) {
    return null;
  }

  final hash = decodeHexString(mangled.substring(hashIndex, bytesIndex - 1));

  // Parse string first 32 characters
  final bytesEndIndex = mangled.indexOf('@', bytesIndex);
  if (bytesEndIndex < 0) {
    return null;
  }

  final buffer = StringBuffer();
  int index = bytesIndex;
  while (index < bytesEndIndex) {
    if (chars[index] == _questionMark) {
      if (chars[index + 1] == _dollar) {
        // ?$xx
        buffer.writeCharCode(decodeHexString(mangled.substring(index + 2, index + 4)));
        index += 4;
      } else if (chars[index + 1] >= _0 && chars[index + 1] <= _9) {
        // ?0-9
        buffer.writeCharCode(_specialChars[chars[index + 1] - _0]);
        index += 2;
      } else {
        if ((chars[index + 1] >= _A && chars[index + 1] <= _P)
          || (chars[index + 1] >= _a && chars[index + 1] <= _p)) {
          // ?A-P or ?a-p
          buffer.writeCharCode(chars[index + 1] + 0x80);
          index += 2;
        } else {
          // ?
          buffer.writeCharCode(chars[index]);
          index++;
        }
      }
    } else {
      // Actual character
      buffer.writeCharCode(chars[index]);
      index++;
    }
  }

  return UnmangledString(length, hash, buffer.toString());
}
