import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:rw_assets/image_utils.dart';
import 'package:rw_assets/texture_utils.dart';
import 'package:rw_assets/tgc.dart';

import 'bse.dart';

/// Converts the base model of a BSE file to a GLTF file.
/// 
/// Animations are not exported and per-triangle flags are ignored.
Map<String, dynamic> bseToGltf(Bse bse, [DecodedTgcFile? texture]) {
  // Create buffers for vertices, UVs, and colors
  double minX = 0;
  double minY = 0;
  double minZ = 0;

  double maxX = 0;
  double maxY = 0;
  double maxZ = 0;

  final vertBuffer = ByteData(bse.polys.length * 3 * 3 * 4);
  final uvBuffer = ByteData(bse.polys.length * 3 * 2 * 4);
  final colorBuffer = ByteData(bse.polys.length * 3 * 3 * 4);

  for (final (i, poly) in bse.polys.indexed) {
    final v1 = bse.vertices[poly.v1 ~/ 3];
    final v2 = bse.vertices[poly.v2 ~/ 3];
    final v3 = bse.vertices[poly.v3 ~/ 3];

    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 0, v1.x * bse.scale, Endian.little);
    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 4, -v1.z * bse.scale, Endian.little);
    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 8, v1.y * bse.scale, Endian.little);

    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 12, v2.x * bse.scale, Endian.little);
    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 16, -v2.z * bse.scale, Endian.little);
    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 20, v2.y * bse.scale, Endian.little);

    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 24, v3.x * bse.scale, Endian.little);
    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 28, -v3.z * bse.scale, Endian.little);
    vertBuffer.setFloat32((i * (3 * 3 * 4)) + 32, v3.y * bse.scale, Endian.little);

    final uvs = bse.uvs[i];

    uvBuffer.setFloat32((i * (3 * 2 * 4)) + 0, uvs.v1.u, Endian.little);
    uvBuffer.setFloat32((i * (3 * 2 * 4)) + 4, uvs.v1.v, Endian.little);

    uvBuffer.setFloat32((i * (3 * 2 * 4)) + 8, uvs.v2.u, Endian.little);
    uvBuffer.setFloat32((i * (3 * 2 * 4)) + 12, uvs.v2.v, Endian.little);

    uvBuffer.setFloat32((i * (3 * 2 * 4)) + 16, uvs.v3.u, Endian.little);
    uvBuffer.setFloat32((i * (3 * 2 * 4)) + 20, uvs.v3.v, Endian.little);

    final colors = bse.colors[i];

    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 0, colors.v1.r / 255.0, Endian.little);
    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 4, colors.v1.g / 255.0, Endian.little);
    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 8, colors.v1.b / 255.0, Endian.little);

    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 12, colors.v2.r / 255.0, Endian.little);
    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 16, colors.v2.g / 255.0, Endian.little);
    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 20, colors.v2.b / 255.0, Endian.little);

    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 24, colors.v3.r / 255.0, Endian.little);
    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 28, colors.v3.g / 255.0, Endian.little);
    colorBuffer.setFloat32((i * (3 * 3 * 4)) + 32, colors.v3.b / 255.0, Endian.little);

    minX = min(minX, v1.x);
    minX = min(minX, v2.x);
    minX = min(minX, v3.x);
    minY = min(minY, v1.y);
    minY = min(minY, v2.y);
    minY = min(minY, v3.y);
    minZ = min(minZ, v1.z);
    minZ = min(minZ, v2.z);
    minZ = min(minZ, v3.z);

    maxX = max(maxX, v1.x);
    maxX = max(maxX, v2.x);
    maxX = max(maxX, v3.x);
    maxY = max(maxY, v1.y);
    maxY = max(maxY, v2.y);
    maxY = max(maxY, v3.y);
    maxZ = max(maxZ, v1.z);
    maxZ = max(maxZ, v2.z);
    maxZ = max(maxZ, v3.z);
  }

  // Encode texture as a PNG
  Uint8List? texturePng;
  if (texture != null) {
    final imageBytes = Uint8List.fromList(texture.imageBytes);
    maskOutBlackPixels(imageBytes);

    texturePng = encodePng(Image.fromBytes(
      width: texture.header.width,
      height: texture.header.height,
      bytes: argb1555ToRgba8888(imageBytes).buffer,
      format: Format.uint8,
      numChannels: 4,
      order: ChannelOrder.rgba));
  }

  // Create GLTF
  final gltf = <String, dynamic>{};

  // GLTF version
  gltf['asset'] = {
    'version': '2.0'
  };

  // Single scene with single node/mesh
  gltf['scene'] = 0;
  gltf['scenes'] = [
    {
      'nodes': [0]
    }
  ];
  gltf['nodes'] = [
    {
      'mesh': 0
    }
  ];
  gltf['meshes'] = [
    {
      'primitives': [
        {
          'attributes': {
            'POSITION': 0,
            'TEXCOORD_0': 1,
            'COLOR_0': 2
          },
          'material': 0,
        }
      ]
    }
  ];

  // Buffers, views, accessors for vertices, UVs, and colors
  gltf['buffers'] = [
    {
      'uri': 'data:application/octet-stream;base64,${base64.encode(vertBuffer.buffer.asUint8List())}',
      'byteLength': vertBuffer.lengthInBytes
    },
    {
      'uri': 'data:application/octet-stream;base64,${base64.encode(uvBuffer.buffer.asUint8List())}',
      'byteLength': uvBuffer.lengthInBytes
    },
    {
      'uri': 'data:application/octet-stream;base64,${base64.encode(colorBuffer.buffer.asUint8List())}',
      'byteLength': colorBuffer.lengthInBytes
    },
  ];

  gltf['bufferViews'] = [
    {
      'buffer': 0,
      'byteOffset': 0,
      'byteLength': vertBuffer.lengthInBytes,
      'target': 34962 // ARRAY_BUFFER
    },
    {
      'buffer': 1,
      'byteOffset': 0,
      'byteLength': uvBuffer.lengthInBytes,
      'target': 34962 // ARRAY_BUFFER
    },
    {
      'buffer': 2,
      'byteOffset': 0,
      'byteLength': colorBuffer.lengthInBytes,
      'target': 34962 // ARRAY_BUFFER
    }
  ];

  gltf['accessors'] = [
    {
      'bufferView': 0,
      'byteOffset': 0,
      'componentType': 5126, // FLOAT
      'count': bse.polys.length * 3,
      'type': 'VEC3',
      'min': [minX, -minZ, minY],
      'max': [maxX, -maxZ, maxY],
    },
    {
      'bufferView': 1,
      'byteOffset': 0,
      'componentType': 5126, // FLOAT
      'count': bse.polys.length * 3,
      'type': 'VEC2'
    },
    {
      'bufferView': 2,
      'byteOffset': 0,
      'componentType': 5126, // FLOAT
      'count': bse.polys.length * 3,
      'type': 'VEC3',
      'min': [0, 0, 0],
      'max': [1, 1, 1],
    }
  ];

  // Texture image, sampler, material if the model has a texture
  if (texturePng != null) {
    gltf['images'] = [
      {
        'uri': 'data:image/png;base64,${base64.encode(texturePng)}',
      }
    ];

    gltf['samplers'] = [
      {
        'magFilter': 9728, // NEAREST
        'minFilter': 9728, // NEAREST
      }
    ];

    gltf['textures'] = [
      {
        'sampler': 0,
        'source': 0
      }
    ];

    gltf['materials'] = [
      {
        'pbrMetallicRoughness': {
          'baseColorTexture': {
            'index': 0
          }
        },
        'alphaMode': 'MASK',
        'alphaCutoff': 0.5
      }
    ];
  } else {
    gltf['materials'] = [
      {
        'alphaMode': 'MASK',
        'alphaCutoff': 0.5
      }
    ];
  }

  return gltf;
}
