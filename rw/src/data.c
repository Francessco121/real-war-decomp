#include <STDIO.H>
#include <WINDOWS.H>

#include "data.h"
#include "strings.h"
#include "undefined.h"
#include "virtual_memory.h"

typedef struct BigFileEntry {
    char path[64];
    /// An XOR hash of [path]
    unsigned int pathHash;
    // File pointer in bigfile.dat
    unsigned int byteOffset;
    unsigned int sizeBytes;
} BigFileEntry;

/**
 * Used to track line-by-line reads of files in bigfile.dat and prevent reads
 * from leaking into other files also in bigfile.
 */
typedef struct BigFileEntryPointer {
    FILE *file;
    // Current byte position in the file.
    int position;
    int sizeBytes;
    // File pointer in bigfile.dat
    unsigned int byteOffset;
} BigFileEntryPointer;

#define MAX_BIG_FILE_ENTRY_POINTERS 32

// note: these symbols have very different addresses even though they're only 
// referenced in this file...
extern int sBigFileEntryCount;
extern int sLoadedBigFileHeader;
extern char sBigFileAbsolutePath[128];
extern BigFileEntryPointer sBigFileEntryPointers[MAX_BIG_FILE_ENTRY_POINTERS];
extern char sBigFileEntryPointerPaths[MAX_BIG_FILE_ENTRY_POINTERS][256];
extern BigFileEntry *sBigFileHeader;
extern char sAbsolutePathTempString[256];

int find_bigfile_entry_by_path(char *path);
void read_data_file_internal(char *path, void *out);
FILE *open_data_file(char *path, char *mode);

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
        sprintf(absolutePath, str_pct_s, path);
        to_absolute_data_path2(absolutePath);
        
        // Read
        file = fopen(absolutePath, str_rb);
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
    
    // wtf? no return??
}

FILE *open_data_file_relative(char *path, char *mode) {
    int index = find_bigfile_entry_by_path(path);
    if (index < 0) {
        // Convert path to an absolute file path
        sprintf(sAbsolutePathTempString, str_pct_s, path);
        to_absolute_data_path2(sAbsolutePathTempString);

        return fopen(sAbsolutePathTempString, mode);
    }
    
    return open_data_file(path, mode);
}

FILE *open_data_file_absolute(char *path, char *mode) {
    int index = find_bigfile_entry_by_path(path);
    if (index < 0) {
        return fopen(path, mode);
    }
    
    return open_data_file(path, mode);
}

size_t read_data_file_partial(char *path, void *out, size_t length) {
    int index;
    FILE *file;
    size_t read;

    read = 0;

    index = find_bigfile_entry_by_path(path);
    if (index < 0) {
        // Convert path to an absolute file path
        sprintf(sAbsolutePathTempString, str_pct_s, path);
        to_absolute_data_path2(sAbsolutePathTempString);

        file = fopen(sAbsolutePathTempString, str_rb);
        if (file != NULL) {
            read = fread(out, length, 1, file);
            fclose(file);
        }

        return read;
    }

    file = fopen(path, str_rb);
    fseek(file, sBigFileHeader[index].byteOffset, SEEK_SET);
    fread(out, length, 1, file);
    read = fclose(file); // wtf?

    return read;
}

size_t get_data_file_length(char *path) {
    int index;
    FILE *file;
    size_t length;

    index = find_bigfile_entry_by_path(path);
    if (index < 0) {
        // Not in bigfile, read from file system

        // Convert path to an absolute file path
        sprintf(sAbsolutePathTempString, str_pct_s, path);
        to_absolute_data_path2(sAbsolutePathTempString);

        length = 0;
        file = fopen(sAbsolutePathTempString, str_rb);
        if (file != NULL) {
            fseek(file, 0, SEEK_END);
            length = ftell(file);
            fseek(file, 0, SEEK_SET);
            fclose(file);
        }

        return length;
    }

    // File is in bigfile, read size from loaded headers
    return sBigFileHeader[index].sizeBytes;
}

