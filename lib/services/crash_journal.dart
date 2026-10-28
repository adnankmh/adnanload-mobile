import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-first crash counter: deliberately does not persist errors, stack
/// traces, download names, URLs or browsing history.
class CrashJournal {
  static Future<void> record(String category) async {
    if (!const {'framework', 'platform', 'startup'}.contains(category)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('localCrashCount', (prefs.getInt('localCrashCount') ?? 0) + 1);
      await prefs.setString('lastCrashCategory', category);
    } catch (_) { /* never crash while reporting a crash */ }
  }

  static Future<int> crashCount() async {
    try {return (await SharedPreferences.getInstance()).getInt('localCrashCount') ?? 0;}
    catch (_) {return 0;}
  }
}
