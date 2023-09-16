#include <std/mem.pat>
#include <std/string.pat>

#pragma endian little
#pragma pattern_limit 999999

struct TGCHeader {
    u16 width;
    u16 height;
};

using Run;

fn format_run(Run run) {
    if (run.ctrl & 0x8000) {
        return "cpy: " + std::string::to_string(run.ctrl & 0x7FFF);
    } else {
        return "rep: " + std::string::to_string(run.ctrl & 0x7FFF);
    }
};

struct Run {
    u16 ctrl;
    
    if (ctrl & 0x8000) {
        u16 literal[ctrl & 0x7FFF] [[highlight_hidden]];
    } else {
        u16 repeat [[highlight_hidden]];
    }
} [[format("format_run")]];

TGCHeader header @ 0x0;
Run runs[while(std::mem::read_unsigned($, 2) != 0xFFFF)] @ $;
u32 endOfData @ $;
u32 trailer @ $;