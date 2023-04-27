#include <WINDOWS.H>
#include <STDIO.H>

#include "data.h"

extern char temp_string[1024]; // idk what the size is

extern void display_message(char *format, ...);
extern void game_exit();

void cd_check() {
    int retries = 0;
    BOOL flag = FALSE;
    FILE* file;

    while (TRUE) {
        sprintf(temp_string, "%sintro.mpg", "vids\\");

        if (get_data_file_length(temp_string)) {
            flag = TRUE;
        } else {
            display_message("Please insert the Real War CD\ninto the CD rom drive and\nselect OK to continue.");
        }

        if (flag) {
            sprintf(temp_string, "%scdtest.txt", "vids\\");

            file = fopen(temp_string, "wb");
            if (file != NULL) {
                flag = FALSE;
                fclose(file);
                _unlink(temp_string);
                display_message("Please insert the Real War CD\ninto the CD rom drive and\nselect OK to continue.");   
            } else if (flag) {
                return;
            }
        }

        if (++retries > 10) {
            game_exit();
        }
    }
}
