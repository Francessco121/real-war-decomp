void set(int* ptr) {
    *ptr = 5;
}

void main() {
    int a;
    set(&a);
}