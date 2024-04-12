#pragma once

#include "types.h"

extern void load_game_dirs_from_registry();
extern void to_absolute_data_path(char *path);
extern void to_absolute_dirtree_path(char *path);
extern void cd_check();
extern char *get_absolute_vid_path(const char *path, int32 idx);
extern void set_game_registry_value(const char *name, const char *value);
extern bool32 get_game_registry_value(const char *name, char *outValue);
