#include <WINDOWS.H>

#include "data.h"
#include "log.h"

#define LOG_DATA 0

extern size_t _read_data_file_base(char *path, void *out);
extern FILE *_open_data_file_base(char *path, char *mode);
extern FILE *_open_data_file_relative_base(char *path, char *mode);
extern size_t _read_data_file_partial_base(char *path, void *out, size_t length);
extern void _load_bigfile_header_base(char *path);
extern size_t _write_bytes_to_file_base(const char *filename, const void *ptr, int length);

extern int find_bigfile_entry_by_path(char *path);
extern void to_absolute_data_path(char *path);

extern int sBigFileEntryCount;

size_t read_data_file_hook(char *path, void *out) {
#if LOG_DATA
    int caller;
    GET_CALLER_ADDRESS(caller, 12);
    
    log_printlnf("[%x] read_data_file(%s)", caller, path);
#endif

    return _read_data_file_base(path, out);
}

FILE *open_data_file_hook(char *path, char *mode)  {
#if LOG_DATA
    int caller;
    GET_CALLER_ADDRESS(caller, 12);

    log_printlnf("[%x] open_data_file(%s)", caller, path);
#endif

    return _open_data_file_base(path, mode);
}

FILE *open_data_file_relative_hook(char *path, char *mode) {
#if LOG_DATA
    int caller;
    GET_CALLER_ADDRESS(caller, 12);

    if (find_bigfile_entry_by_path(path) < 0) {
        log_printlnf("[%x] open_data_file_relative(%s)", caller, path);
    }
#endif

    return _open_data_file_relative_base(path, mode);
}

size_t read_data_file_partial_hook(char *path, void *out, size_t length) {
#if LOG_DATA
    int caller;
    GET_CALLER_ADDRESS(caller, 20);

    log_printlnf("[%x] read_data_file_partial(%s, %d)", caller, path, length);
#endif

    return _read_data_file_partial_base(path, out, length);
}

void load_bigfile_header_hook(char *path) {
#if LOG_DATA
    char absolutePath[256];

    sprintf(absolutePath, "%s", path);
    to_absolute_data_path(absolutePath);

    log_printlnf("Loading bigfile at: %s", absolutePath);
#endif

    _load_bigfile_header_base(path);

#if LOG_DATA
    log_printlnf("Loaded %d bigfile entries", sBigFileEntryCount);
#endif
}

size_t write_bytes_to_file_hook(const char *filename, const void *ptr, int length) {
#if LOG_DATA
    int caller;
    GET_CALLER_ADDRESS(caller, 20);

    log_printlnf("[%x] write_bytes_to_file(%s, %d)", caller, filename, length);
#endif
    
    return _write_bytes_to_file_base(filename, ptr, length);
}
