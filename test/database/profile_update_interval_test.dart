import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legacyMillis = 24 * 60 * 60 * 1000;

  late Database database;

  setUp(() {
    database = Database(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertProfile({required int id, required int durationMillis}) {
    return database
        .into(database.profiles)
        .insert(
          ProfilesCompanion.insert(
            id: Value(id),
            label: 'profile-$id',
            url: 'https://example.com/$id.yaml',
            overwriteType: OverwriteType.standard,
            autoUpdateDurationMillis: durationMillis,
            autoUpdate: true,
            selectedMap: const {},
            unfoldSet: const {},
          ),
        );
  }

  Future<int> durationOf(int id) async {
    final row = await (database.select(
      database.profiles,
    )..where((row) => row.id.equals(id))).getSingle();
    return row.autoUpdateDurationMillis;
  }

  test('the default update interval is an hour', () {
    // Profiles are per-client subscriptions; a day meant a revoked or moved node
    // stayed in the config for up to that long.
    expect(defaultUpdateDuration, const Duration(minutes: 60));
  });

  test('a profile still on the old daily default is pulled up', () async {
    await insertProfile(id: 1, durationMillis: legacyMillis);

    await database.shortenDefaultUpdateInterval();

    expect(await durationOf(1), defaultUpdateDuration.inMilliseconds);
  });

  test('an interval somebody chose is left alone', () async {
    // The field is editable per profile, so anything that is not exactly the
    // old default is a decision, and a new default is no reason to overwrite it.
    const chosen = 15 * 60 * 1000;
    const weekly = 7 * 24 * 60 * 60 * 1000;
    await insertProfile(id: 1, durationMillis: chosen);
    await insertProfile(id: 2, durationMillis: weekly);

    await database.shortenDefaultUpdateInterval();

    expect(await durationOf(1), chosen);
    expect(await durationOf(2), weekly);
  });
}
