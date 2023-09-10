#include <STDARG.H>
#include <STDIO.H>

#include "log.h"

#define LOG_PRINT_BUFFER_LENGTH 0x10000

static FILE *logTxtFile = NULL;
static char logPrintBuffer[LOG_PRINT_BUFFER_LENGTH];

extern void display_message_and_exit(char* message);
extern int _fflush_lk(FILE *stream); // this might actually just be fflush but i gave it the wrong symbol name

void log_printf(char *format, ...) {
    va_list args;
    int length;

    if (logTxtFile == NULL) {
        logTxtFile = fopen("modlog.txt", "w");

        if (logTxtFile == NULL) {
            display_message_and_exit("Failed to open modlog.txt.");
        }
    }

    va_start(args, format);
    length = vsprintf(logPrintBuffer, format, args); // really wish we had vfprintf :(
    va_end(args);

    if (length > LOG_PRINT_BUFFER_LENGTH) {
        display_message_and_exit("Log print buffer overflow :(");
    }

    fwrite(logPrintBuffer, 1, length, logTxtFile);
    _fflush_lk(logTxtFile);
}
