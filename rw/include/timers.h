#pragma once

#include <WINDOWS.H>

#define NUM_TIMERS 34

#define TIMER_CLOCKERS 33
#define TIMER_RESOLUTION_PER_FRAME 32

void init_timers();
void set_timer_label(int timer, char *label);
void set_timer_label_and_update_cycle_counter(int timer, char *label);
void update_timer_cycle_counter(int timer);
void update_timer_cycle_delta(int timer);
void set_timer_cycle_delta(int timer, UINT32 delta);
UINT32 get_timer_cycle_delta(int timer);
UINT32 increment_timer_total_for_avg(int timer);
void reset_all_timer_cycle_counters();
void reset_timer_cycle_counter(int timer);
char *timer_tostring(int timer);
void calculate_timer_resolution();
