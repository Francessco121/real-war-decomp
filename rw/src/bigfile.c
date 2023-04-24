#include "WINDOWS.H"

// read_data_file

// FUN_004d6910

// FUN_004d6960

// FUN_004d69a0

// get_data_file_length

// FUN_004d6af0

// only called by some_kind_of_string_hash
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

unsigned int some_kind_of_string_hash(char *str) {
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

// FUN_004d6e30

// FUN_004d6eb0

// FUN_004d6f80

// FUN_004d6fe0
