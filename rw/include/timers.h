#pragma once

#include "types.h"

#define NUM_TIMERS 34

#define TIMER_CLOCKERS 33
#define TIMER_RESOLUTION_PER_FRAME 32

extern void init_timers();
extern void set_timer_label(int32 timer, const char *label);
extern void set_timer_label_and_update_cycle_counter(int32 timer, const char *label);
extern void update_timer_cycle_counter(int32 timer);
extern void update_timer_cycle_delta(int32 timer);
extern void set_timer_cycle_delta(int32 timer, uint32 delta);
extern uint32 get_timer_cycle_delta(int32 timer);
extern uint32 increment_timer_total_for_avg(int32 timer);
extern void reset_all_timer_cycle_counters();
extern void reset_timer_cycle_counter(int32 timer);
extern const char *timer_tostring(int32 timer);
extern void calculate_timer_resolution();
