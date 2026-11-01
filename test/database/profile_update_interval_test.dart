import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dailyMillis = 24 * 60 * 60 * 1000;

  late Database database;

  setUp(() {
    database = Database(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertProfile({
    required int id,
    required int durationMillis,
    bool autoUpdate = true,
    String? url,
  }) {
    return database
        .into(database.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: Value(id),
            label: 'profile-$id',
            url: url ?? 'https://example.com/$id.yaml',
            overwriteType: OverwriteType.standard,
            autoUpdateDurationMillis: durationMillis,
            autoUpdate: autoUpdate,
            selectedMap: const {},
            unfoldSet: const {},
          ),
        );
  }

  Future<RawProfile> rowOf(int id) {
    return (database.select(
      database.profiles,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  test('the default update interval is a day', () {
    expect(defaultUpdateDuration, const Duration(hours: 24));
  });

  test('every subscription is put on a daily auto-update', () async {
    const hourly = 60 * 60 * 1000;
    const weekly = 7 * 24 * 60 * 60 * 1000;
    await insertProfile(id: 1, durationMillis: hourly);
    await insertProfile(id: 2, durationMillis: weekly);
    await insertProfile(id: 3, durationMillis: hourly, autoUpdate: false);

    await database.enforceDailyAutoUpdate();

    for (final id in [1, 2, 3]) {
      final row = await rowOf(id);
      expect(row.autoUpdate, true, reason: 'profile $id');
      expect(row.autoUpdateDurationMillis, dailyMillis, reason: 'profile $id');
    }
  });

  test('a profile imported from a file is left alone', () async {
    // It has no URL to update from, so there is nothing to switch on.
    const hourly = 60 * 60 * 1000;
    await insertProfile(
      id: 1,
      durationMillis: hourly,
      autoUpdate: false,
      url: '',
    );

    await database.enforceDailyAutoUpdate();

    final row = await rowOf(1);
    expect(row.autoUpdate, false);
    expect(row.autoUpdateDurationMillis, hourly);
  });
}
