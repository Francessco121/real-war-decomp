#pragma once

#include <WINDOWS.H>

/**
 * Reads the CPU's current time-stamp counter (i.e. clock cycles since last reset).
 */
void rdtsc(UINT64 *outValue);
/**
 * Calculates the number of clock cycles that have passed since the given counter value.
 */
void rdtsc_delta(UINT64 *since, UINT64 *outDelta);
