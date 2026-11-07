import 'package:adnanload_mobile/services/crash_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('counts only supported crash categories', () async {
    await CrashJournal.record('framework');
    await CrashJournal.record('platform');
    await CrashJournal.record('startup');
    await CrashJournal.record('download-url-with-private-data');
    expect(await CrashJournal.crashCount(), 3);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('lastCrashCategory'), 'startup');
    expect(prefs.getKeys(), {'localCrashCount', 'lastCrashCategory'});
  });

  test('recovers a restored counter with the wrong type', () async {
    SharedPreferences.setMockInitialValues({
      'localCrashCount': 'not an integer',
      'lastCrashCategory': 'startup',
    });
    expect(await CrashJournal.crashCount(), 0);
    await CrashJournal.record('platform');
    expect(await CrashJournal.crashCount(), 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('localCrashCount'), 1);
    expect(prefs.getString('lastCrashCategory'), 'platform');
  });

  test('recovers negative persisted crash counts', () async {
    SharedPreferences.setMockInitialValues({'localCrashCount': -8});
    expect(await CrashJournal.crashCount(), 0);
    await CrashJournal.record('framework');
    expect(await CrashJournal.crashCount(), 1);
  });

  test('saturates oversized counters without integer overflow', () async {
    SharedPreferences.setMockInitialValues({'localCrashCount': 1000000007});
    expect(await CrashJournal.crashCount(), 1000000000);
    await CrashJournal.record('startup');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('localCrashCount'), 1000000000);
  });

  test('does not lose simultaneous platform and framework errors', () async {
    await Future.wait(List.generate(
      40,
      (index) => CrashJournal.record(index.isEven ? 'platform' : 'framework'),
    ));
    expect(await CrashJournal.crashCount(), 40);
  });
}
