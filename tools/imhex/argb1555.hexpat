#include <std/string.pat>

struct Pixel {
    u16 value;
} [[sealed, color(std::format("{:02X}{:02X}{:02X}", ((value >> 10) & 0x1F) * 8, ((value >> 5) & 0x1F) * 8, ((value >> 0) & 0x1F) * 8))]];

Pixel pixels[while($ < sizeof($))] @ 0;