#pragma once

#include <MEMORY.H>

extern int gVirtualMemoryBufferNumber;

extern void setup_virtual_memory_buffers();

extern void skip_virtual_memory_rwmap_record();
extern void start_rwmap();
extern void end_rwmap();
extern void record_virtual_memory_to_rwmap(char* str);

extern void* custom_alloc(size_t bytes);
extern void custom_free(void** ptr);

extern void free_all_virtual_memory_buffers();

extern void set_virtual_memory_buffer_number(int num);
extern int get_virtual_memory_buffer_number();
extern void free_virtual_memory_buffer_by_number(int num);
