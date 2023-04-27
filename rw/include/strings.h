/**
 * @file
 * @brief Static strings affected by duplicate string elimination (/Gf) in the
 * base executable.
 * 
 * Since the way the MSVC linker deals with duplicate strings isn't documented,
 * for the purposes of this decomp we will refer to them primarily as externs.
 * Object files that happen to have the actual declaration can declare them as
 * a global to let its .data section actually match.
 * 
 * Note: Real War used /Gf NOT /GF so strings are declared in *writable* .data,
 * and NOT readonly .rdata like other compilers would do.
 */

extern char str_rb[]; // "rb"
extern char str_wb[]; // "wb"
extern char str_pct_s[]; // "%s"
extern char str_pct_s_2[]; // "%s"
