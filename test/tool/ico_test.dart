import 'dart:typed_data';

import 'package:test/test.dart';

import '../../tool/ico.dart';

RgbaImage solid(int size, List<int> rgba) {
  final pixels = Uint8List(size * size * 4);
  for (var i = 0; i < size * size; i++) {
    pixels.setRange(i * 4, i * 4 + 4, rgba);
  }
  return RgbaImage(size, size, pixels);
}

void main() {
  test('PNG round-trips through the encoder and decoder', () {
    final image = RgbaImage(
      2,
      2,
      Uint8List.fromList([
        255, 0, 0, 255, //
        0, 255, 0, 128, //
        0, 0, 255, 0, //
        10, 20, 30, 40, //
      ]),
    );

    final decoded = decodePng(encodePng(image));

    expect(decoded.width, 2);
    expect(decoded.height, 2);
    expect(decoded.pixels, image.pixels);
  });

  test('ICO lists every size and stores small ones as DIBs', () {
    final small = solid(16, [1, 2, 3, 255]);
    final large = solid(64, [4, 5, 6, 255]);
    final largePng = encodePng(large);

    final ico = encodeIco([
      IcoImage(image: large, png: largePng),
      IcoImage(image: small, png: encodePng(small)),
    ]);
    final data = ByteData.sublistView(ico);

    expect(data.getUint16(2, Endian.little), 1, reason: 'type icon');
    expect(data.getUint16(4, Endian.little), 2, reason: 'two entries');
    // Smallest first.
    expect(ico[6], 16);
    expect(ico[22], 64);
    // The 16 px entry is a 32-bit DIB: 40-byte header, 16*16*4 pixels, mask.
    final smallSize = data.getUint32(14, Endian.little);
    final smallOffset = data.getUint32(18, Endian.little);
    expect(smallOffset, 6 + 16 * 2);
    expect(smallSize, 40 + 16 * 16 * 4 + 16 * 4);
    expect(data.getUint32(smallOffset, Endian.little), 40);
    expect(data.getInt32(smallOffset + 8, Endian.little), 32, reason: 'h*2');
    // First stored pixel is BGRA of the source RGBA.
    expect(ico.sublist(smallOffset + 40, smallOffset + 44), [3, 2, 1, 255]);
    // The 64 px entry keeps its PNG bytes verbatim.
    final largeOffset = data.getUint32(34, Endian.little);
    final largeSize = data.getUint32(30, Endian.little);
    expect(ico.sublist(largeOffset, largeOffset + largeSize), largePng);
  });

  test('256 px entries are written with a zero width byte', () {
    final image = solid(256, [0, 0, 0, 255]);
    final ico = encodeIco([IcoImage(image: image, png: encodePng(image))]);
    expect(ico[6], 0);
    expect(ico[7], 0);
  });
}
