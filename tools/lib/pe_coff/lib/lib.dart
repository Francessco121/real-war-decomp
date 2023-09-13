import 'dart:typed_data';

import 'src/structured_file_reader.dart';
import 'src/utils.dart';

/// Descriptor for an Archive file.
/// 
/// Supports parsing SystemV/GNU symbol tables, Windows linker member
/// tables, and longname members if present. This class will primarily
/// use Windows terminology however.
class ArchiveFile {
  /// The magic string "!<arch>\n".
  final String signature;

  /// Descriptors for each archive member.
  final List<ArchiveMemberHeader> members;

  /// A map of file offsets to the corresponding member index.
  /// 
  /// Not a part of the file format. Provided for convienence.
  final Map<int, int> memberIndices;

  /// Windows 1st linker member (SystemV/GNU symbol table), if any.
  final FirstLinkerMember? firstLinkerMember;

  /// Windows 2nd linker member, if any.
  final SecondLinkerMember? secondLinkerMember;

  /// Member names that were too long to fit in a member header.
  final LongnamesMember? longnamesMember;

  ArchiveFile({
    required this.signature,
    required this.members,
    required this.memberIndices,
    this.firstLinkerMember,
    this.secondLinkerMember,
    this.longnamesMember,
  });

  factory ArchiveFile.fromList(Uint8List list, {Endian endian = Endian.little}) {
    return ArchiveFile._fromReader(StructuredFileReader.list(list, endian: endian), list.lengthInBytes);
  }

  factory ArchiveFile._fromReader(StructuredFileReader reader, int fileLength) {
    final eof = reader.position + fileLength;
    
    final signature = String.fromCharCodes(reader.readBytes(8));
    assert(signature == '!<arch>\n');

    final members = <ArchiveMemberHeader>[];
    final indices = <int, int>{};
    while (reader.position < eof) {
      // Headers are aligned to even bytes
      if (reader.position % 2 == 1) {
        reader.skip(1);

        if (reader.position >= eof) {
          break;
        }
      }

      indices[reader.position] = members.length;
      
      final memberHeader = ArchiveMemberHeader.fromReader(reader);
      members.add(memberHeader);

      reader.skip(memberHeader.size);
    }

    final FirstLinkerMember? firstLinkerMember;
    if (members.isNotEmpty && members[0].name == "/") {
      reader.setPosition(members[0].pointerToData);
      firstLinkerMember = FirstLinkerMember.fromReader(reader);
    } else {
      firstLinkerMember = null;
    }

    final SecondLinkerMember? secondLinkerMember;
    if (members.length > 1 && members[1].name == "/") {
      reader.setPosition(members[1].pointerToData);
      secondLinkerMember = SecondLinkerMember.fromReader(reader);
    } else {
      secondLinkerMember = null;
    }

    final LongnamesMember? longnamesMember;
    if (members.length > 1 && members[1].name == "//") {
      reader.setPosition(members[1].pointerToData);
      longnamesMember = LongnamesMember.fromReader(reader, members[1].size);
    } else if (members.length > 2 && members[2].name == "//") {
      reader.setPosition(members[2].pointerToData);
      longnamesMember = LongnamesMember.fromReader(reader, members[2].size);
    } else {
      longnamesMember = null;
    }

    return ArchiveFile(
      signature: signature, 
      members: members,
      memberIndices: indices,
      firstLinkerMember: firstLinkerMember,
      secondLinkerMember: secondLinkerMember,
      longnamesMember: longnamesMember,
    );
  }
}

/// Header information for a single archive member.
///
/// A member is a single file within the archive.
class ArchiveMemberHeader {
  /// The name of the archive member.
  ///
  /// If the first character is a slash, the name has a special interpretation.
  final String name;

  /// The date and time that the archive member was created.
  final DateTime timestamp;

  /// User/owner ID.
  ///
  /// Does not have a meaningful value on Windows.
  final int userId;

  /// Group ID.
  ///
  /// Does not have a meaningful value on Windows.
  final int groupId;

  /// The member's file mode (i.e. type and permissions).
  final int mode;

  /// The total byte size of the member, excluding the size of the header.
  final int size;

  /// A file pointer to the member's data.
  ///
  /// Not actually part of the header. Instead, the data comes right after
  /// the header. This field is provided for convienence.
  final int pointerToData;

