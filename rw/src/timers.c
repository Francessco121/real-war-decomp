#include <STDIO.H>
#include <WINDOWS.H>

#include "rdtsc.h"
#include "strings.h"
#include "timers.h"

void init_timers() {
    memset(gTimerValues, 0, sizeof(gTimerValues));
    memset(gTimerCounters, 0, sizeof(gTimerCounters));
}

void set_timer_label(int timer, char *label) {
    sprintf(gTimerStrings[timer], str_pct_s, label);
}

void set_timer_label_and_update_cycle_counter(int timer, char *label) {
    sprintf(gTimerStrings[timer], str_pct_s, label);

    rdtsc((UINT64*)&gClockCycleCounters[timer*2]);
    gClockCycleCounters[timer*2] = gClockCycleCounters[timer*2] - 100;
}

void update_timer_cycle_counter(int timer) {
    rdtsc((UINT64*)&gClockCycleCounters[timer*2]);
}

void update_timer_cycle_delta(int timer) {
    rdtsc_delta((UINT64*)&gClockCycleCounters[timer*2], (UINT64*)&gClockCycleDeltas[timer*2]);
}

void set_timer_cycle_delta(int timer, UINT32 delta) {
    gClockCycleDeltas[timer*2] = delta;
}

UINT32 get_timer_cycle_delta(int timer) {
    return gClockCycleDeltas[timer*2];
}

UINT32 increment_timer_total_for_avg(int timer) {
    UINT32 delta;

    delta = gClockCycleDeltas[timer*2];

    if (delta != 0 || gTimerCounters[timer*2] != 0) {
        gTimerValues[timer*2] = gTimerValues[timer*2] + delta;
        gTimerCounters[timer*2] = gTimerCounters[timer*2] + 1;

        if (gTimerCounters[timer*2] > 8) {
            gTimerCounters[timer*2] = 1;
            gTimerValues[timer*2] = delta + 1;
        }
    }

    return gTimerCounters[timer*2];
}

void reset_all_timer_cycle_counters() {
    int i;
    // Note: This seems to be a bug: there's 34 timers total but this only clears
    // the first 32 elements. Maybe there was only 32 originally and they forgot
    // to update this function?
    for (i = 0; i < (NUM_TIMERS - 2); i++) {
        gClockCycleDeltas[i*2] = 0;
        gClockCycleDeltas[i*2 + 1] = 0;
        gClockCycleCounters[i*2] = 0;
        gClockCycleCounters[i*2 + 1] = 0;
    }
}

void reset_timer_cycle_counter(int timer) {
    gClockCycleDeltas[timer*2] = 0;
    gClockCycleDeltas[timer*2 + 1] = 0;
    gClockCycleCounters[timer*2] = 0;
    gClockCycleCounters[timer*2 + 1] = 0;
}

char *timer_tostring(int timer) {
    int avgDelta;
    int thousands;
    int millions;
    int hundreds;

    if (gTimerCounters[timer*2] != 0) {
        avgDelta = gTimerValues[timer*2] / gTimerCounters[timer*2] + 1;
    } else {
        avgDelta = gClockCycleDeltas[timer*2];
    }

    millions = avgDelta / 1000000;
    thousands = (avgDelta % 1000000) / 1000;
    hundreds = avgDelta % 1000;

    if (millions == 0) {
        if (thousands == 0) {
            sprintf(gTimerTempString, str_pct24s_d, gTimerStrings[timer], hundreds);
        } else {
            sprintf(gTimerTempString, str_pct24s_dd, gTimerStrings[timer], thousands, hundreds);
        }
    } else {
        sprintf(gTimerTempString, str_pct24s_ddd, gTimerStrings[timer], millions, thousands, hundreds);
    }
    
    return gTimerTempString;
}

void calculate_timer_resolution() {
    DWORD tc1, tc2;
    
    DAT_005fa7c0 = 0;
    DAT_005fa7c4 = 0;
    DAT_005fa7c8 = 0;
    DAT_005fa7cc = 0;

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
