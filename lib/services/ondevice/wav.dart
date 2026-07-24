import 'dart:io';
import 'dart:typed_data';

/// أدوات WAV مشتركة بين TTS و STT — بلا اعتماد على أي مكتبة خارجية.

/// يرمّز عيّنات Float32 [-1,1] إلى WAV (PCM 16-bit أحادي).
Uint8List encodeWavPcm16(Float32List samples, int sampleRate) {
  final n = samples.length;
  final dataSize = n * 2;
  final out = BytesBuilder();

  void putStr(String v) => out.add(v.codeUnits);
  void putU32(int v) => out.add(
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void putU16(int v) => out.add(
      (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  putStr('RIFF');
  putU32(36 + dataSize);
  putStr('WAVE');
  putStr('fmt ');
  putU32(16); // حجم كتلة fmt
  putU16(1); // PCM
  putU16(1); // قناة واحدة
  putU32(sampleRate);
  putU32(sampleRate * 2); // بايت/ثانية
  putU16(2); // block align
  putU16(16); // bits per sample
  putStr('data');
  putU32(dataSize);

  final pcm = ByteData(dataSize);
  for (var i = 0; i < n; i++) {
    final s = (samples[i] * 32767.0).clamp(-32768.0, 32767.0).toInt();
    pcm.setInt16(i * 2, s, Endian.little);
  }
  out.add(pcm.buffer.asUint8List());
  return out.toBytes();
}

/// نتيجة قراءة WAV.
class WavData {
  final Float32List samples;
  final int sampleRate;
  const WavData(this.samples, this.sampleRate);
}

/// يقرأ WAV (PCM 16-bit) ويعيد عيّنات Float32 [-1,1].
/// يتعامل مع كتل إضافية (LIST/fact) بالمرور عليها حتى كتلة data.
WavData readWavPcm16(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 44) {
    throw const FormatException('ملف WAV قصير أو تالف');
  }
  final bd = ByteData.sublistView(bytes);

  final isRiff = bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46;
  if (!isRiff) throw const FormatException('ليس ملف WAV صالحاً');

  var sampleRate = bd.getUint32(24, Endian.little);
  var bitsPerSample = 16;
  var channels = 1;
  var dataOffset = -1;
  var dataSize = 0;

  var i = 12;
  while (i + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(i, i + 4));
    final size = bd.getUint32(i + 4, Endian.little);
    if (id == 'fmt ') {
      channels = bd.getUint16(i + 10, Endian.little);
      sampleRate = bd.getUint32(i + 12, Endian.little);
      bitsPerSample = bd.getUint16(i + 22, Endian.little);
    } else if (id == 'data') {
      dataOffset = i + 8;
      dataSize = size;
      break;
    }
    i += 8 + size + (size.isOdd ? 1 : 0);
  }

  if (dataOffset < 0) throw const FormatException('لم تُوجد كتلة data');
  if (bitsPerSample != 16) {
    throw FormatException('يُدعم PCM 16-bit فقط (وُجد $bitsPerSample-bit)');
  }
  if (dataOffset + dataSize > bytes.length) {
    dataSize = bytes.length - dataOffset; // ملف مقطوع — اقرأ المتاح
  }

  final totalFrames = dataSize ~/ (2 * channels);
  final out = Float32List(totalFrames);
  for (var f = 0; f < totalFrames; f++) {
    if (channels == 1) {
      out[f] = bd.getInt16(dataOffset + f * 2, Endian.little) / 32768.0;
    } else {
      // اخلط القنوات إلى أحادية (Whisper يتوقّع mono)
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        sum += bd.getInt16(dataOffset + (f * channels + c) * 2, Endian.little) /
            32768.0;
      }
      out[f] = sum / channels;
    }
  }
  return WavData(out, sampleRate);
}
