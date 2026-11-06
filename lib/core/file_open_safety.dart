/// Safety gate for handing downloaded files to external applications.
///
/// The stored display name can differ from the on-disk name after renaming,
/// so both must be checked. This is a confirmation prompt, not a malware
/// scanner; users should still verify the source before opening files.
class FileOpenSafety {
  FileOpenSafety._();

  static final RegExp _riskyExtension = RegExp(
    r'\.(?:apk|apks|xapk|aab|exe|msi|bat|cmd|ps1|sh|jar|vbs|com|scr|hta|wsf|pif|cpl|reg|lnk)$',
    caseSensitive: false,
  );

  // Ignore format characters that can visually disguise an extension.
  static final RegExp _hiddenFormatting = RegExp(
    r'[\u00AD\u061C\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );

  static bool requiresConfirmation(String path, {String? displayName}) {
    return _risky(path) || (displayName != null && _risky(displayName));
  }

  static bool _risky(String value) {
    final basename = value
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(_hiddenFormatting, '')
        .trim()
        // Windows may ignore trailing dots/spaces in file names. Treat
        // disguised installer extensions conservatively on every platform.
        .replaceFirst(RegExp(r'[. ]+$'), '');
    return _riskyExtension.hasMatch(basename);
  }
}
