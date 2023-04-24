#pragma once

typedef struct BigFileEntry {
    char path[64];
    unsigned int pathHash;
    // File pointer in bigfile.dat
    int byteOffset;
    int sizeBytes;
} BigFileEntry;

/**
 * Reads the bytes of a data file (a file either in bigfile.dat or in the data directory).
 * 
 * Returns the file length if the file was in the data directory. The return value is
 * always zero if the file was found in bigfile.dat.
 */
size_t read_data_file(char *path, void *out);

/**
 * Creates/overwrites a file with the given byte data.
 * 
 * If the file could not be opened then this function does nothing.
 * 
 * [filename] - Path to the file to write to.
 * [ptr] - Pointer to bytes to write.
 * [length] - Number of bytes to write.
 * 
 * Returns the number of bytes successfully written.
 */
size_t write_bytes_to_file(const char *filename, const void *ptr, int length);
