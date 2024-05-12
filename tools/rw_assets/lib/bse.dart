import 'dart:typed_data';

class Vert {
  final double x;
  final double y;
  final double z;

  Vert(this.x, this.y, this.z);
}

class Poly {
  final int v1;
  final int v2;
  final int v3;
  final int unk4;
  final int bseIndex;
  final int polyIndex;
  final int unk7;
  final int unk8;

  Poly(this.v1, this.v2, this.v3, this.unk4, this.bseIndex, 
      this.polyIndex, this.unk7, this.unk8);
}

class UV {
  final double u;
  final double v;

  UV(this.u, this.v);
}

class PolyUV {
  final UV v1;
  final UV v2;
  final UV v3;

  PolyUV(this.v1, this.v2, this.v3);
}

class RGB {
  final int r;
  final int g;
  final int b;

  RGB(this.r, this.g, this.b);
}

class PolyColor {
  final RGB v1;
  final RGB v2;
  final RGB v3;

  PolyColor(this.v1, this.v2, this.v3);
}

class Frame {
  final List<Vert> verts;

  Frame(this.verts);
}

class UVFrame {
  final List<PolyUV> uvs;

  UVFrame(this.uvs);
}

class Bse {
  final int numPolys;
  final int numVertices;
  final int numFrames;

  final List<Vert> vertices;
  final List<Poly> polys;
  final List<PolyColor> colors;
  final List<PolyUV> uvs;
  final List<int> flags;
  final List<Frame>? frames;
  final double scale;
  /// aka animated UVs
  final List<UVFrame>? uvFrames;

  Bse({
    required this.numPolys,
    required this.numVertices,
    required this.numFrames,
    required this.vertices,
    required this.polys,
    required this.colors,
    required this.uvs,
    required this.flags,
    required this.frames,
    required this.scale,
    required this.uvFrames,
  });
}

