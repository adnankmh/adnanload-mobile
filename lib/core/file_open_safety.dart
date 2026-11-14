import 'smart_link.dart';

/// Safety gate for handing downloaded files to external applications.
///
/// The stored display name can differ from the on-disk name after renaming,
/// so both must be checked. This is a confirmation prompt, not a malware
/// scanner; users should still verify the source before opening files.
class FileOpenSafety {
  FileOpenSafety._();

  // Include installer bundles, script hosts and desktop launchers on other
  // platforms. Opening them is always an explicit user decision.
  static final RegExp _riskyExtension = RegExp(
    r'\.(?:apk|apks|xapk|aab|deb|rpm|dmg|appx|appxbundle|msix|msixbundle|exe|msi|msp|bat|cmd|ps1|psm1|sh|command|desktop|jar|vbs|vbe|js|jse|ws|wsh|com|scr|hta|sct|scf|wsf|pif|cpl|reg|lnk|url)$',
    caseSensitive: false,
  );

  // Ignore format characters that can visually disguise an extension.
  static final RegExp _hiddenFormatting = RegExp(
    r'[\u00AD\u061C\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  );

  /// Only auto-open a confirmed non-installer. Check the physical path as
  /// well as the display name: the two can diverge after native renaming.
  /// This does not replace the foreground and explicit opt-in checks.
  static bool mayAutoOpen(String path, {required String displayName}) {
    if (path.trim().isEmpty ||
        requiresConfirmation(path, displayName: displayName)) {
      return false;
    }
    // SmartLink additionally recognizes .deb/.rpm/.dmg and URL-style
    // query/fragment suffixes, which may disguise application packages.
    return SmartLink.category(path) != 'application' &&
        SmartLink.category(displayName) != 'application';
  }

  static bool requiresConfirmation(String path, {String? displayName}) {
    // Keep manual-open warnings consistent with the automatic-open guard.
    // SmartLink recognizes additional installer formats (deb/rpm/dmg) and
    // URL-style query/fragment suffixes; _risky still handles invisible
    // formatting characters and trailing dots/spaces in physical filenames.
    bool installer(String value) =>
        _risky(value) || SmartLink.category(value) == 'application';
    return installer(path) || (displayName != null && installer(displayName));
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
    // Check both literal filenames and URL-style suffixes after removing
    // invisible formatting. SmartLink only covers application packages,
    // not script and shortcut extensions such as .cmd or .lnk.
    final withoutSuffix = basename.split(RegExp(r'[?#]')).first
        .trimRight()
        .replaceFirst(RegExp(r'[. ]+$'), '');
    return _riskyExtension.hasMatch(basename) ||
        _riskyExtension.hasMatch(withoutSuffix);
  }
}
