#include "WINDOWS.H"
#include "STDIO.H"

char intro_cd_path[1024]; // idk what the size is

long func_004d6a60(char* file_path);
void display_message(char *format, ...);
void game_exit();

void cd_check() {
    int retries = 0;
    BOOL flag = FALSE;
    FILE* file;

    while (TRUE) {
        sprintf(intro_cd_path, "%sintro.mpg", "vids\\");

        if (func_004d6a60(intro_cd_path)) {
            flag = TRUE;
        } else {
            display_message("Please insert the Real War CD\ninto the CD rom drive and\nselect OK to continue.");
        }

        if (flag) {
            sprintf(intro_cd_path, "%scdtest.txt", "vids\\");

            file = fopen(intro_cd_path, "wb");
            if (file != NULL) {
                flag = FALSE;
                fclose(file);
                _unlink(intro_cd_path);
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
