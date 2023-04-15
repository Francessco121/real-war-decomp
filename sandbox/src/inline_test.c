void add(int* a, int b) {
    *a += b;
}

int do_thing(int l) {
    int i;
    int a = 0;

    for (i = 0; i < l; i++) {
        add(&a, i);
    }

    return a;
}

__inline void add_inline(int* a, int b) {
    *a += b;
}

int do_thing_inline(int l) {
    int i;
    int a = 0;

    for (i = 0; i < l; i++) {
        add_inline(&a, i);
    }

    return a;
}

int get();
int get2();
void foo();
void bar(int*);

int check(int* v) {
    int v2 = get2();
    bar(&v2);

    return *v == v2;
}

void short_circuit() {
    int v = get();

    if (check(&v)) {
        return;
    }

    foo();
}

__inline int check_inline(int* v) {
    int v2 = get2();
    bar(&v2);

    return *v == v2;
}

void short_circuit_inline() {
    int v = get();

    if (check_inline(&v)) {
        return;
    }

    foo();
}

