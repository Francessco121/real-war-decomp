#include <WINDOWS.H>
#include <STDIO.H>

#include "data.h"
#include "strings.h"
#include "undefined.h"

void cd_check() {
    int retries = 0;
    BOOL flag = FALSE;
    FILE* file;

    while (TRUE) {
        sprintf(gTempString, str_pct_intro_mpg, str_vids_slash);

        if (get_data_file_length(gTempString)) {
            flag = TRUE;
        } else {
            display_message(str_please_insert_the_cd);
        }

        if (flag) {
            sprintf(gTempString, str_pct_cdtest_txt, str_vids_slash);

            file = fopen(gTempString, str_wb);
            if (file != NULL) {
                flag = FALSE;
                fclose(file);
                remove(gTempString);
                display_message(str_please_insert_the_cd);   
            } else if (flag) {
                return;
            }
        }

        if (++retries > 10) {
            game_exit();
        }
    }
}
