#include <D3D.H>

GUID guids[10];
char names[10][50];
char descriptions[10][256];
int counter = 1;

int value;

int array1[];
int array2[];
int array3[];
int array4[];

void single() {
    memcpy(&array1[value], &array2[value], 4);
    memcpy(&array3[value], &array4[value], 4);
}

void ungrouped(GUID *lpGuid, char *name, char *desc) {
    memcpy(&guids[0], lpGuid, sizeof(GUID));
    strcpy(&names[counter][0], name);
    strcpy(&descriptions[counter][0], desc);
    counter += 1;
}
