class Test {
public:
    int test(int a, int b);
    int biggerTest(int *a, int *b, int c);
    int get();
private:
    int data;
};

int Test::test(int a, int b) {
    return a + b;
}

int Test::get() {
    return this->data;
}

int Test::biggerTest(int *a, int *b, int c) {
    for (int i = 0; i < 10; i++) {
        a[i] = c;
        b[i] = c;
    }

    return c;
}
