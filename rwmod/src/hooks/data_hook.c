#include <WINDOWS.H>

#include "log.h"

extern size_t _read_data_file_base(char *path, void *out);
extern FILE *_open_data_file_base(char *path, char *mode) ;

size_t read_data_file_hook(char *path, void *out) {
    int caller;
    GET_CALLER_ADDRESS(caller, 12);
    
    log_printlnf("[%x] read_data_file(%s)", caller, path);
    
    return _read_data_file_base(path, out);
}

FILE *open_data_file_hook(char *path, char *mode)  {
    int caller;
    GET_CALLER_ADDRESS(caller, 12);
    
    log_printlnf("[%x] open_data_file(%s)", caller, path);
    
    return _open_data_file_base(path, mode);
}
