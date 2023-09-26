#include <STDIO.H>
#include <WINDOWS.H>

#include "rdtsc.h"
#include "strings.h"
#include "timers.h"

// .data

static char sTimerStrings[NUM_TIMERS][128] = {
    "Timer 0", "Timer 1", "Timer 2", "Timer 3",
    "Timer 4", "Timer 5", "Timer 6", "Timer 7",
    "Timer 8", "Timer 9", "Timer 10", "Timer 11",
    "Timer 12", "Timer 13", "Timer 14", "Timer 15",
    "Timer 16", "Timer 17", "Timer 18", "Timer 19",
    "Timer 20", "Timer 21", "Timer 22", "Timer 23",
    "Timer 24", "Timer 25", "Timer 26", "Timer 27",
    "Timer 28", "Timer 29", "Timer 30", "Timer 31",
    "Timer 32", ""
};

// .bss

// Note: these arrays are technically 64-bit integer arrays but the code only addresses them
// as 32-bit integers (aside from the indexing being correctly 64-bit). It's just easier to
// leave them defined as 32-bit integer arrays.

static UINT32 sTimerValues[NUM_TIMERS * 2];
static UINT32 sClockCycleDeltas[NUM_TIMERS * 2]; 
static UINT32 sTimerCounters[NUM_TIMERS * 2];
static UINT32 sClockCycleCounters[NUM_TIMERS * 2];

static int sUnusedTimerGlobal1;
static int sUnusedTimerGlobal2;
static int sUnusedTimerGlobal3;
static int sUnusedTimerGlobal4;

static char sTimerTempString[256];

// .text

void init_timers() {
    memset(sTimerValues, 0, sizeof(sTimerValues));
    memset(sTimerCounters, 0, sizeof(sTimerCounters));
}

void set_timer_label(int timer, char *label) {
    sprintf(sTimerStrings[timer], str_pct_s, label);
}

void set_timer_label_and_update_cycle_counter(int timer, char *label) {
    sprintf(sTimerStrings[timer], str_pct_s, label);

    rdtsc((UINT64*)&sClockCycleCounters[timer*2]);
    sClockCycleCounters[timer*2] = sClockCycleCounters[timer*2] - 100;
}

void update_timer_cycle_counter(int timer) {
    rdtsc((UINT64*)&sClockCycleCounters[timer*2]);
}

void update_timer_cycle_delta(int timer) {
    rdtsc_delta((UINT64*)&sClockCycleCounters[timer*2], (UINT64*)&sClockCycleDeltas[timer*2]);
}

void set_timer_cycle_delta(int timer, UINT32 delta) {
    sClockCycleDeltas[timer*2] = delta;
}

UINT32 get_timer_cycle_delta(int timer) {
    return sClockCycleDeltas[timer*2];
}

UINT32 increment_timer_total_for_avg(int timer) {
    UINT32 delta;

    delta = sClockCycleDeltas[timer*2];

    if (delta != 0 || sTimerCounters[timer*2] != 0) {
        sTimerValues[timer*2] = sTimerValues[timer*2] + delta;
        sTimerCounters[timer*2] = sTimerCounters[timer*2] + 1;

        if (sTimerCounters[timer*2] > 8) {
            sTimerCounters[timer*2] = 1;
            sTimerValues[timer*2] = delta + 1;
        }
    }

    return sTimerCounters[timer*2];
}

void reset_all_timer_cycle_counters() {
    int i;
    // Note: This seems to be a bug: there's 34 timers total but this only clears
    // the first 32 elements. Maybe there was only 32 originally and they forgot
    // to update this function?
    for (i = 0; i < (NUM_TIMERS - 2); i++) {
        sClockCycleDeltas[i*2] = 0;
        sClockCycleDeltas[i*2 + 1] = 0;
        sClockCycleCounters[i*2] = 0;
        sClockCycleCounters[i*2 + 1] = 0;
    }
}

void reset_timer_cycle_counter(int timer) {
    sClockCycleDeltas[timer*2] = 0;
    sClockCycleDeltas[timer*2 + 1] = 0;
    sClockCycleCounters[timer*2] = 0;
    sClockCycleCounters[timer*2 + 1] = 0;
}

char *timer_tostring(int timer) {
    int avgDelta;
    int thousands;
    int millions;
    int hundreds;

    if (sTimerCounters[timer*2] != 0) {
        avgDelta = sTimerValues[timer*2] / sTimerCounters[timer*2] + 1;
    } else {
        avgDelta = sClockCycleDeltas[timer*2];
    }

    millions = avgDelta / 1000000;
    thousands = (avgDelta % 1000000) / 1000;
    hundreds = avgDelta % 1000;

    if (millions == 0) {
        if (thousands == 0) {
            sprintf(sTimerTempString, str_pct24s_d, sTimerStrings[timer], hundreds);
        } else {
            sprintf(sTimerTempString, str_pct24s_dd, sTimerStrings[timer], thousands, hundreds);
        }
    } else {
        sprintf(sTimerTempString, str_pct24s_ddd, sTimerStrings[timer], millions, thousands, hundreds);
    }
    
    return sTimerTempString;
}

void calculate_timer_resolution() {
    DWORD tc1, tc2;
    
    sUnusedTimerGlobal1 = 0;
    sUnusedTimerGlobal2 = 0;
    sUnusedTimerGlobal3 = 0;
    sUnusedTimerGlobal4 = 0;

    set_timer_label(TIMER_CLOCKERS, str_clockers);
    set_timer_label(TIMER_RESOLUTION_PER_FRAME, str_resolution_per_frame);

    tc1 = GetTickCount();
    update_timer_cycle_counter(TIMER_RESOLUTION_PER_FRAME);
    tc2 = GetTickCount();

    while (tc2 < (tc1 + 1000)) {
        tc2 = GetTickCount();
    }

    update_timer_cycle_delta(TIMER_RESOLUTION_PER_FRAME);
    set_timer_cycle_delta(TIMER_CLOCKERS, 
        get_timer_cycle_delta(TIMER_RESOLUTION_PER_FRAME) / 1000000);
    set_timer_cycle_delta(TIMER_RESOLUTION_PER_FRAME, 
        get_timer_cycle_delta(TIMER_RESOLUTION_PER_FRAME) / 60);
}
