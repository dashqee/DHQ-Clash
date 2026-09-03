// Render an SVG at every size Windows asks for and pack them into one ICO.
//
//   dart tool/make_ico.dart <icon.svg> <out.ico> [size ...]
//
// Needs rsvg-convert on PATH. Defaults to the sizes the shell, taskbar and
// notification area actually request, so none of them has to scale.
import 'dart:io';

import 'ico.dart';

const defaultSizes = [16, 20, 24, 32, 40, 48, 64, 128, 256];

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart tool/make_ico.dart <icon.svg> <out.ico> [size ...]');
    exitCode = 64;
    return;
  }
  final source = args[0];
  final output = args[1];
  final sizes = args.length > 2 ? args.sublist(2).map(int.parse).toList() : defaultSizes;
  final temp = Directory.systemTemp.createTempSync('dhq-ico-');
  try {
    final images = <IcoImage>[];
    for (final size in sizes) {
      final png = File('${temp.path}/$size.png');
      final result = await Process.run('rsvg-convert', [
        '--width',
        '$size',
        '--height',
        '$size',
        '--output',
        png.path,
        source,
      ]);
      if (result.exitCode != 0) {
        stderr
          ..writeln('rsvg-convert failed for $source at $size px')
          ..writeln(result.stderr);
        exitCode = result.exitCode;
        return;
      }
      final bytes = png.readAsBytesSync();
      images.add(IcoImage(image: decodePng(bytes), png: bytes));
    }
    File(output).writeAsBytesSync(encodeIco(images));
    stdout.writeln('$output: ${sizes.join(', ')} px');
  } finally {
    temp.deleteSync(recursive: true);
  }
}