size_t write_bytes_to_file(const char *filename, const void *ptr, int length) {
    FILE *file;
    size_t bytesWritten;

    bytesWritten = 0;
    file = fopen(filename, str_wb);

    if (file != NULL) {
        if (length != 0) {
            bytesWritten = fwrite(ptr, 1, length, file);
        }
        fclose(file);
    }

    return bytesWritten;
}

/*static*/ char *pack_dword_for_bigfile_path_hash(char *str, unsigned int *out) {
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

/*static*/ unsigned int xor_hash_bigfile_entry_path(char *str) {
    unsigned int var2;
    unsigned int var1;

    var2 = 0;
    var1 = 0;
    
    while (*str != 0) {
        str = pack_dword_for_bigfile_path_hash(str, &var1);
        var2 ^= var1;
    }

    return var2;
}

void load_bigfile_header(char *path) {
    FILE *file;
    int i, j;
    char absolutePath[256];

    // Init sBigFileEntryPointers memory to 0xFFFFFFFF
    memset(sBigFileEntryPointers, 0xFFFFFFFF, sizeof(BigFileEntryPointer) * MAX_BIG_FILE_ENTRY_POINTERS);

    // Convert path to absolute
    sprintf(absolutePath, str_pct_s, path);
    to_absolute_data_path(absolutePath);
    sprintf(sBigFileAbsolutePath, str_pct_s, absolutePath);

    file = fopen(absolutePath, str_rb);
    if (file != NULL) {
        // Read entry count
        fread(&sBigFileEntryCount, 4, 1, file);

        // Free existing data if any
        if (sBigFileHeader != NULL) {
            custom_free(&sBigFileHeader);
        }

        // Allocate memory for just the header entries
        sBigFileHeader = (BigFileEntry*)custom_alloc(sBigFileEntryCount * sizeof(BigFileEntry));

        // Read header entries
        fread(sBigFileHeader, sBigFileEntryCount * sizeof(BigFileEntry), 1, file);
        fclose(file);

        // Convert paths to uppercase
        for (i = 0; i < sBigFileEntryCount; i++) {
            j = 0;
            while (sBigFileHeader[i].path[j] != '\0') {
                if (sBigFileHeader[i].path[j] >= 'a' && sBigFileHeader[i].path[j] <= 'z') {
                    sBigFileHeader[i].path[j] = sBigFileHeader[i].path[j] - 0x20;
                }

                j++;
            }

            sBigFileHeader[i].path[j] = '\0'; // redundant
        }

        // Done!
        sLoadedBigFileHeader = 1;
    }
}

static int find_bigfile_entry_by_path(char *path) {
    char pathCopy[256];
    int charIndex;
    int entryIndex;
    unsigned int hash;
    
    // If the bigfile.dat headers haven't been loaded, then there's nothing to search
    if (sLoadedBigFileHeader == 0) {
        return -1;
    }

    // Convert path to uppercase
    sprintf(pathCopy, str_pct_s_2, path);
    charIndex = 0;
    while (pathCopy[charIndex] != '\0') {
        if (pathCopy[charIndex] >= 'a' && pathCopy[charIndex] <= 'z') {
            pathCopy[charIndex] = pathCopy[charIndex] - 0x20;
        }
        charIndex++;
    }
    pathCopy[charIndex] = '\0';

    // Generate hash for requested path
    hash = xor_hash_bigfile_entry_path(pathCopy);

    // Find first bigfile entry with the same hash and path
    //
    // Note: We check the hash first to speed this up and only if that matches
    // do we double-check the full path string.
    entryIndex = 0;
    while (TRUE) {
        if (entryIndex >= sBigFileEntryCount) {
            entryIndex = -1;
            break;
        }

        if (hash == sBigFileHeader[entryIndex].pathHash) {
            if (strcmp(pathCopy, sBigFileHeader[entryIndex].path) == 0) {
                if (entryIndex >= sBigFileEntryCount) {
                    entryIndex = -1;
                }
                break;
            }
        }

        entryIndex++;
    }

    return entryIndex;
}

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
    file = fopen(sBigFileAbsolutePath, str_rb);
    fseek(file, sBigFileHeader[index].byteOffset, SEEK_SET);
    fread(out, sBigFileHeader[index].sizeBytes, 1, file);
    fclose(file);
}

