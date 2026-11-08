/// The only language codes exposed by the application settings UI.
/// Persisted preferences and imported backups may contain older or invalid
/// values; normalize them before building locale-dependent widgets.
class LanguagePreference {
  static const supported = <String>['ar', 'en'];

  /// Accept only exact supported codes, including when a persisted value has
  /// an unexpected type (for example, a corrupted SharedPreferences entry).
  static bool isSupported(Object? value) =>
      value is String && supported.contains(value);

  static String normalize(Object? value) =>
      isSupported(value) ? value as String : 'ar';
}
