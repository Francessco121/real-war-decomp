#pragma once

#include <STDIO.H>

/**
 * Gets the address of the caller to the current function.
 * 
 * MUST be the first line of the function (after variable declarations).
 * Assumes that [esp+8] is the caller return address.
 * Assumes that the calling instruction was 5-bytes long.
 */
#define GET_CALLER_ADDRESS(variable)    \
    __asm mov eax, [esp+8]              \
    __asm sub eax, 5                    \
    __asm mov (variable), eax             

/**
 * Print text to modlog.txt.
 */
void log_printlnf(char *format, ...) ;
