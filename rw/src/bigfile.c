#include <STDIO.H>
#include <WINDOWS.H>

#include "bigfile.h"

extern void to_absolute_data_path2(char *path);

char gBigFileAbsolutePath[256];
BigFileEntry *gBigFileHeader;

int find_bigfile_entry_by_path(char *path);
void read_data_file_internal(char *path, void *out);

size_t read_data_file(char *path, void *out) {
    int index;
    FILE *file;
    size_t fileSize;
    char absolutePath[256];

    fileSize = 0;

    // Check if requested file is in bigfile
    index = find_bigfile_entry_by_path(path);
    
    if (index < 0) {
        // Not in bigfile, read from file system

        // Convert path to an absolute file path
        sprintf(absolutePath, "%s", path);
        to_absolute_data_path2(absolutePath);
        
        // Read
        file = fopen(absolutePath, "rb");
        if (file != NULL) {
            fseek(file, 0, SEEK_END);
            fileSize = ftell(file);
            fseek(file, 0, SEEK_SET);
            fread(out, 1, fileSize, file);
            fclose(file);
        }

        return fileSize;
    } 

    // File is in bigfile, read from that
    read_data_file_internal(path, out);
    
    // wtf? fileSize will always be zero here
    return fileSize;
}

// FUN_004d6910

// FUN_004d6960

// FUN_004d69a0

// get_data_file_length

size_t write_bytes_to_file(const char *filename, const void *ptr, int length) {
    FILE *file;
    size_t bytesWritten;

    bytesWritten = 0;
    file = fopen(filename, "wb");

    if (file != NULL) {
        if (length != 0) {
            bytesWritten = fwrite(ptr, 1, length, file);
        }
        fclose(file);
    }

    return bytesWritten;
}

static char *FUN_004d6b40(char *str, unsigned int *out) {
    unsigned int ints[4];
    char c;
    int i;

    ints[3] = 0;
    ints[2] = 0;
    ints[1] = 0;
    ints[0] = 0;

    for (i = 0; i < 4; i++) {
        c = *str;
        
        // To uppercase
        if (c >= 'a' && c <= 'z') {
            c = c & 0xdf;
        }

        // Substitute ':' for '/' and '\'
        ints[i] = (c == '\\' || c == '/') ? ':' : c;

        // Only increment if not at the end of the string,
        // but don't break the loop since we still need 4 values
        str += (*str != 0);
    }

    *out = ints[0] | (ints[1] << 8) | (ints[2] << 16) | (ints[3] << 24);
    return str;
}

static unsigned int some_kind_of_string_hash(char *str) {
    unsigned int var2;
    unsigned int var1;

    var2 = 0;
    var1 = 0;
    
    while (*str != 0) {
        str = FUN_004d6b40(str, &var1);
        var2 ^= var1;
    }

    return var2;
}

// load_bigfile_header

// find_bigfile_entry_by_path

static void read_data_file_internal(char *path, void *out) {
    int index;
    FILE *file;

    index = find_bigfile_entry_by_path(path);
    if (index < 0) {
        // Path isn't in bigfile, read from file system instead
        read_data_file(path, out);
        return;
    }

    // Path is in bigfile, read from bigfile on disk
    file = fopen(gBigFileAbsolutePath, "rb");
    fseek(file, gBigFileHeader[index].byteOffset, SEEK_SET);
    fread(out, gBigFileHeader[index].sizeBytes, 1, file);
    fclose(file);
}

// FUN_004d6eb0

// FUN_004d6f80

// FUN_004d6fe0
