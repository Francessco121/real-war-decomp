// For convenience, just remove the CD check since it's not needed to run the game.
//
// The game included this check as a form of DRM but given how insanely trivial it is to
// fake a CD by mounting the game ISO, it just makes working with the game a pain. Feel
// free to comment this out if you think it's wrong to patch this. :)

extern void display_message(char *format, ...);

void cd_check() {
    display_message("hello world!");
}
