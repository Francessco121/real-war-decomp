#pragma MIME application/x-archive

#include <std/string.pat>
#include <std/mem.pat>
#include <std/sys.pat>

struct NullTerminatedString {
    char value[while(std::mem::read_unsigned($, 1) != 0)];
    padding[1];
};

struct LinkerMember1 {
    be u32 num_entries;
    be u32 file_offsets[num_entries];
    NullTerminatedString string_table[num_entries];
};

struct LinkerMember2 {
    le u32 num_members;
    le u32 offsets[num_members];
    le u32 num_symbols;
    le u16 indices[num_symbols];
    NullTerminatedString string_table[num_symbols];
    
};

struct ARFile {
    char file_name[16];
    char modification_timestamp[12];
    char owner_id[6];
    char group_id[6];
    char file_mode[8];
    char file_size[10];
    u16 end_marker;
    
    u32 start = $;
    u32 file_size_int = std::string::parse_int(this.file_size, 10);
    
    if (end_marker == 0x0A60) {
        u8 data[std::string::parse_int(this.file_size, 10)];
        padding[$ & 1];
    }
};

char signature[8] @ 0x00;
std::assert(signature == "!<arch>\n", "File is not a valid archive!");

ARFile files[while($ < std::mem::size())] @ $;

LinkerMember1 linker_member_1 @ addressof(files[0].data);
LinkerMember2 linker_member_2 @ addressof(files[1].data);
NullTerminatedString longnames_member[while($ < addressof(files[3]))] @ addressof(files[2].data);