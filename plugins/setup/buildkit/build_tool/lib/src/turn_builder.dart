import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'error.dart';
import 'options.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('turn_builder');

class TurnBuilder {
  final String rootDir;
  final BuildConfig config;

  TurnBuilder({required this.rootDir, required this.config});

  String get _sourcePath =>
      p.join(rootDir, 'third_party', 'whitelist-bypass', 'relay');

  Future<String> build(Target target) async {
    if (!File(p.join(_sourcePath, 'go.mod')).existsSync()) {
      throw BuildException(
        'TURN source is missing. Run git submodule update --init --recursive.',
      );
    }

    final environment = <String, String>{
      'CGO_ENABLED': '0',
      'GOOS': target.isLib ? 'linux' : target.goos,
      'GOARCH': target.goarch,
      if (target.goarch == 'arm') 'GOARM': '7',
    };
    final String output;
    if (target.isLib) {
      final outputDirectory = p.join(
        rootDir,
        'android',
        'app',
        'src',
        'main',
        'jniLibs',
        target.abi!,
      );
      ensureDir(outputDirectory);
      output = p.join(outputDirectory, 'libDHQClashTurn.so');
    } else {
      final outputDirectory = p.join(
        rootDir,
        config.outputDir,
        target.platformDir,
      );
      ensureDir(outputDirectory);
      output = p.join(
        outputDirectory,
        'DHQClashTurn${target.executableExtension}',
      );
    }

    _log.info('Building TURN sidecar: $target');
    await runCommandStream(
      'go',
      ['build', '-trimpath', '-ldflags=-s -w', '-o', output, '.'],
      workingDirectory: _sourcePath,
      environment: environment,
    );
    _log.info('Built: $output');
    return output;
  }

  Future<List<String>> buildAll(List<Target> targets) async {
    final results = <String>[];
    for (final target in targets) {
      results.add(await build(target));
    }
    return results;
  }
}
