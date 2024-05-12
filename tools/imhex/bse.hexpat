import std.core;

struct Vert {
    float x;
    float y;
    float z;
};

struct Poly {
    u32 v1; // vertex indices
    u32 v2;
    u32 v3;
    u32 unk4; // object id?
    u32 bseIndex; // unused in file
    u32 polyIdx;
    u32 unk7; // color?
    u32 unk8;
};

struct RGB {
    u8 r;
    u8 g;
    u8 b;
};

struct PolyColor {
    RGB v1;
    RGB v2;
    RGB v3;
};

struct UV {
    float u;
    float v;
};

struct PolyUV {
    UV v1;
    UV v2;
    UV v3;
};

struct Frame {
    Vert verts[parent.numVert];
};

struct UVFrame {
    PolyUV uvs[parent.numPoly];
};

struct BSE {
    char bseMagic[4];
    u32 numPoly;
    u32 numVert;
    u32 numFrms;
    
    char vertMagic[4];
    Vert verts[numVert];
    
    char polyMagic[4];
    Poly polys[numPoly];
    
    char colorMagic[4];
    PolyColor colors[numPoly];
    
    char uvsMagic[4];
    PolyUV uvs[numPoly];
    
    char flagsMagic[4];
    u32 flags[numPoly];
    
    if (numFrms != 0) {
        char frmsMagic[4];
        Frame frames[numFrms];
    }
    
    if (std::mem::read_unsigned($ + 0, 1) == 'S' &&
        std::mem::read_unsigned($ + 1, 1) == 'C' &&
        std::mem::read_unsigned($ + 2, 1) == 'A' &&
        std::mem::read_unsigned($ + 3, 1) == 'L'
    ) {
        char scaleMagic[4];
        float scale;
    }
    
    if (std::mem::read_unsigned($ + 0, 1) == 'A' &&
        std::mem::read_unsigned($ + 1, 1) == 'U' &&
        std::mem::read_unsigned($ + 2, 1) == 'V' &&
        std::mem::read_unsigned($ + 3, 1) == 'S'
    ) {
        char auvsMagic[4];
        UVFrame auvs[numFrms];
    }
};

BSE bse @ 0x0;