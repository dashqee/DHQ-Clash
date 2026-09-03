// Windows ICO from PNG renders, with no package dependencies: this runs from
// the branding script, and an image library is not worth adding to the app for
// a build step.
//
// Every size gets its own entry so Windows never scales: the taskbar picks
// 24 or 32, Alt-Tab 32 or 48, the notification area 16 or 20. Small sizes are
// stored as 32-bit DIBs, the format every Windows reads; PNG payloads are kept
// for the large entries where the DIB would be a megabyte.
import 'dart:io';
import 'dart:typed_data';

class RgbaImage {
  final int width;
  final int height;

  /// Row-major RGBA, 4 bytes per pixel.
  final Uint8List pixels;

  const RgbaImage(this.width, this.height, this.pixels);
}

class IcoImage {
  final RgbaImage image;
  final Uint8List png;

  const IcoImage({required this.image, required this.png});
}

/// 8-bit, non-interlaced RGB or RGBA PNG — what rsvg-convert writes.
RgbaImage decodePng(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 8 ||
      !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v)) {
    throw const FormatException('not a PNG');
  }
  final data = ByteData.sublistView(bytes);
  int? width;
  int? height;
  int? bitDepth;
  int? colorType;
  int? interlace;
  final idat = BytesBuilder(copy: false);
  var offset = 8;
  while (offset + 8 <= bytes.length) {
    final length = data.getUint32(offset);
    final type = String.fromCharCodes(bytes, offset + 4, offset + 8);
    final start = offset + 8;
    if (type == 'IHDR') {
      width = data.getUint32(start);
      height = data.getUint32(start + 4);
      bitDepth = bytes[start + 8];
      colorType = bytes[start + 9];
      interlace = bytes[start + 12];
    } else if (type == 'IDAT') {
      idat.add(Uint8List.sublistView(bytes, start, start + length));
    } else if (type == 'IEND') {
      break;
    }
    offset = start + length + 4;
  }
  if (width == null || height == null) {
    throw const FormatException('PNG without IHDR');
  }
  if (bitDepth != 8 || interlace != 0 || (colorType != 6 && colorType != 2)) {
    throw const FormatException(
      'unsupported PNG: only 8-bit non-interlaced RGB/RGBA',
    );
  }
  final channels = colorType == 6 ? 4 : 3;
  final raw = Uint8List.fromList(ZLibDecoder().convert(idat.toBytes()));
  final stride = width * channels;
  final pixels = Uint8List(width * height * 4);
  var previous = Uint8List(stride);
  var position = 0;
  for (var y = 0; y < height; y++) {
    final filter = raw[position++];
    final row = Uint8List.fromList(
      Uint8List.sublistView(raw, position, position + stride),
    );
    position += stride;
    _unfilter(row, previous, filter, channels);
    for (var x = 0; x < width; x++) {
      final source = x * channels;
      final target = (y * width + x) * 4;
      pixels[target] = row[source];
      pixels[target + 1] = row[source + 1];
      pixels[target + 2] = row[source + 2];
      pixels[target + 3] = channels == 4 ? row[source + 3] : 255;
    }
    previous = row;
  }
  return RgbaImage(width, height, pixels);
}

void _unfilter(Uint8List row, Uint8List previous, int filter, int bpp) {
  for (var i = 0; i < row.length; i++) {
    final a = i >= bpp ? row[i - bpp] : 0;
    final b = previous[i];
    final c = i >= bpp ? previous[i - bpp] : 0;
    final predictor = switch (filter) {
      0 => 0,
      1 => a,
      2 => b,
      3 => (a + b) >> 1,
      4 => _paeth(a, b, c),
      _ => throw FormatException('unknown PNG filter $filter'),
    };
    row[i] = (row[i] + predictor) & 0xff;
  }
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

/// A minimal RGBA PNG, unfiltered rows — enough for tests to round-trip.
Uint8List encodePng(RgbaImage image) {
  final rows = BytesBuilder(copy: false);
  for (var y = 0; y < image.height; y++) {
    rows.add([0]);
    final start = y * image.width * 4;
    rows.add(Uint8List.sublistView(image.pixels, start, start + image.width * 4));
  }
  final header = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  final out = BytesBuilder(copy: false)
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', header.buffer.asUint8List()))
    ..add(_chunk('IDAT', Uint8List.fromList(ZLibEncoder().convert(rows.toBytes()))))
    ..add(_chunk('IEND', Uint8List(0)));
  return out.toBytes();
}

Uint8List _chunk(String type, Uint8List body) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  final crcInput = Uint8List(4 + body.length)
    ..setRange(0, 4, typeBytes)
    ..setRange(4, 4 + body.length, body);
  final out = ByteData(12 + body.length)
    ..setUint32(0, body.length)
    ..setUint32(8 + body.length, _crc32(crcInput));
  final bytes = out.buffer.asUint8List()
    ..setRange(4, 8, typeBytes)
    ..setRange(8, 8 + body.length, body);
  return bytes;
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// One ICO holding every [images] entry, smallest first.
///
/// Entries of [pngFromSize] pixels and up keep their PNG bytes; the rest are
/// written as 32-bit BGRA DIBs with an empty AND mask, since the alpha channel
/// already carries transparency.
Uint8List encodeIco(List<IcoImage> images, {int pngFromSize = 64}) {
  final sorted = [...images]
    ..sort((a, b) => a.image.width.compareTo(b.image.width));
  const headerSize = 6;
  const entrySize = 16;
  final payloads = [
    for (final entry in sorted)
      entry.image.width >= pngFromSize ? entry.png : _dib(entry.image),
  ];
  final directory = ByteData(headerSize + entrySize * sorted.length)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, sorted.length, Endian.little);
  var offset = headerSize + entrySize * sorted.length;
  for (var i = 0; i < sorted.length; i++) {
    final image = sorted[i].image;
    final base = headerSize + i * entrySize;
    directory
      ..setUint8(base, image.width >= 256 ? 0 : image.width)
      ..setUint8(base + 1, image.height >= 256 ? 0 : image.height)
      ..setUint8(base + 2, 0)
      ..setUint8(base + 3, 0)
      ..setUint16(base + 4, 1, Endian.little)
      ..setUint16(base + 6, 32, Endian.little)
      ..setUint32(base + 8, payloads[i].length, Endian.little)
      ..setUint32(base + 12, offset, Endian.little);
    offset += payloads[i].length;
  }
  final out = BytesBuilder(copy: false)..add(directory.buffer.asUint8List());
  for (final payload in payloads) {
    out.add(payload);
  }
  return out.toBytes();
}

Uint8List _dib(RgbaImage image) {
  final width = image.width;
  final height = image.height;
  final maskStride = ((width + 31) ~/ 32) * 4;
  final pixelBytes = width * height * 4;
  final maskBytes = maskStride * height;
  final out = ByteData(40 + pixelBytes + maskBytes)
    ..setUint32(0, 40, Endian.little)
    ..setInt32(4, width, Endian.little)
    ..setInt32(8, height * 2, Endian.little)
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, 32, Endian.little)
    ..setUint32(16, 0, Endian.little)
    ..setUint32(20, pixelBytes + maskBytes, Endian.little);
  var position = 40;
  for (var y = height - 1; y >= 0; y--) {
    for (var x = 0; x < width; x++) {
      final source = (y * width + x) * 4;
      out
        ..setUint8(position, image.pixels[source + 2])
        ..setUint8(position + 1, image.pixels[source + 1])
        ..setUint8(position + 2, image.pixels[source])
        ..setUint8(position + 3, image.pixels[source + 3]);
      position += 4;
    }
  }
  return out.buffer.asUint8List();
}
