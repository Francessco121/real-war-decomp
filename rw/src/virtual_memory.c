#include <MEMORY.H>
#include <WINDOWS.H>

#include "strings.h"

#define MAX_VIRTUAL_MEMORY_BUFFERS 8192

extern void display_message(char *format, ...);
extern void display_message_and_exit(char* message);

extern void* gVirtualMemoryBuffers[MAX_VIRTUAL_MEMORY_BUFFERS];
extern size_t gVirtualMemorySizes[MAX_VIRTUAL_MEMORY_BUFFERS];
extern int gVirtualMemoryNumbers[MAX_VIRTUAL_MEMORY_BUFFERS];
extern int gTotalVirtualMemoryAllocated;

extern int DAT_0051b908;
extern int DAT_00567788;

void setup_virtual_memory_buffers() {
    memset(gVirtualMemoryBuffers, 0, sizeof(gVirtualMemoryBuffers));
    memset(gVirtualMemoryNumbers, 0, sizeof(gVirtualMemoryNumbers));
    gTotalVirtualMemoryAllocated = 0;
}

void FUN_004d5e90() {
    DAT_00567788 = gTotalVirtualMemoryAllocated;
}

#pragma ASM_FUNC FUN_004d5ea0

#pragma ASM_FUNC FUN_004d5ee0

#pragma ASM_FUNC FUN_004d5fb0

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
    gVirtualMemoryNumbers[bufferIndex] = DAT_0051b908;
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

#pragma ASM_FUNC FUN_004d62a0

#pragma ASM_FUNC FUN_004d62f0

#pragma ASM_FUNC FUN_004d6300

#pragma ASM_FUNC FUN_004d6310
