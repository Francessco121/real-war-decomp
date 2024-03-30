#include <D3D.H>

struct _strct {
    GUID guids[10];
    char names[10][50];
    char descriptions[10][256];
    int counter;
} s;

struct _s2 {
    int value;
} s2;

int array1[];
int array2[];
int array3[];
int array4[];

void single() {
    memcpy(&array1[s2.value], &array2[s2.value], 4);
    memcpy(&array3[s2.value], &array4[s2.value], 4);
}

void grouped(GUID *lpGuid, char *name, char *desc) {
    memcpy(&s.guids[0], lpGuid, sizeof(GUID));
    strcpy(&s.names[s.counter][0], name);
    strcpy(&s.descriptions[s.counter][0], desc);
    s.counter += 1;
}
