#pragma once

#include <STDDEF.H>

// For now, these are MSVC 6 specific. We can make this portable later with some #if magic.

typedef __int8 int8;
typedef unsigned __int8 uint8;
typedef __int16 int16;
typedef unsigned __int16 uint16;
typedef __int32 int32;
typedef unsigned __int32 uint32;
typedef __int64 int64;
typedef unsigned __int64 uint64;

typedef float float32;
typedef double float64;

typedef int bool32;
typedef __int8 bool8;

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif
