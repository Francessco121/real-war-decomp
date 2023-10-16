#include <MEMORY.H>
#include <STDIO.H>
#include <WINDOWS.H>

#include "strings.h"
#include "types.h"
#include "undefined.h"
#include "virtual_memory.h"
#include "window.h"

#define MAX_VIRTUAL_MEMORY_BUFFERS 8192

// .bss

void* gVirtualMemoryBuffers[MAX_VIRTUAL_MEMORY_BUFFERS];
size_t gVirtualMemorySizes[MAX_VIRTUAL_MEMORY_BUFFERS];
int32 gVirtualMemoryNumbers[MAX_VIRTUAL_MEMORY_BUFFERS];
int32 gTotalVirtualMemoryAllocated;

bool gEnableRwMap;
int32 DAT_0051b988;
int32 DAT_00567788;
FILE* sRwMapTxtFile;

// .text

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
    int32 bytesUsed;
    int32 millions;
    int32 thousands;
    int32 hundreds;

    if (!gEnableRwMap) {
        return;
    }

    bytesUsed = gTotalVirtualMemoryAllocated - DAT_0051b988;
    millions = bytesUsed / 1000000;
    thousands = (bytesUsed % 1000000) / 1000;
    hundreds = bytesUsed % 1000;

    if (millions != 0) {
        sprintf(gTempString, str_total_used3, millions, thousands, hundreds);
    } else if (thousands != 0) {
        sprintf(gTempString, str_total_used2, thousands, hundreds);
    } else {
        sprintf(gTempString, str_total_used, hundreds);
    }

    fprintf(sRwMapTxtFile, str_pct_newline_newline, gTempString);
    fclose(sRwMapTxtFile);
}

void record_virtual_memory_to_rwmap(const char *str) {
    int32 bytesUsed;
    int32 millions;
    int32 thousands;
    int32 hundreds;

    if (!gEnableRwMap) {
        return;
    }

    bytesUsed = gTotalVirtualMemoryAllocated - DAT_00567788;
    millions = bytesUsed / 1000000;
    thousands = (bytesUsed % 1000000) / 1000;
    hundreds = bytesUsed % 1000;

    if (millions != 0) {
        sprintf(gTempString, str_used_eq_ddd, millions, thousands, hundreds, str);
    } else if (thousands != 0) {
        sprintf(gTempString, str_used_eq_dd, thousands, hundreds, str);
    } else {
        sprintf(gTempString, str_used_eq_d, hundreds, str);
    }

    bytesUsed = gTotalVirtualMemoryAllocated - DAT_0051b988;
    millions = bytesUsed / 1000000;
    thousands = (bytesUsed % 1000000) / 1000;
    hundreds = bytesUsed % 1000;

    if (millions != 0) {
        fprintf(sRwMapTxtFile, str_pct_ddd, gTempString, millions, thousands, hundreds);
    } else if (thousands != 0) {
        fprintf(sRwMapTxtFile, str_pct_tab_dd, gTempString, thousands, hundreds);
    } else {
        fprintf(sRwMapTxtFile, str_pct_tab_d, gTempString, hundreds);
    }

    DAT_00567788 = gTotalVirtualMemoryAllocated;
}

void* custom_alloc(size_t bytes) {
    int i;
    int bufferIndex;
    void* allocatedPtr;

    if (bytes <= 0) {
        display_messagebox_and_exit(str_trying_to_allocate_0);
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

    display_messagebox_and_exit(str_no_memory_buffers_left);
    label1:

    if (bytes >= 0x400000) {
        allocatedPtr = VirtualAlloc(NULL, bytes, MEM_COMMIT, PAGE_READWRITE);
        
        if (allocatedPtr != NULL) {
            goto label2;
        }
        
        display_messagebox(str_virtual_alloc_failed);
    } else {
        allocatedPtr = malloc(bytes);

        if (allocatedPtr != NULL) {
            goto label2;
        }
    }

    display_messagebox_and_exit(str_no_memory_left_for_alloc);
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
                    display_messagebox(str_virtual_free_failed);
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
        display_messagebox(gTempString2);
    }
}

void set_virtual_memory_buffer_number(int32 num) {
    gVirtualMemoryBufferNumber = num;
}

int get_virtual_memory_buffer_number() {
    return gVirtualMemoryBufferNumber;
}

void free_virtual_memory_buffer_by_number(int32 num) {
    int i;

    for (i = 0; i < MAX_VIRTUAL_MEMORY_BUFFERS; i++) {
        if (gVirtualMemoryBuffers[i] != NULL && gVirtualMemoryNumbers[i] == num) {
            custom_free(&gVirtualMemoryBuffers[i]);
        }
    }
}
