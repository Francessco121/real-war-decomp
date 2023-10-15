#pragma once

#include "types.h"

// Array for all virtual key codes where a value of 0 is released and 1 is pressed
extern bool8 gKeysPressed[256];
// Same as [gKeysPressed] but only remains 1 for one tick 
extern bool8 gKeysTapped[256];

extern uint32 get_key_state(int nVirtKey);
extern void update_keys_pressed();
extern bool was_key_tapped(int virtKeyCode);
