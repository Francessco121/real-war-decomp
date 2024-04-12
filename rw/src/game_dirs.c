#include <WINDOWS.H>
#include <STDIO.H>

#include "data.h"
#include "game_dirs.h"
#include "types.h"
#include "undefined.h"
#include "warnsuppress.h"
#include "window.h"


// .data

char gVidTree[256] = "vids\\";
char gDataTree[256] = "data\\";
char gCDDataDir[256] = "vids\\";
DWORD gRegKeyValueDataSize = 256;

// .bss

char gDirTree[256] = "";

char gRegKeyClass[16];
HKEY gSoftwareRegKey;
HKEY gRealWarRegKey;
DWORD gRegKeyDisposition;
DWORD gRegKeyValueType;
char gRegKeyValueData[256];
char gDirTreeRegValueData[256];
char gVidPaths[4][256];

// .text

void load_game_dirs_from_registry() {
    char value[256];

    if (get_game_registry_value("DIRTREE", value)) {
        sprintf(gDirTree, "%s", &value);
    }

    if (get_game_registry_value("DATATREE", value)) {
        sprintf(gDataTree, "%s", &value);
    }

    if (get_game_registry_value("VIDTREE", value)) {
        sprintf(gVidTree, "%s", &value);
    }

    if (get_game_registry_value("CDDATADIR", value)) {
        sprintf(gCDDataDir, "%svids\\", &value);
    }
}

void to_absolute_data_path(char *path) {
    int pathLen;
    int i;
    int dataSlashIdx;
    char temp[256];

    if (DAT_00ece464 != 0 || DAT_00945e94 != 0 || DAT_00f0c770 != 0 || DAT_01359b80 != 0) {
        return;
    }

    pathLen = strlen(path);
    dataSlashIdx = 0;

    for (i = 0; i < pathLen; i++) {
        if (path[i] >= 'a' && path[i] <= 'z') {
            path[i] -= 0x20;
        }

        if (
            (path[i + 0] == 'D' || path[i + 0] == 'd') &&
            (path[i + 1] == 'A' || path[i + 1] == 'a') &&
            (path[i + 2] == 'T' || path[i + 2] == 't') &&
            (path[i + 3] == 'A' || path[i + 3] == 'a') &&
            path[i + 4] == '\\'
        ) {
            dataSlashIdx = i + 1;
        }
    }

    if (dataSlashIdx == 0) {
        return;
    }

    if (strstr(path, "GAMESAVE") == NULL) {
        sprintf(temp, "%s", path);
        sprintf(&temp[dataSlashIdx - 1], "%s%s", gDataTree, &path[dataSlashIdx + 4]);
        sprintf(path, "%s", temp);
    }
}

void to_absolute_dirtree_path(char *path) {
    int pathLen;
    int i;
    int dataSlashIdx;
    char temp[256];

    if (DAT_00ece464 != 0 || DAT_00945e94 != 0 || DAT_00f0c770 != 0 || DAT_01359b80 != 0) {
        return;
    }

    pathLen = strlen(path);
    dataSlashIdx = 0;

    for (i = 0; i < pathLen; i++) {
        if (path[i] >= 'a' && path[i] <= 'z') {
            path[i] -= 0x20;
        }

        if (
            (path[i + 0] == 'D' || path[i + 0] == 'd') &&
            (path[i + 1] == 'A' || path[i + 1] == 'a') &&
            (path[i + 2] == 'T' || path[i + 2] == 't') &&
            (path[i + 3] == 'A' || path[i + 3] == 'a') &&
            path[i + 4] == '\\'
        ) {
            dataSlashIdx = i + 1;
        }
    }

    if (dataSlashIdx == 0) {
        return;
    }

    sprintf(temp, "%s", path);
    sprintf(&temp[dataSlashIdx - 1], "%sdata\\%s", gDirTree, &path[dataSlashIdx + 4]);
    sprintf(path, "%s", temp);
}

void cd_check() {
    int retries = 0;
    bool flag = FALSE;
    FILE* file;

    while (TRUE) {
        sprintf(gTempString, "%sintro.mpg", gCDDataDir);

        if (get_data_file_length(gTempString)) {
            flag = TRUE;
        } else {
            display_messagebox("Please insert the Real War CD\ninto the CD rom drive and\nselect OK to continue.");
        }

        if (flag) {
            sprintf(gTempString, "%scdtest.txt", gCDDataDir);

            file = fopen(gTempString, "wb");
            if (file != NULL) {
                flag = FALSE;
                fclose(file);
                remove(gTempString);
                display_messagebox("Please insert the Real War CD\ninto the CD rom drive and\nselect OK to continue.");   
            } else if (flag) {
                return;
            }
        }

        if (++retries > 10) {
            game_exit();
        }
    }
}

char *get_absolute_vid_path(const char *path, int32 idx) {
    int filenameStart;

    filenameStart = 0;

    while (path[filenameStart] != '.') {
        filenameStart++;
    }

    while (path[filenameStart] != '\\' && filenameStart >= 0) {
        filenameStart--;
    }

    sprintf(gVidPaths[idx], "%s%s", gVidTree, &path[filenameStart + 1]);
    return gVidPaths[idx];
}

