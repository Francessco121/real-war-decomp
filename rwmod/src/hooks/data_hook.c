#include <WINDOWS.H>

#include "log.h"

extern size_t _read_data_file_base(char *path, void *out);

size_t read_data_file_hook(char *path, void *out) {
    int caller;
    GET_CALLER_ADDRESS(caller, 12);
    
    log_printlnf("[%x] read_data_file(%s)", caller, path);
    
    return _read_data_file_base(path, out);
}
