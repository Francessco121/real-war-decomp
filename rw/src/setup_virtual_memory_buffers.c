#include "MEMORY.H"

#define VIRTUAL_MEMORY_BUFFER_SIZE 8192

int g_virtual_memory_buffers[VIRTUAL_MEMORY_BUFFER_SIZE];
int g_zeroed_mem_8192_bytes_2[VIRTUAL_MEMORY_BUFFER_SIZE]; // note: not bytes lol
int g_total_virtual_memory_allocated;

void setup_virtual_memory_buffers() {
    memset(g_virtual_memory_buffers, 0, sizeof(g_virtual_memory_buffers));
    memset(g_zeroed_mem_8192_bytes_2, 0, sizeof(g_zeroed_mem_8192_bytes_2));
    g_total_virtual_memory_allocated = 0;
}
