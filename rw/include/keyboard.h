#pragma once

#include "types.h"

#define MAX_KEYDOWN_HISTORY 32

// Array for all virtual key codes where a value of 0 is released and 1 is pressed
extern bool8 gKeysPressed[256];
// Same as [gKeysPressed] but only remains 1 for one tick 
extern bool8 gKeysTapped[256];

extern int32 gKeyDownHistoryIdx;
extern int32 gKeyDownHistory[MAX_KEYDOWN_HISTORY];
extern bool8 gKeysDown[256];
extern int32 gKeyDownBufferIdx;

extern uint32 get_key_state(int nVirtKey);
extern void update_keys_pressed();
extern bool32 was_key_tapped(int virtKeyCode);
