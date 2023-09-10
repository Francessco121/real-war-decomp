String unmangle(String name) {
  if (name.startsWith('_?')) {
    // Static declared within a function, return in form of 'staticVarName__function_name'
    final qqIndex = name.indexOf('??');
    final atIndex = name.indexOf('@');
    final atIndex2 = name.indexOf('@', atIndex + 1);

    return '${name.substring(2, atIndex)}__${name.substring(qqIndex + 2, atIndex2)}';
  } else {
    // Other
    if (name.startsWith('__imp__')) {
      name = name.substring(7);
    } else if (name.startsWith('_')) {
      name = name.substring(1);
    }
    final atIndex = name.indexOf('@');
    if (atIndex >= 0) {
      name = name.substring(0, atIndex);
    }
  }

  return name;
}
