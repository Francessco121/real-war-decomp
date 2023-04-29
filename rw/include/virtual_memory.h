extern int gVirtualMemoryBufferNumber;

void setup_virtual_memory_buffers();

void skip_virtual_memory_rwmap_record();
void start_rwmap();
void end_rwmap();
void record_virtual_memory_to_rwmap(char* str);

void* custom_alloc(size_t bytes);
void custom_free(void** ptr);

void free_all_virtual_memory_buffers();

void set_virtual_memory_buffer_number(int num);
int get_virtual_memory_buffer_number();
void free_virtual_memory_buffer_by_number(int num);
