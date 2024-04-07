String unmangle(String name) {
  // Leave compiler-generated symbols alone
  if (name.startsWith('__real@') || name.startsWith('??_C@')) {
    return name;
  }

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
    } else if (name.startsWith('_')) { // cdecl/stdcall prefix
      name = name.substring(1);
    } else if (name.startsWith('@')) { // fastcall prefix
      name = name.substring(1);
    }
    final atIndex = name.indexOf('@'); // stdcall/fastcall suffix
    if (atIndex >= 0) {
      name = name.substring(0, atIndex);
    }
  }

  return name;
}