Bse readBse(Uint8List bseBytes) {
  final bseData = ByteData.sublistView(bseBytes);

  int i = 0;
  _assertMagic(bseBytes, i, 'BSE1');
  i += 4;

  final numPoly = bseData.getUint32(i, Endian.little);
  i += 4;
  final numVert = bseData.getUint32(i, Endian.little);
  i += 4;
  final numFrames = bseData.getUint32(i, Endian.little);
  i += 4;

  _assertMagic(bseBytes, i, 'VERT');
  i += 4;

  final verts = <Vert>[];
  for (int j = 0; j < numVert; j++) {
    final x = bseData.getFloat32(i, Endian.little);
    final y = bseData.getFloat32(i + 4, Endian.little);
    final z = bseData.getFloat32(i + 8, Endian.little);

    verts.add(Vert(x, y, z));

    i += (3 * 4);
  }

  _assertMagic(bseBytes, i, 'POLY');
  i += 4;

  final polygons = <Poly>[];
  for (int j = 0; j < numPoly; j++) {
    final v1 = bseData.getUint32(i, Endian.little);
    final v2 = bseData.getUint32(i + 4, Endian.little);
    final v3 = bseData.getUint32(i + 8, Endian.little);
    final unk4 = bseData.getUint32(i + 12, Endian.little);
    final bseIndex = bseData.getUint32(i + 16, Endian.little);
    final polyIndex = bseData.getUint32(i + 20, Endian.little);
    final unk7 = bseData.getUint32(i + 24, Endian.little);
    final unk8 = bseData.getUint32(i + 28, Endian.little);

    polygons.add(Poly(v1, v2, v3, unk4, bseIndex, polyIndex, unk7, unk8));

    i += (8 * 4);
  }

  _assertMagic(bseBytes, i, 'COLR');
  i += 4;

  final colors = <PolyColor>[];
  for (int j = 0; j < numPoly; j++) {
    final r1 = bseData.getUint8(i + 0);
    final g1 = bseData.getUint8(i + 1);
    final b1 = bseData.getUint8(i + 2);

    final r2 = bseData.getUint8(i + 3);
    final g2 = bseData.getUint8(i + 4);
    final b2 = bseData.getUint8(i + 5);

    final r3 = bseData.getUint8(i + 6);
    final g3 = bseData.getUint8(i + 7);
    final b3 = bseData.getUint8(i + 8);

    colors.add(PolyColor(RGB(r1, g1, b1), RGB(r2, g2, b2), RGB(r3, g3, b3)));

    i += 9;
  }

  _assertMagic(bseBytes, i, 'UVS0');
  i += 4;

  final uvs = <PolyUV>[];
  for (int j = 0; j < numPoly; j++) {
    final u1 = bseData.getFloat32(i + 0, Endian.little);
    final v1 = bseData.getFloat32(i + 4, Endian.little);

    final u2 = bseData.getFloat32(i + 8, Endian.little);
    final v2 = bseData.getFloat32(i + 12, Endian.little);

    final u3 = bseData.getFloat32(i + 16, Endian.little);
    final v3 = bseData.getFloat32(i + 20, Endian.little);

    uvs.add(PolyUV(UV(u1, v1), UV(u2, v2), UV(u3, v3)));

    i += (6 * 4);
  }

  _assertMagic(bseBytes, i, 'FLAG');
  i += 4;

  final flags = <int>[];
  for (int j = 0; j < numPoly; j++) {
    flags.add(bseData.getUint32(i, Endian.little));
    i += 4;
  }

  final List<Frame>? frames;
  if (numFrames != 0) {
    _assertMagic(bseBytes, i, 'FRMS');
    i += 4;

    frames = [];

    for (int j = 0; j < numFrames; j++) {
      final frameVerts = <Vert>[];

      for (int k = 0; k < numVert; k++) {
        final x = bseData.getFloat32(i, Endian.little);
        final y = bseData.getFloat32(i + 4, Endian.little);
        final z = bseData.getFloat32(i + 8, Endian.little);

        frameVerts.add(Vert(x, y, z));

        i += (3 * 4);
      }
    }
  } else {
    frames = null;
  }

  final double scale;
  if (i <= (bseBytes.lengthInBytes - 4) && _readMagic(bseBytes, i, 4) == 'SCAL') {
    i += 4;

    scale = bseData.getFloat32(i, Endian.little);
    i += 4;
  } else {
    scale = 1;
  }

  final List<UVFrame>? uvFrames;
  if (i <= (bseBytes.lengthInBytes - 4) && _readMagic(bseBytes, i, 4) == 'AUVS') {
    i += 4;

    uvFrames = [];

    for (int j = 0; j < numFrames; j++) {
      final frameUVs = <PolyUV>[];

      for (int k = 0; k < numPoly; k++) {
        final u1 = bseData.getFloat32(i + 0, Endian.little);
        final v1 = bseData.getFloat32(i + 4, Endian.little);

        final u2 = bseData.getFloat32(i + 8, Endian.little);
        final v2 = bseData.getFloat32(i + 12, Endian.little);

        final u3 = bseData.getFloat32(i + 16, Endian.little);
        final v3 = bseData.getFloat32(i + 20, Endian.little);

        frameUVs.add(PolyUV(UV(u1, v1), UV(u2, v2), UV(u3, v3)));

        i += (6 * 4);
      }
    }
  } else {
    uvFrames = null;
  }

  return Bse(
    numPolys: numPoly,
    numVertices: numVert,
    numFrames: numFrames,
    vertices: verts,
    polys: polygons,
    colors: colors,
    uvs: uvs,
    flags: flags,
    frames: frames,
    scale: scale,
    uvFrames: uvFrames,
  );
}

void _assertMagic(Uint8List bytes, int offset, String magic) {
  if (_readMagic(bytes, offset, magic.length) != magic) {
    throw Exception(
        'Expected magic $magic at file offset 0x${offset.toRadixString(16)}.');
  }
}

String _readMagic(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(
      Uint8List.sublistView(bytes, offset, offset + length));
}
