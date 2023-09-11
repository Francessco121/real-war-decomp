#pragma once

#include <STDIO.H>

/**
 * Gets the address of the caller to the current function.
 * 
 * Offset depends on function this is used in.
 * Assumes that the calling instruction was 5-bytes long.
 */
#define GET_CALLER_ADDRESS(variable, offset)    \
    __asm mov eax, [esp+(offset)]               \
    __asm sub eax, 5                            \
    __asm mov (variable), eax             

/**
 * Print text to modlog.txt.
 */
void log_printlnf(char *format, ...) ;
