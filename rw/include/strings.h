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

extern char str_dd3d_obj_failed[]; // "Direct Draw 3D Object Failed"
extern char str_creation_of_id3d_failed[]; // "Creation of Direct3D interface failed."
extern char str_enum_of_drivers_failed[]; // "Enumeration of drivers failed."
extern char str_couldnt_find_compatible_d3d_driver[]; // "Could not find a D3D driver that is compatible with this program."

extern char str_pct_intro_mpg[]; // "%sintro.mpg"
extern char str_vids_slash[]; // "vids\\"
extern char str_please_insert_the_cd[]; // "Please insert the Real War CD\ninto the CD rom drive and\nselect OK to continue."
extern char str_pct_cdtest_txt[]; // "%scdtest.txt"

extern char str_trying_to_allocate_0[]; // "Trying to Allocate 0 Bytes."
extern char str_no_memory_buffers_left[]; // "No Memory Buffers Left For Allocation."
extern char str_virtual_alloc_failed[]; // "Virtual Alloc Failed.."
extern char str_no_memory_left_for_alloc[]; // "No Memory left For Allocation."
extern char str_virtual_free_failed[]; // "Virtual Free Failed"
