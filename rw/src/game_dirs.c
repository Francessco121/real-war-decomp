#include <WINDOWS.H>
#include <STDIO.H>

#include "data.h"
#include "game_dirs.h"
#include "strings.h"
#include "undefined.h"

extern char gVidTree[];
extern char gDataTree[];
extern char gCDDataDir[];
extern char gDirTree[];

char gRegKeyClass[16];
HKEY gSoftwareRegKey;
HKEY gRealWarRegKey;
DWORD gRegKeyDisposition;
DWORD gRegKeyValueType;
char gRegKeyValueData[256];
DWORD gRegKeyValueDataSize; // = 256
char gDirTreeRegValueData[256];

int get_game_registry_value(char *name, char *outValue);

void load_game_dirs_from_registry() {
    char value[256];

    if (get_game_registry_value(str_dirtree, value)) {
        sprintf(gDirTree, str_pct_s, &value);
    }

    if (get_game_registry_value(str_datatree, value)) {
        sprintf(gDataTree, str_pct_s, &value);
    }

    if (get_game_registry_value(str_vidtree, value)) {
        sprintf(gVidTree, str_pct_s, &value);
    }

    if (get_game_registry_value(str_cddatadir, value)) {
        sprintf(gCDDataDir, str_pct_s_vids_slash, &value);
    }
}

#pragma ASM_FUNC to_absolute_data_path2

#pragma ASM_FUNC to_absolute_data_path

void cd_check() {
    int retries = 0;
    BOOL flag = FALSE;
    FILE* file;

    while (TRUE) {
        sprintf(gTempString, str_pct_intro_mpg, gCDDataDir);

        if (get_data_file_length(gTempString)) {
            flag = TRUE;
        } else {
            display_message(str_please_insert_the_cd);
        }

        if (flag) {
            sprintf(gTempString, str_pct_cdtest_txt, gCDDataDir);

            file = fopen(gTempString, str_wb);
            if (file != NULL) {
                flag = FALSE;
                fclose(file);
                remove(gTempString);
                display_message(str_please_insert_the_cd);   
            } else if (flag) {
                return;
            }
        }

        if (++retries > 10) {
            game_exit();
        }
    }
}

#pragma ASM_FUNC get_absolute_vid_path