void set_game_registry_value(const char *name, const char *value) {
    LONG result;

    // Get/create key HKEY_LOCAL_MACHINE\Software
    result = RegCreateKeyExA(HKEY_LOCAL_MACHINE, "Software",
        0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
        &gSoftwareRegKey, &gRegKeyDisposition);
    
    if (result == ERROR_SUCCESS) {
        // Get/create key HKEY_LOCAL_MACHINE\Software\RealWar
        result = RegCreateKeyExA(gSoftwareRegKey, "RealWar",
            0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
            &gRealWarRegKey, &gRegKeyDisposition);
        
        if (result == ERROR_SUCCESS) {
            if (gRegKeyDisposition == REG_OPENED_EXISTING_KEY) {
                // Check if value already exists
                result = RegQueryValueExA(gRealWarRegKey, name, 0, 
                    &gRegKeyValueType, (LPBYTE)gRegKeyValueData, &gRegKeyValueDataSize);
                
                if (result == ERROR_SUCCESS) {
                    if (gRegKeyValueType == REG_SZ && strcmp(value, gRegKeyValueData) == 0) {
                        // Value already exists and matches the input value, do nothing
                        RegCloseKey(gRealWarRegKey);
                        RegCloseKey(gSoftwareRegKey);

                        if (strstr(name, "DirTree")) {
                            sprintf(gDirTreeRegValueData, "%s", gRegKeyValueData);
                        }

                        display_messagebox("Found Key %s", gRegKeyValueData);
                        return;
                    } else {
                        // Value exists but doesn't match, update it
                        sprintf(gRegKeyValueData, "%s", value);

                        result = RegSetValueExA(gRealWarRegKey, name, 0,
                            REG_SZ, (BYTE*)gRegKeyValueData, strlen(gRegKeyValueData) + 1);
                        
                        if (result == ERROR_SUCCESS) {
                            RegCloseKey(gRealWarRegKey);
                            RegCloseKey(gSoftwareRegKey);

                            if (strstr(name, "DirTree")) {
                                sprintf(gDirTreeRegValueData, "%s", gRegKeyValueData);
                            }

                            display_messagebox("Created Key %s", gRegKeyValueData);
                            return;
                        }

                        RegCloseKey(gRealWarRegKey);
                        RegCloseKey(gSoftwareRegKey);

                        display_messagebox("Couldn't Create Key %s", value);
                    }
                } else {
                    // Value doesn't exist, create it
                    sprintf(gRegKeyValueData, "%s", value);

                    result = RegSetValueExA(gRealWarRegKey, name, 0,
                        REG_SZ, (BYTE*)gRegKeyValueData, strlen(gRegKeyValueData) + 1);

                    RegCloseKey(gRealWarRegKey);
                    RegCloseKey(gSoftwareRegKey);

                    if (result == ERROR_SUCCESS) {
                        if (strstr(name, "DirTree")) {
                            sprintf(gDirTreeRegValueData, "%s", gRegKeyValueData);
                        }

                        display_messagebox("Created Key %s", gRegKeyValueData);
                        return;
                    }

                    display_messagebox("Couldn't Create Key %s", value);
                }
            } else {
                // RealWar key didn't exist, so the value definitely doesn't. Create it
                sprintf(gRegKeyValueData, "%s", value);

                result = RegSetValueExA(gRealWarRegKey, name, 0,
                    REG_SZ, (BYTE*)gRegKeyValueData, strlen(gRegKeyValueData) + 1);

                RegCloseKey(gRealWarRegKey);
                RegCloseKey(gSoftwareRegKey);

                if (result == ERROR_SUCCESS) {
                    if (strstr(name, "DirTree")) {
                        sprintf(gDirTreeRegValueData, "%s", gRegKeyValueData);
                    }

                    display_messagebox("Created Key %s", gRegKeyValueData);
                    return;
                }

                display_messagebox("Couldn't Create Key %s", value);
            }
        } else {
            RegCloseKey(gRealWarRegKey);
            RegCloseKey(gSoftwareRegKey);
            display_messagebox("Couldn't Create Key %s", value);
        }
    } else {
        display_messagebox("Couldn't Open Registry!");
    }
}

bool get_game_registry_value(const char *name, char *outValue) {
    LONG result;

    // Create/get key HKEY_LOCAL_MACHINE\Software
    result = RegCreateKeyExA(HKEY_LOCAL_MACHINE, "Software",
        0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
        &gSoftwareRegKey, &gRegKeyDisposition);

    if (result == ERROR_SUCCESS) {
        // Create/get key HKEY_LOCAL_MACHINE\Software\RealWar
        result = RegCreateKeyExA(gSoftwareRegKey, "RealWar",
            0, gRegKeyClass, 0, KEY_ALL_ACCESS, NULL,
            &gRealWarRegKey, &gRegKeyDisposition);
        
        if (result == ERROR_SUCCESS && gRegKeyDisposition == REG_OPENED_EXISTING_KEY) {
            // Get value
            result = RegQueryValueExA(gRealWarRegKey, name, 
                0, &gRegKeyValueType, (LPBYTE)gRegKeyValueData, &gRegKeyValueDataSize);
            
            if (result == ERROR_SUCCESS) {
                if (gRegKeyValueType == REG_SZ) {
                    // If the value exists and is a string, return it
                    sprintf(outValue, "%s", &gRegKeyValueData);
                    RegCloseKey(gRealWarRegKey);
                    RegCloseKey(gSoftwareRegKey);
                    return TRUE;
                }

                RegCloseKey(gRealWarRegKey);
                RegCloseKey(gSoftwareRegKey);
                return FALSE;
            } else {
                RegCloseKey(gRealWarRegKey);
                RegCloseKey(gSoftwareRegKey);
                return FALSE;
            }
        } else {
            RegCloseKey(gRealWarRegKey);
            RegCloseKey(gSoftwareRegKey);
            return FALSE;
        }
    } else {
        RegCloseKey(gSoftwareRegKey);
        return FALSE;
    }
}
