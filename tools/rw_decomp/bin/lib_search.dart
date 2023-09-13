import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:pe_coff/lib.dart';

/// Searches for a symbol in a Windows .lib archive file and returns 
/// the member name, index, and offset that defines it.
void main(List<String> args) {
  if (args.length < 2) {
    print('usage: lib_search.dart <path/to/libfile> <symbols...>');
    exit(1);
  }

  final file = File(args[0]);
  final lib = ArchiveFile.fromList(file.readAsBytesSync());

  print('${'Symbol'.padRight(12)} ${'Defined In'.padRight(38)} ${'@ Idx'.padRight(6)} @ Offset');

  for (final symbol in args.skip(1)) {
    final int? memberOffset;
    if (lib.secondLinkerMember != null) {
      // Use second linker member if available since we can do a fast binary search on it
      final lm = lib.secondLinkerMember!;
      final symIdx = binarySearch(lm.stringTable, symbol);
      if (symIdx < 0) {
        memberOffset = null;
      } else {
        final offIdx = lm.indices[symIdx] - 1;
        memberOffset = lm.offsets[offIdx];
      }
    } else if (lib.firstLinkerMember != null) {
      final lm = lib.firstLinkerMember!;
      final symIdx = lm.stringTable.indexOf(symbol);
      if (symIdx < 0) {
        memberOffset = null;
      } else {
        memberOffset = lm.offsets[symIdx];
      }
    } else {
      print('Archive does not contain a symbol table. Cannot perform lookup.');
      exit(-1);
    }

    if (memberOffset == null) {
      print('${symbol.substring(0, min(symbol.length, 12))} <not found>');
      continue;
    }

    final memberIdx = lib.memberIndices[memberOffset]!;
    final member = lib.members[memberIdx];

    final String memberName;
    if (member.name.startsWith('/') && member.name.length > 1) {
      final longnameOffset = int.parse(member.name.substring(1));
      memberName = lib.longnamesMember!.strings[longnameOffset]!;
    } else {
      memberName = member.name;
    }

    print(
        '${symbol.substring(0, min(symbol.length, 12)).padRight(12)} '
        '${memberName.padRight(38)} '
        '${memberIdx.toString().padRight(6)} '
        '$memberOffset');
  }
}
