#pragma once

void load_game_dirs_from_registry();
void to_absolute_data_path2(char *path);
void to_absolute_data_path(char *path);
void cd_check();
char *get_absolute_vid_path(char *path, int idx);
void set_game_registry_value(char *name, char *value);
int get_game_registry_value(char *name, char *outValue);
