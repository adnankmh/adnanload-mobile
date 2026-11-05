/// The only language codes exposed by the application settings UI.
/// Persisted preferences and imported backups may contain older or invalid
/// values; normalize them before building locale-dependent widgets.
class LanguagePreference {
  static const supported = <String>['ar', 'en'];

  static bool isSupported(String? value) => supported.contains(value);

  static String normalize(String? value) =>
      isSupported(value) ? value! : 'ar';
}
