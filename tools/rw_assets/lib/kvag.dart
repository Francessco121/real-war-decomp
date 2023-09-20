import 'dart:math';
import 'dart:typed_data';

import 'src/utils.dart';

const _kvagAdpcmByteOffset = 0xe;

class KvagHeader {
  final String magic;
  final int size;
  final int sampleRate;
  final bool isStereo;

  KvagHeader(this.magic, this.size, this.sampleRate, this.isStereo);

  factory KvagHeader.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final magic = readNullTerminatedOrFullString(Uint8List.sublistView(bytes, 0, 4));
    final size = data.getUint32(4, Endian.little);
    final sampleRate = data.getUint32(8, Endian.little);
    final isStereo = data.getUint16(12, Endian.little);

    return KvagHeader(magic, size, sampleRate, isStereo == 1);
  }
}

/// Reads a KVAG file and returns its header information as well as decompresses
/// the 4-bit ADPCM data into 16-bit PCM.
/// 
/// If the file does not have a header, default header information will be generated
/// (this matches what the game does).
(KvagHeader, Uint8List) readKvagPcm(Uint8List kvagBytes) {
  final header = KvagHeader.fromBytes(kvagBytes);

  if (header.magic == 'KVAG') {
    final adpcmBytes = Uint8List.sublistView(kvagBytes, _kvagAdpcmByteOffset);
    
    final pcmBytes = header.isStereo
        ? _adpcmDecompressStereo(adpcmBytes)
        : _adpcmDecompressMono(adpcmBytes);
    
    return (header, pcmBytes);
  } else {
    // File doesn't have the KVAG header and is just raw mono ADPCM
    //
    // The game code defaults the sample rate to 22050 in this case
    final pcmBytes = _adpcmDecompressMono(kvagBytes);

    return (KvagHeader('', kvagBytes.lengthInBytes, 22050, false), pcmBytes);
  }
}

const _indexTable = <int>[
  -1,-1,-1,-1, 2, 4, 6, 8,
  -1,-1,-1,-1, 2, 4, 6, 8,
];
const _stepSizeTable = <int>[
  7, 8, 9, 10, 11, 12, 13,
  14, 16, 17, 19, 21, 23, 25, 28,
  31, 34, 37, 41, 45, 50, 55, 60,
  66, 73, 80, 88, 97, 107, 118,
  130, 143, 157, 173, 190, 209, 230,
  253, 279, 307, 337, 371, 408, 449,
  494, 544, 598, 658, 724, 796, 876,
  963, 1060, 1166, 1282, 1411, 1552,
  1707, 1878, 2066, 2272, 2499, 2749,
  3024, 3327, 3660, 4026, 4428, 4871,
  5358, 5894, 6484, 7132, 7845, 8630,
  9493, 10442, 11487, 12635, 13899,
  15289, 16818, 18500, 20350, 22385,
  24623, 27086, 29794, 32767,
];

Uint8List _adpcmDecompressMono(Uint8List adpcm) {
  final output = BytesBuilder();

  int index = 0;
  int predictor = 0;
  int step = _stepSizeTable[index];
  int nibbleIdx = 0;
  int i = 0, j = 0;
  int curByte = 0;

  while (i < (adpcm.lengthInBytes * 2)) {
    int nibble;
    if (nibbleIdx == 1) {
      nibble = curByte;
    } else {
      curByte = adpcm[j++];
      nibble = curByte >> 4;
    }

    nibble = nibble & 0xF;
    nibbleIdx = nibbleIdx == 0 ? 1 : 0;

    index += _indexTable[nibble];

    index = max(0, min(88, index));

    int signBit = nibble & 8;
    nibble = nibble & 7;

    int diff = step >> 3;
    if ((nibble & 4) != 0) diff += step;
    if ((nibble & 2) != 0) diff += (step >> 1);
    if ((nibble & 1) != 0) diff += (step >> 2);

    if (signBit != 0) {
      predictor -= diff;
    } else {
      predictor += diff;
    }

    predictor = max(-32768, min(32767, predictor));

    step = _stepSizeTable[index];
    output.addByte(predictor & 0xFF);
    output.addByte((predictor >> 8) & 0xFF);
    i++;
  }

  return output.takeBytes();
}

Uint8List _adpcmDecompressStereo(Uint8List adpcm) {
  final output = BytesBuilder();

  int index1 = 0;
  int predictor1 = 0;
  int step1 = _stepSizeTable[index1];

  int index2 = 0;
  int predictor2 = 0;
  int step2 = _stepSizeTable[index2];

  int i = 0, j = 0;

  while (i < adpcm.lengthInBytes) {
    int nibble1 = adpcm[j] & 0xF; // right channel
    int nibble2 = (adpcm[j++] >> 4) & 0xF; // left channel

    index1 += _indexTable[nibble1];
    index2 += _indexTable[nibble2];

    index1 = max(0, min(88, index1));
    index2 = max(0, min(88, index2));

    int signBit1 = nibble1 & 8;
    int signBit2 = nibble2 & 8;
    nibble1 = nibble1 & 7;
    nibble2 = nibble2 & 7;

    int diff1 = step1 >> 3;
    if ((nibble1 & 4) != 0) diff1 += step1;
    if ((nibble1 & 2) != 0) diff1 += (step1 >> 1);
    if ((nibble1 & 1) != 0) diff1 += (step1 >> 2);

    int diff2 = step2 >> 3;
    if ((nibble2 & 4) != 0) diff2 += step2;
    if ((nibble2 & 2) != 0) diff2 += (step2 >> 1);
    if ((nibble2 & 1) != 0) diff2 += (step2 >> 2);

    if (signBit1 != 0) {
      predictor1 -= diff1;
    } else {
      predictor1 += diff1;
    }

    if (signBit2 != 0) {
      predictor2 -= diff2;
    } else {
      predictor2 += diff2;
    }

    predictor1 = max(-32768, min(32767, predictor1));
    predictor2 = max(-32768, min(32767, predictor2));

    step1 = _stepSizeTable[index1];
    step2 = _stepSizeTable[index2];

    output.addByte(predictor2 & 0xFF);
    output.addByte((predictor2 >> 8) & 0xFF);
    output.addByte(predictor1 & 0xFF);
    output.addByte((predictor1 >> 8) & 0xFF);
    i++;
  }

  return output.takeBytes();
}
