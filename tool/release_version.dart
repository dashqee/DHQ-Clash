import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart tool/release_version.dart <tag> <workflow-run-number>',
    );
    exitCode = 64;
    return;
  }

  final runNumber = int.tryParse(args[1]);
  if (runNumber == null || runNumber < 0) {
    stderr.writeln('Invalid workflow run number: ${args[1]}');
    exitCode = 64;
    return;
  }

  final pubspec = File('pubspec.yaml');
  final updatedPubspec = withReleaseVersion(
    pubspec.readAsStringSync(),
    tag: args[0],
    runNumber: runNumber,
    now: DateTime.now().toUtc(),
  );
  pubspec.writeAsStringSync(updatedPubspec);
  stdout.writeln(
    RegExp(r'^version:\s*.+$', multiLine: true).firstMatch(updatedPubspec)![0],
  );
}

String withReleaseVersion(
  String pubspec, {
  required String tag,
  required int runNumber,
  required DateTime now,
}) {
  final releaseVersion = tag.replaceFirst(RegExp(r'^v'), '');
  final isValid = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  ).hasMatch(releaseVersion);
  if (!isValid) {
    throw FormatException('Invalid release tag: $tag');
  }

  final date =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}';
  final sequence = (runNumber % 100).toString().padLeft(2, '0');
  final packageVersion = '$releaseVersion+$date$sequence';
  final versionLine = RegExp(r'^version:\s*.+$', multiLine: true);
  if (!versionLine.hasMatch(pubspec)) {
    throw const FormatException('pubspec.yaml has no version field');
  }
  return pubspec.replaceFirst(versionLine, 'version: $packageVersion');
}
