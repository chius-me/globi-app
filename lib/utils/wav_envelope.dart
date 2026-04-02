import 'dart:math' as math;
import 'dart:typed_data';

const int kWaveEnvelopeBucketMillis = 70;

List<double> extractWaveEnvelope(
  Uint8List wavBytes, {
  int bucketMillis = kWaveEnvelopeBucketMillis,
}) {
  final header = _parseWavHeader(wavBytes);
  if (header == null ||
      header.audioFormat != 1 ||
      header.bitsPerSample != 16 ||
      header.sampleRate <= 0 ||
      header.channelCount <= 0 ||
      bucketMillis <= 0) {
    return const [];
  }

  final bytesPerFrame = header.channelCount * (header.bitsPerSample ~/ 8);
  if (bytesPerFrame <= 0 || header.dataLength < bytesPerFrame) {
    return const [];
  }

  final frameCount = header.dataLength ~/ bytesPerFrame;
  final framesPerBucket = math.max(
    1,
    (header.sampleRate * bucketMillis) ~/ 1000,
  );
  final byteData = ByteData.sublistView(wavBytes);
  final levels = <double>[];

  var frameOffset = header.dataOffset;
  var frameIndex = 0;

  while (frameIndex < frameCount) {
    final bucketEnd = math.min(frameIndex + framesPerBucket, frameCount);
    var sumSquares = 0.0;
    var samples = 0;

    while (frameIndex < bucketEnd) {
      var framePeak = 0.0;

      for (var channel = 0; channel < header.channelCount; channel++) {
        final sample = byteData.getInt16(frameOffset, Endian.little);
        final normalized = sample.abs() / 32768.0;
        if (normalized > framePeak) {
          framePeak = normalized;
        }
        frameOffset += 2;
      }

      sumSquares += framePeak * framePeak;
      samples += 1;
      frameIndex += 1;
    }

    final rms = samples == 0 ? 0.0 : math.sqrt(sumSquares / samples);
    levels.add(math.pow(rms.clamp(0.0, 1.0), 0.65).toDouble());
  }

  return levels;
}

_WavHeader? _parseWavHeader(Uint8List wavBytes) {
  if (wavBytes.lengthInBytes < 44) {
    return null;
  }

  final bytes = ByteData.sublistView(wavBytes);
  if (_readAscii(wavBytes, 0, 4) != 'RIFF' ||
      _readAscii(wavBytes, 8, 4) != 'WAVE') {
    return null;
  }

  var audioFormat = 0;
  var channelCount = 0;
  var sampleRate = 0;
  var bitsPerSample = 0;
  var dataOffset = -1;
  var dataLength = 0;
  var offset = 12;

  while (offset + 8 <= wavBytes.lengthInBytes) {
    final chunkId = _readAscii(wavBytes, offset, 4);
    final chunkSize = bytes.getUint32(offset + 4, Endian.little);
    final chunkDataOffset = offset + 8;
    final nextOffset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);

    if (nextOffset > wavBytes.lengthInBytes) {
      break;
    }

    if (chunkId == 'fmt ' && chunkSize >= 16) {
      audioFormat = bytes.getUint16(chunkDataOffset, Endian.little);
      channelCount = bytes.getUint16(chunkDataOffset + 2, Endian.little);
      sampleRate = bytes.getUint32(chunkDataOffset + 4, Endian.little);
      bitsPerSample = bytes.getUint16(chunkDataOffset + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkDataOffset;
      dataLength = chunkSize;
      break;
    }

    offset = nextOffset;
  }

  if (dataOffset < 0 || dataLength <= 0) {
    return null;
  }

  return _WavHeader(
    audioFormat: audioFormat,
    channelCount: channelCount,
    sampleRate: sampleRate,
    bitsPerSample: bitsPerSample,
    dataOffset: dataOffset,
    dataLength: dataLength,
  );
}

String _readAscii(Uint8List bytes, int start, int length) {
  return String.fromCharCodes(bytes.sublist(start, start + length));
}

class _WavHeader {
  final int audioFormat;
  final int channelCount;
  final int sampleRate;
  final int bitsPerSample;
  final int dataOffset;
  final int dataLength;

  const _WavHeader({
    required this.audioFormat,
    required this.channelCount,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataLength,
  });
}
