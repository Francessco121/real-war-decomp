// This file is for disabling warnings that we cannot always avoid due to matching 
// code not always being the cleanest C code. If the Real War developers compiled 
// with /W4, they didn't read all of them. :)

// DO NOT INCLUDE THIS HEADER IN UNFINISHED FILES! Disabling these warnings may 
// hide useful information while trying to match a function! Once a file has all
// functions decompiled and all are at least non-matching (but equivalent), then this
// header can be included to clear up the compilation output.

// "conditional expression is constant"
// MSVC 6 doesn't make an exception for things like while (1) like newer versions do.
#pragma warning( disable : 4127 )

// "not all control paths return a value"
// Some Real War functions just simply have missing returns...
#pragma warning( disable : 4715 )
// "'X' must return a value"
// Same reasoning as 4715
#pragma warning( disable : 4033 )

// "unreferenced formal parameter"
// Some functions have unused parameters. We cannot remove these.
#pragma warning( disable : 4100 )

// "local variable 'X' may be used without having been initialized"
// Some functions will read from local variables that appear to the compiler as
// uninitialized, but are always initialized first if you follow the control flow.
#pragma warning( disable : 4701 )
