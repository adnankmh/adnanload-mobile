import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-first crash counter: deliberately does not persist errors, stack
/// traces, download names, URLs or browsing history.
class CrashJournal {
  // Keep the diagnostic counter bounded even after years of repeated failures.
  static const int _maxCount = 1000000000;

  // Framework and platform errors may arrive at the same time. Serialize
  // read-modify-write operations so a burst does not lose crash counts.
  static Future<void> _pending = Future<void>.value();

  static int _safeCount(SharedPreferences prefs) {
    // A restored preference can have the wrong type; typed getters throw in
    // that case, leaving the journal unable to record any future failures.
    final value = prefs.get('localCrashCount');
    if (value is! int || value < 0) return 0;
    return value > _maxCount ? _maxCount : value;
  }

  static Future<void> record(String category) {
    if (!const {'framework', 'platform', 'startup'}.contains(category)) {
      return Future<void>.value();
    }
    return _pending = _pending.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final count = _safeCount(prefs);
        await prefs.setInt(
          'localCrashCount',
          count < _maxCount ? count + 1 : _maxCount,
        );
        await prefs.setString('lastCrashCategory', category);
      } catch (_) {
        // Diagnostics must never cause another application crash.
      }
    });
  }

  static Future<int> crashCount() async {
    try {
      return _safeCount(await SharedPreferences.getInstance());
    } catch (_) {
      return 0;
    }
  }
}