  ArchiveMemberHeader({
    required this.name,
    required this.timestamp,
    required this.userId,
    required this.groupId,
    required this.mode,
    required this.size,
    required this.pointerToData,
  });

  factory ArchiveMemberHeader.fromReader(StructuredFileReader reader) {
    final pointerToData = reader.position + 60;

    final nameBytes = reader.readBytes(16);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
        parseAsciiNumeric(reader.readBytes(12)) * 1000);
    final userId = parseAsciiNumeric(reader.readBytes(6));
    final groupId = parseAsciiNumeric(reader.readBytes(6));
    final mode = parseAsciiNumeric(reader.readBytes(8), radix: 8);
    final size = parseAsciiNumeric(reader.readBytes(10));
    final eoh = reader.readBytes(2);

    assert(eoh[0] == 0x60 && eoh[1] == 0x0A);

    var name = String.fromCharCodes(nameBytes).trimRight();
    // Strip terminating slash when not a special file name
    if (!name.startsWith('/')) {
      final terminator = name.indexOf('/');
      if (terminator > 0) {
        name = name.substring(0, terminator);
      }
    }

    return ArchiveMemberHeader(
      name: name, 
      timestamp: timestamp, 
      userId: userId, 
      groupId: groupId, 
      mode: mode, 
      size: size, 
      pointerToData: pointerToData,
    );
  }
}

/// Windows 1st linker member (SystemV/GNU symbol table). 
class FirstLinkerMember {
  /// The number of indexed symbols.
  final int numberOfSymbols;

  /// For each symbol, the file offset to the archive member that
  /// contains the symbol.
  final List<int> offsets;
  
  /// Names of all indexed symbols.
  final List<String> stringTable;

  FirstLinkerMember({
    required this.numberOfSymbols,
    required this.offsets,
    required this.stringTable,
  });

  factory FirstLinkerMember.fromReader(StructuredFileReader reader) {
    final numberOfSymbols = reader.readUint32(Endian.big);

    final offsets = <int>[];
    for (int i = 0; i < numberOfSymbols; i++) {
      offsets.add(reader.readUint32(Endian.big));
    }

    final stringTable = <String>[];
    for (int i = 0; i < numberOfSymbols; i++) {
      stringTable.add(reader.readNullTerminatedString());
    }

    return FirstLinkerMember(
      numberOfSymbols: numberOfSymbols, 
      offsets: offsets, 
      stringTable: stringTable,
    );
  }
}

/// Windows 2nd linker member. 
class SecondLinkerMember {
  /// The number of archive members.
  final int numberOfMembers;

  /// Files offsets to each archive member, in ascending order.
  final List<int> offsets;

  /// The number of indexed symbols.
  final int numberOfSymbols;

  /// 1-based indices that map symbols to an entry in [offsets].
  final List<int> indices;

  /// Names of all indexed symbols, in ascending lexical order.
  final List<String> stringTable;

  SecondLinkerMember({
    required this.numberOfMembers,
    required this.offsets,
    required this.numberOfSymbols,
    required this.indices,
    required this.stringTable,
  });

  factory SecondLinkerMember.fromReader(StructuredFileReader reader) {
    final numberOfMembers = reader.readUint32();

    final offsets = <int>[];
    for (int i = 0; i < numberOfMembers; i++) {
      offsets.add(reader.readUint32());
    }

    final numberOfSymbols = reader.readUint32();

    final indices = <int>[];
    for (int i = 0; i < numberOfSymbols; i++) {
      indices.add(reader.readUint16());
    }

    final stringTable = <String>[];
    for (int i = 0; i < numberOfSymbols; i++) {
      stringTable.add(reader.readNullTerminatedString());
    }

    return SecondLinkerMember(
      numberOfMembers: numberOfMembers, 
      offsets: offsets, 
      numberOfSymbols: numberOfSymbols, 
      indices: indices, 
      stringTable: stringTable,
    );
  }
}

class LongnamesMember {
  /// A map of relative byte offsets to the string, for each longname string.
  final Map<int, String> strings;

  LongnamesMember(this.strings);

  factory LongnamesMember.fromReader(StructuredFileReader reader, int memberSize) {
    final memberDataStart = reader.position;
    final eom = reader.position + memberSize;
    final strings = <int, String>{};

    while (reader.position < eom) {
      strings[reader.position - memberDataStart] = reader.readNullTerminatedString();
    }

    return LongnamesMember(strings);
  }
}
