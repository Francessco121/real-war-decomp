#pragma once

#include <WINDOWS.H>

#define NUM_TIMERS 34

#define TIMER_CLOCKERS 33
#define TIMER_RESOLUTION_PER_FRAME 32

extern char gTimerStrings[NUM_TIMERS][128];

// Note: these arrays are technically 64-bit integer arrays but the code only addresses them
// as 32-bit integers (aside from the indexing being correctly 64-bit). It's just easier to
// leave them defined as 32-bit integer arrays.

extern UINT32 gTimerValues[NUM_TIMERS * 2];
extern UINT32 gClockCycleDeltas[NUM_TIMERS * 2]; 
extern UINT32 gTimerCounters[NUM_TIMERS * 2];
extern UINT32 gClockCycleCounters[NUM_TIMERS * 2];

extern int DAT_005fa7c0;
extern int DAT_005fa7c4;
extern int DAT_005fa7c8;
extern int DAT_005fa7cc;

extern char gTimerTempString[256];