void set_game_registry_value(char *name, char *value) {
    LONG result;

    // Get/create key HKEY_LOCAL_MACHINE\Software
    result = RegCreateKeyExA(HKEY_LOCAL_MACHINE, str_software,
        0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
        &gSoftwareRegKey, &gRegKeyDisposition);
    
    if (result == ERROR_SUCCESS) {
        // Get/create key HKEY_LOCAL_MACHINE\Software\RealWar
        result = RegCreateKeyExA(gSoftwareRegKey, str_realwar,
            0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
            &gRealWarRegKey, &gRegKeyDisposition);
        
        if (result == ERROR_SUCCESS) {
            if (gRegKeyDisposition == REG_OPENED_EXISTING_KEY) {
                // Check if value already exists
                result = RegQueryValueExA(gRealWarRegKey, name, 0, 
                    &gRegKeyValueType, gRegKeyValueData, &gRegKeyValueDataSize);
                
                if (result == ERROR_SUCCESS) {
                    if (gRegKeyValueType == REG_SZ && strcmp(value, gRegKeyValueData) == 0) {
                        // Value already exists and matches the input value, do nothing
                        RegCloseKey(gRealWarRegKey);
                        RegCloseKey(gSoftwareRegKey);

                        if (strstr(name, str_dirtree_2)) {
                            sprintf(gDirTreeRegValueData, str_pct_s, gRegKeyValueData);
                        }

                        display_message(str_found_key, gRegKeyValueData);
                        return;
                    } else {
                        // Value exists but doesn't match, update it
                        sprintf(gRegKeyValueData, str_pct_s_2, value);

                        result = RegSetValueExA(gRealWarRegKey, name, 0,
                            REG_SZ, gRegKeyValueData, strlen(gRegKeyValueData) + 1);
                        
                        if (result == ERROR_SUCCESS) {
                            RegCloseKey(gRealWarRegKey);
                            RegCloseKey(gSoftwareRegKey);

                            if (strstr(name, str_dirtree_2)) {
                                sprintf(gDirTreeRegValueData, str_pct_s, gRegKeyValueData);
                            }

                            display_message(str_created_key, gRegKeyValueData);
                            return;
                        }

                        RegCloseKey(gRealWarRegKey);
                        RegCloseKey(gSoftwareRegKey);

                        display_message(str_couldnt_create_key, value);
                    }
                } else {
                    // Value doesn't exist, create it
                    sprintf(gRegKeyValueData, str_pct_s_2, value);

                    result = RegSetValueExA(gRealWarRegKey, name, 0,
                        REG_SZ, gRegKeyValueData, strlen(gRegKeyValueData) + 1);

                    RegCloseKey(gRealWarRegKey);
                    RegCloseKey(gSoftwareRegKey);

                    if (result == ERROR_SUCCESS) {
                        if (strstr(name, str_dirtree_2)) {
                            sprintf(gDirTreeRegValueData, str_pct_s, gRegKeyValueData);
                        }

                        display_message(str_created_key, gRegKeyValueData);
                        return;
                    }

                    display_message(str_couldnt_create_key, value);
                }
            } else {
                // RealWar key didn't exist, so the value definitely doesn't. Create it
                sprintf(gRegKeyValueData, str_pct_s_2, value);

                result = RegSetValueExA(gRealWarRegKey, name, 0,
                    REG_SZ, gRegKeyValueData, strlen(gRegKeyValueData) + 1);

                RegCloseKey(gRealWarRegKey);
                RegCloseKey(gSoftwareRegKey);

                if (result == ERROR_SUCCESS) {
                    if (strstr(name, str_dirtree_2)) {
                        sprintf(gDirTreeRegValueData, str_pct_s, gRegKeyValueData);
                    }

                    display_message(str_created_key, gRegKeyValueData);
                    return;
                }

                display_message(str_couldnt_create_key, value);
            }
        } else {
            RegCloseKey(gRealWarRegKey);
            RegCloseKey(gSoftwareRegKey);
            display_message(str_couldnt_create_key, value);
        }
    } else {
        display_message(str_couldnt_open_registry);
    }
}

int get_game_registry_value(char *name, char *outValue) {
    LONG result;

    // Create/get key HKEY_LOCAL_MACHINE\Software
    result = RegCreateKeyExA(HKEY_LOCAL_MACHINE, str_software,
        0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
        &gSoftwareRegKey, &gRegKeyDisposition);

    if (result == ERROR_SUCCESS) {
        // Create/get key HKEY_LOCAL_MACHINE\Software\RealWar
        result = RegCreateKeyExA(gSoftwareRegKey, str_realwar,
            0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
            &gRealWarRegKey, &gRegKeyDisposition);
        
        if (result == ERROR_SUCCESS && gRegKeyDisposition == REG_OPENED_EXISTING_KEY) {
            // Get value
            result = RegQueryValueExA(gRealWarRegKey, name, 
                0, &gRegKeyValueType, gRegKeyValueData, &gRegKeyValueDataSize);
            
            if (result == ERROR_SUCCESS) {
                if (gRegKeyValueType == REG_SZ) {
                    // If the value exists and is a string, return it
                    sprintf(outValue, str_pct_s, &gRegKeyValueData);
                    RegCloseKey(gRealWarRegKey);
                    RegCloseKey(gSoftwareRegKey);
                    return 1;
                }

                RegCloseKey(gRealWarRegKey);
                RegCloseKey(gSoftwareRegKey);
                return 0;
            } else {
                RegCloseKey(gRealWarRegKey);
                RegCloseKey(gSoftwareRegKey);
                return 0;
            }
        } else {
            RegCloseKey(gRealWarRegKey);
            RegCloseKey(gSoftwareRegKey);
            return 0;
        }
    } else {
        RegCloseKey(gSoftwareRegKey);
        return 0;
    }
}
