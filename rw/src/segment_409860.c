#include "types.h"
#include "undefined.h"

void mul_mat3_vec3(Matrix3x3 *m, float32 *x, float32 *y, float32 *z) {
    // This might be inline assembly in the original code
    float x_, y_, z_;

    x_ = *x;
    y_ = *y;
    z_ = *z;

    *x = x_ * m->m00 + y_ * m->m01 + z_ * m->m02;
    *y = x_ * m->m10 + y_ * m->m11 + z_ * m->m12;
    *z = x_ * m->m20 + y_ * m->m21 + z_ * m->m22;
}
