#include "MEMORY.H"

#define bzero(buf) {                    \
    int i;                              \
    for (i = 0; i < sizeof(buf); i++) { \
        buf[i] = 0;                     \
    }                                   \
}

void do_thing(int* buf) {
    int i;
    int buffer[512];
    bzero(buffer)

    for (i = 0; i < sizeof(buffer); i++) {
        buffer[i] = buf[i] + 1;
    }

    memcpy(buf, buffer, sizeof(buffer));
}

void main() {
    int i;
    int buffer[512];
    bzero(buffer);

    do_thing(buffer);
}
