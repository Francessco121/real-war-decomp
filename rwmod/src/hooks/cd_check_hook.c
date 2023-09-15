// For convenience, just remove the CD check since it's not needed to run the game.
//
// The game included this check as a form of DRM but given how insanely trivial it is to
// fake a CD by mounting the game ISO, it just makes working with the game a pain. Feel
// free to comment this out if you think it's wrong to patch this. :)

#include "log.h"

#define LOG_CD_CHECK 0

void cd_check_hook() {
#if LOG_CD_CHECK
    int caller;
    GET_CALLER_ADDRESS(caller, 8);

    log_printlnf("skipping CD check from %x", caller);
#endif
}
