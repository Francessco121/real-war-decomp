#include <STDARG.H>
#include <STDIO.H>

#include "log.h"

#define LOG_PRINT_BUFFER_LENGTH 0x10000

static FILE *logTxtFile = NULL;
static char logPrintBuffer[LOG_PRINT_BUFFER_LENGTH];

extern void display_message_and_exit(char* message);

void log_printlnf(char *format, ...) {
    va_list args;
    int length;
    int caller;

    GET_CALLER_ADDRESS(caller, 8);

    if (logTxtFile == NULL) {
        logTxtFile = fopen("modlog.txt", "w");

        if (logTxtFile == NULL) {
            display_message_and_exit("Failed to open modlog.txt.");
        }
    }

    length = sprintf(logPrintBuffer, "[%x] ", caller);
    fwrite(logPrintBuffer, 1, length, logTxtFile);

    va_start(args, format);
    length = vsprintf(logPrintBuffer, format, args); // really wish we had vfprintf :(
    va_end(args);

    if (length > LOG_PRINT_BUFFER_LENGTH) {
        display_message_and_exit("Log print buffer overflow :(");
    }

    fwrite(logPrintBuffer, 1, length, logTxtFile);
    fputs("\n", logTxtFile);
    fflush(logTxtFile);
}
