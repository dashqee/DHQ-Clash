import 'package:test/test.dart';

import '../setup.dart' as setup;
import '../tool/release_version.dart' as release_version;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });
  });

  group('release version', () {
    test('uses prerelease tag and a dated Android build number', () {
      final pubspec = release_version.withReleaseVersion(
        'name: fl_clash\nversion: 1.1.5+2026072406\n',
        tag: 'v1.2.0-beta.2',
        runNumber: 17,
        now: DateTime.utc(2026, 7, 25),
      );

      expect(pubspec, contains('version: 1.2.0-beta.2+2026072517'));
    });

    test('rejects branch names as release versions', () {
      expect(
        () => release_version.withReleaseVersion(
          'version: 1.1.5+1\n',
          tag: 'feature/test',
          runNumber: 1,
          now: DateTime.utc(2026),
        ),
        throwsFormatException,
      );
    });
  });
}
