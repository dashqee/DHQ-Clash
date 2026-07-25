import 'dart:async';

import 'package:fl_clash/common/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();
    preferences.sharedPreferencesCompleter = Completer<SharedPreferences?>()
      ..complete(sharedPreferences);
  });

  test('claims the automatic macOS helper install once per release', () async {
    expect(
      await preferences.claimMacOSHelperInstallAttempt(releaseId: '1.1.8+10'),
      isTrue,
    );
    expect(
      await preferences.claimMacOSHelperInstallAttempt(releaseId: '1.1.8+10'),
      isFalse,
    );
    expect(
      await preferences.claimMacOSHelperInstallAttempt(releaseId: '1.1.9+11'),
      isTrue,
    );
  });

  test('allows an explicit macOS helper install attempt', () async {
    expect(
      await preferences.claimMacOSHelperInstallAttempt(releaseId: '1.1.8+10'),
      isTrue,
    );
    expect(
      await preferences.claimMacOSHelperInstallAttempt(
        releaseId: '1.1.8+10',
        force: true,
      ),
      isTrue,
    );
    expect(
      await preferences.claimMacOSHelperInstallAttempt(releaseId: '1.1.8+10'),
      isFalse,
    );
  });
}
