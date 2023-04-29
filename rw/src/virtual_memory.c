#include <MEMORY.H>
#include <STDIO.H>
#include <WINDOWS.H>

#include "strings.h"
#include "virtual_memory.h"

#define MAX_VIRTUAL_MEMORY_BUFFERS 8192

extern void display_message(char *format, ...);
extern void display_message_and_exit(char* message);

extern void* gVirtualMemoryBuffers[MAX_VIRTUAL_MEMORY_BUFFERS];
extern size_t gVirtualMemorySizes[MAX_VIRTUAL_MEMORY_BUFFERS];
extern int gVirtualMemoryNumbers[MAX_VIRTUAL_MEMORY_BUFFERS];
extern int gTotalVirtualMemoryAllocated;

extern BOOL gEnableRwMap;
extern int DAT_0051b988;
extern int DAT_00567788;
extern FILE* sRwMapTxtFile;

extern char gTempString[];
extern char gTempString2[];

void setup_virtual_memory_buffers() {
    memset(gVirtualMemoryBuffers, 0, sizeof(gVirtualMemoryBuffers));
    memset(gVirtualMemoryNumbers, 0, sizeof(gVirtualMemoryNumbers));
    gTotalVirtualMemoryAllocated = 0;
}

void skip_virtual_memory_rwmap_record() {
    DAT_00567788 = gTotalVirtualMemoryAllocated;
}

void start_rwmap() {
    if (gEnableRwMap) {
        DAT_0051b988 = gTotalVirtualMemoryAllocated;
        DAT_00567788 = gTotalVirtualMemoryAllocated;
        sRwMapTxtFile = fopen(str_rwmap_txt, str_wb);
        fprintf(sRwMapTxtFile, str_memory_map_file);
    }
}

void end_rwmap() {
    int var1;
    int var2;
    int var3;
    int var4;

    if (gEnableRwMap == FALSE) {
        return;
    }

    var2 = gTotalVirtualMemoryAllocated - DAT_0051b988;
    var3 = var2 / 1000000;
    var1 = (var2 % 1000000) / 1000;
    var4 = var2 % 1000;

    if (var3 != 0) {
        sprintf(gTempString, str_total_used3, var3, var1, var4);
    } else if (var1 != 0) {
        sprintf(gTempString, str_total_used2, var1, var4);
    } else {
        sprintf(gTempString, str_total_used, var4);
    }

    fprintf(sRwMapTxtFile, str_pct_newline_newline, gTempString);
    fclose(sRwMapTxtFile);
}

void record_virtual_memory_to_rwmap(char *str) {
    int var1;
    int var2;
    int var3;
    int var4;

    if (gEnableRwMap == FALSE) {
        return;
    }

    var2 = gTotalVirtualMemoryAllocated - DAT_00567788;
    var3 = var2 / 1000000;
    var1 = (var2 % 1000000) / 1000;
    var4 = var2 % 1000;

    if (var3 != 0) {
        sprintf(gTempString, str_used_eq_ddd, var3, var1, var4, str);
    } else if (var1 != 0) {
        sprintf(gTempString, str_used_eq_dd, var1, var4, str);
    } else {
        sprintf(gTempString, str_used_eq_d, var4, str);
    }

    var2 = gTotalVirtualMemoryAllocated - DAT_0051b988;
    var3 = var2 / 1000000;
    var1 = (var2 % 1000000) / 1000;
    var4 = var2 % 1000;

    if (var3 != 0) {
        fprintf(sRwMapTxtFile, str_pct_ddd, gTempString, var3, var1, var4);
    } else if (var1 != 0) {
        fprintf(sRwMapTxtFile, str_pct_tab_dd, gTempString, var1, var4);
    } else {
        fprintf(sRwMapTxtFile, str_pct_tab_d, gTempString, var4);
    }

    DAT_00567788 = gTotalVirtualMemoryAllocated;
}

void* custom_alloc(size_t bytes) {
    int i;
    int bufferIndex;
    void* allocatedPtr;

    if (bytes <= 0) {
        display_message_and_exit(str_trying_to_allocate_0);
    }

    bufferIndex = 0;
    for (i = 0; i < MAX_VIRTUAL_MEMORY_BUFFERS; i++) {
        if (gVirtualMemoryBuffers[i] == NULL) {
            if (bufferIndex >= MAX_VIRTUAL_MEMORY_BUFFERS) {
                break;
            }
            goto label1;
        }
        bufferIndex++;
    }

    display_message_and_exit(str_no_memory_buffers_left);
    label1:

    if (bytes >= 0x400000) {
        allocatedPtr = VirtualAlloc(NULL, bytes, MEM_COMMIT, PAGE_READWRITE);
        
        if (allocatedPtr != NULL) {
            goto label2;
        }
        
        display_message(str_virtual_alloc_failed);
    } else {
        allocatedPtr = malloc(bytes);

        if (allocatedPtr != NULL) {
            goto label2;
        }
    }

    display_message_and_exit(str_no_memory_left_for_alloc);
    label2:

    gVirtualMemoryBuffers[bufferIndex] = allocatedPtr;
    gVirtualMemoryNumbers[bufferIndex] = gVirtualMemoryBufferNumber;
    gVirtualMemorySizes[bufferIndex] = bytes;
    gTotalVirtualMemoryAllocated += bytes;

    return allocatedPtr;
}

void custom_free(void** ptr) {
    size_t i;
    
    if (*ptr == NULL) {
        return;
    }

    for (i = 0; i < MAX_VIRTUAL_MEMORY_BUFFERS; i++) {
        if (gVirtualMemoryBuffers[i] == *ptr) {
            if (i >= MAX_VIRTUAL_MEMORY_BUFFERS) {
                return;
            }

            if (gVirtualMemorySizes[i] >= 0x400000) {
                if (VirtualFree(gVirtualMemoryBuffers[i], 0, 0x8000) == 0) {
                    display_message(str_virtual_free_failed);
                }
            } else {
                free(gVirtualMemoryBuffers[i]);
            }

            gTotalVirtualMemoryAllocated -= gVirtualMemorySizes[i];
            *ptr = NULL;
            gVirtualMemoryBuffers[i] = NULL;
            gVirtualMemoryNumbers[i] = 0;
            gVirtualMemorySizes[i] = 0;
            return;
        }
    }
}

void free_all_virtual_memory_buffers() {
    int i;

    for (i = 0; i < MAX_VIRTUAL_MEMORY_BUFFERS; i++) {
        if (gVirtualMemoryBuffers[i] != NULL) {
            custom_free(&gVirtualMemoryBuffers[i]);
        }
    }

    if (gTotalVirtualMemoryAllocated != 0) {
        sprintf(gTempString2, str_memory_unaccounted, gTotalVirtualMemoryAllocated);
        display_message(gTempString2);
    }
}

void set_virtual_memory_buffer_number(int num) {
    gVirtualMemoryBufferNumber = num;
}

int get_virtual_memory_buffer_number() {
    return gVirtualMemoryBufferNumber;
}

void free_virtual_memory_buffer_by_number(int num) {
    int i;

    for (i = 0; i < MAX_VIRTUAL_MEMORY_BUFFERS; i++) {
        if (gVirtualMemoryBuffers[i] != NULL && gVirtualMemoryNumbers[i] == num) {
            custom_free(&gVirtualMemoryBuffers[i]);
        }
    }
}
