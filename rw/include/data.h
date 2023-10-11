#pragma once

#include <STDIO.H>

#include "types.h"

/**
 * @file
 * @brief Functions for reading/writing from/to data files.
 * 
 * Data files are files found in either the data directory or in bigfile.dat.
 */

/**
 * Reads the bytes of a data file.
 * 
 * Returns the file length if the file was in the data directory. The return value is
 * *undefined* if the file was found in bigfile.dat.
 */
extern size_t read_data_file(const char *path, void *out);

/**
 * Opens a data file from a relative file path.
 */
extern FILE *open_data_file_relative(const char *path, const char *mode);

/**
 * Opens a data file. The given path will be used as-is.
 */
extern FILE *open_data_file_absolute(const char *path, const char *mode);

/**
 * Reads the first [length] bytes of a data file.
 */
extern size_t read_data_file_partial(const char *path, void *out, size_t length);

/**
 * Gets the length in bytes of a data file.
 * 
 * If the file was not found, returns 0.
 */
extern size_t get_data_file_length(const char *path);

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
extern size_t write_bytes_to_file(const char *filename, const void *ptr, size_t length);

/**
 * Loads the headers of bigfile.dat.
 */
extern void load_bigfile_header(const char *path);

/**
 * Opens a data file.
 */
extern FILE *open_data_file(const char *path, const char *mode);

/**
 * Closes a data file.
 */
extern void close_data_file(FILE *file);

/**
 * Reads the next line from the data file.
 * 
 * Returns NULL if the end of the file was reached.
 */
extern char *get_data_file_line(char *str, int32 length, FILE *file);