FILE *open_data_file(char *path, char *mode) {
    int ptrIndex;
    int index;
    int i;
    FILE *file;

    index = find_bigfile_entry_by_path(path);
    
    if (index < 0) {
        // Path isn't in bigfile, just open from file system
        return fopen(path, mode);
    }

    // Open file in bigfile
    file = fopen(sBigFileAbsolutePath, str_rb);
    fseek(file, sBigFileHeader[index].byteOffset, SEEK_SET);

    // Find first entry pointer element that is free
    ptrIndex = 0;
    for (i = 0; i < MAX_BIG_FILE_ENTRY_POINTERS - 1; i++) { // wtf? why the - 1?
        if (sBigFileEntryPointers[i].file == (FILE*)0xFFFFFFFF) {
            break;
        }

        ptrIndex++;
    }

    // If there's a free slot, store information about the file
    if (ptrIndex < MAX_BIG_FILE_ENTRY_POINTERS) {
        sprintf(sBigFileEntryPointerPaths[ptrIndex], str_pct_s, path);
        sBigFileEntryPointers[ptrIndex].file = file;
        sBigFileEntryPointers[ptrIndex].position = 0;
        sBigFileEntryPointers[ptrIndex].sizeBytes = sBigFileHeader[index].sizeBytes;
        sBigFileEntryPointers[ptrIndex].byteOffset = sBigFileHeader[index].byteOffset;
    }

    return file;
}

void close_data_file(FILE *file) {
    int i;
    int ptrIndex;

    ptrIndex = 0;
    for (i = 0; i < MAX_BIG_FILE_ENTRY_POINTERS; i++) {
        if (sBigFileEntryPointers[i].file == file) {
            if (ptrIndex < MAX_BIG_FILE_ENTRY_POINTERS) {
                sBigFileEntryPointers[ptrIndex].file = (FILE*)0xFFFFFFFF;
                sBigFileEntryPointers[ptrIndex].position = 0xFFFFFFFF;
                sBigFileEntryPointers[ptrIndex].sizeBytes = 0xFFFFFFFF;
                sBigFileEntryPointers[ptrIndex].byteOffset = 0xFFFFFFFF;
            }

            fclose(file);
            return;
        }

        ptrIndex++;
    }

    fclose(file);
}

char *get_data_file_line(char *str, int length, FILE *file) {
    long filePos;
    char *ret;
    int ptrIndex;

    // Read next line
    filePos = ftell(file); // shouldn't this be *after* fgets for the below check to work?
    ret = fgets(str, length, file);

    if (ret != NULL) {
        // Find entry pointer element
        ptrIndex = 0;
        for (ptrIndex = 0; ptrIndex < MAX_BIG_FILE_ENTRY_POINTERS; ptrIndex++) {
            if (sBigFileEntryPointers[ptrIndex].file == file && sBigFileEntryPointers[ptrIndex].file != (FILE*)0xFFFFFFFF) {
                break;
            }
        }

        if (ptrIndex < MAX_BIG_FILE_ENTRY_POINTERS) {
            // Record file position
            sBigFileEntryPointers[ptrIndex].position = filePos - sBigFileEntryPointers[ptrIndex].byteOffset;

            // If we've gone past the file, force the the return value to null (fgets doesn't know about the
            // structure of bigfile and will happily read into a different entry).
            if (sBigFileEntryPointers[ptrIndex].position >= sBigFileEntryPointers[ptrIndex].sizeBytes) {
                ret = NULL;
            }
        }
    }

    return ret;
}
