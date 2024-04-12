#include <MEMORY.H>
#include <STDIO.H>
#include <WINDOWS.H>

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

bool32 gEnableRwMap;
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
        sRwMapTxtFile = fopen("rwmap.txt", "wb");
        fprintf(sRwMapTxtFile, "Memory map file.\r\n\r\n");
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
        sprintf(gTempString, "Total Used = %d,%03d,%03d", millions, thousands, hundreds);
    } else if (thousands != 0) {
        sprintf(gTempString, "Total Used = %d,%03d", thousands, hundreds);
    } else {
        sprintf(gTempString, "Total Used = %d", hundreds);
    }

    fprintf(sRwMapTxtFile, "%s\r\n\r\n", gTempString);
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
        sprintf(gTempString, "Used = %3d,%03d,%03d at %18s", millions, thousands, hundreds, str);
    } else if (thousands != 0) {
        sprintf(gTempString, "Used =     %3d,%03d at %18s", thousands, hundreds, str);
    } else {
        sprintf(gTempString, "Used =         %3d at %18s", hundreds, str);
    }

    bytesUsed = gTotalVirtualMemoryAllocated - DAT_0051b988;
    millions = bytesUsed / 1000000;
    thousands = (bytesUsed % 1000000) / 1000;
    hundreds = bytesUsed % 1000;

    if (millions != 0) {
        fprintf(sRwMapTxtFile, "%s %3d,%03d,%03d\r\n\r\n", gTempString, millions, thousands, hundreds);
    } else if (thousands != 0) {
        fprintf(sRwMapTxtFile, "%s     %3d,%03d\r\n\r\n", gTempString, thousands, hundreds);
    } else {
        fprintf(sRwMapTxtFile, "%s         %3d\r\n\r\n", gTempString, hundreds);
    }

    DAT_00567788 = gTotalVirtualMemoryAllocated;
}

void* custom_alloc(size_t bytes) {
    int i;
    int bufferIndex;
    void* allocatedPtr;

    if (bytes <= 0) {
        display_messagebox_and_exit("Trying to Allocate 0 Bytes.");
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

    display_messagebox_and_exit("No Memory Buffers Left For Allocation.");
    label1:

    if (bytes >= 0x400000) {
        allocatedPtr = VirtualAlloc(NULL, bytes, MEM_COMMIT, PAGE_READWRITE);
        
        if (allocatedPtr != NULL) {
            goto label2;
        }
        
        display_messagebox("Virtual Alloc Failed..");
    } else {
        allocatedPtr = malloc(bytes);

        if (allocatedPtr != NULL) {
            goto label2;
        }
    }

    display_messagebox_and_exit("No Memory left For Allocation.");
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
                    display_messagebox("Virtual Free Failed");
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
        sprintf(gTempString2, "Memory unaccounted %d", gTotalVirtualMemoryAllocated);
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
