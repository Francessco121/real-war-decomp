#pragma once

#include <WINDOWS.H>

#define NUM_TIMERS 34

#define TIMER_CLOCKERS 33
#define TIMER_RESOLUTION_PER_FRAME 32

extern void init_timers();
extern void set_timer_label(int timer, char *label);
extern void set_timer_label_and_update_cycle_counter(int timer, char *label);
extern void update_timer_cycle_counter(int timer);
extern void update_timer_cycle_delta(int timer);
extern void set_timer_cycle_delta(int timer, UINT32 delta);
extern UINT32 get_timer_cycle_delta(int timer);
extern UINT32 increment_timer_total_for_avg(int timer);
extern void reset_all_timer_cycle_counters();
extern void reset_timer_cycle_counter(int timer);
extern char *timer_tostring(int timer);
extern void calculate_timer_resolution();
