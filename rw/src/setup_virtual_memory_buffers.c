#include <MEMORY.H>

#define VIRTUAL_MEMORY_BUFFER_SIZE 8192

extern int g_virtual_memory_buffers[VIRTUAL_MEMORY_BUFFER_SIZE];
extern int g_zeroed_mem_8192_bytes_2[VIRTUAL_MEMORY_BUFFER_SIZE]; // note: not bytes lol
extern int g_total_virtual_memory_allocated;

void setup_virtual_memory_buffers() {
    memset(g_virtual_memory_buffers, 0, sizeof(g_virtual_memory_buffers));
    memset(g_zeroed_mem_8192_bytes_2, 0, sizeof(g_zeroed_mem_8192_bytes_2));
    g_total_virtual_memory_allocated = 0;
}
