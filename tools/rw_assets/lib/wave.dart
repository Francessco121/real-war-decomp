import 'dart:typed_data';

import 'src/utils.dart';

Uint8List makePcmWaveFile(Uint8List pcmBytes, {
  required int sampleRate, 
  required int bitsPerSample,
  required int numChannels,
}) {
  final builder = BytesBuilder(copy: false);
  builder.addAsciiString('RIFF', nullTerminate: false); // RIFF magic
  builder.addUint32(pcmBytes.lengthInBytes + 36);       // Wave file size
  builder.addAsciiString('WAVE', nullTerminate: false); // WAVE magic

  builder.addAsciiString('fmt ', nullTerminate: false); // Format chunk magic
  builder.addUint32(16); // Length of format data (16 = PCM)
  builder.addUint16(1);  // Format tag (1 = PCM)
  builder.addUint16(numChannels); // Channel count
  builder.addUint32(sampleRate);  // Samples per second
  builder.addUint32((sampleRate * numChannels * bitsPerSample) ~/ 8); // Data rate
  builder.addUint16((numChannels * bitsPerSample) ~/ 8);              // Block align
  builder.addUint16(bitsPerSample); // Bits per sample

  builder.addAsciiString('data', nullTerminate: false); // Data chunk magic
  builder.addUint32(pcmBytes.lengthInBytes);            // Data chunk size
  builder.add(pcmBytes); // Data bytes (PCM in our case)

  return builder.takeBytes();
}
