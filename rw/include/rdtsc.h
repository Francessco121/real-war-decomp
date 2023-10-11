#pragma once

#include "types.h"

/**
 * Reads the CPU's current time-stamp counter (i.e. clock cycles since last reset).
 */
extern void rdtsc(uint64 *outValue);
/**
 * Calculates the number of clock cycles that have passed since the given counter value.
 */
extern void rdtsc_delta(uint64 *since, uint64 *outDelta);
