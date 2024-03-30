extern int a;
extern int b;
extern int c;
extern int d;
extern int e;
extern int a_arr[];
extern int b_arr[];
extern int c_arr[];
extern void branch(int v);
extern void branch1();
extern void branch2();
extern void branch3();
extern void branch4();
extern void branch5();
extern void end();

void example1() {
    if (a) {
        branch1();
    } else if (b) {
        branch2();
    } else if (c) {
        branch3();
    } else {
        branch4();
    }
}

void example2() {
    if (a || b) {
        branch1();
    } else {
        branch2();
    }
}

void example3() {
    if (a || b) {
        branch1();
    } else if (c) {
        branch2();
    } else {
        branch3();
    }
}

void example4() {
    if (a && b) {
        branch1();
    } else if (c) {
        branch2();
    } else {
        branch3();
    }
}

void example5() {
    /*
    ASSEMBLY:

    L_1:
    if (a != 4)
        goto L_2
    if (b == 4)
        goto L_3
    branch1()
    goto L_4
    
    L_2:
    if (a != 2)
        goto L_3
    if (b == 2)
        goto L_3
    branch2()
    goto L_4
    
    L_3:
    branch3()
    
    L_4:
    end()
    */

    /*
    TRUTH TABLE:

    branch1():
        a == 4 && b != 4
    branch2():
        a != 4 && a == 2 && b != 2
    branch3():
        a == 4 && b == 4
        a != 4 && (a != 2 || b == 2)
    */

    if (a == 4 && b != 4) {
        branch1();
    } else if (a == 2 && b != 2) {
        branch2();
    } else if ((a == 4 && b == 4) || (a != 4 && (a != 2 || b == 2))) {
        branch3();
    }

    end();
}

void example6() {
    /*
    ASSEMBLY:

    L_1:
    if (a == b)
        goto L_end
    if (a < 0)
        goto L_3
    if (c == 0)
        goto L_2
    branch1()
    goto L_end

    L_2:
    branch2()
    goto L_end
    
    L_3:
    if (a == b)
        goto L_end
    branch3()

    L_end:
    end()
    */

    /*
    TRUTH TABLE:
    
    branch1():
        a != b && a >= 0 && c != 0
    branch2():
        a != b && a >= 0 && c == 0
    branch3():
        a != b && a < 0 && a != b
    */

    int tmp;

    tmp = a_arr[a];
    if (tmp != b) {
        if (tmp >= 0) {
            if (c != 0) {
                branch1();
            } else {
                branch2();
            }
        // duplicate condition isn't optimized out if the value is
        // from a different variable, in this case a compiler temporary
        // (result of expression a_arr[a] vs our tmp local)
        } else if (a_arr[a] != b) {
            branch3();
        }

    }

    end();
}
