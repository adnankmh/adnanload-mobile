import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Optional local PIN gate. The salted verifier is held in Android's encrypted
/// platform storage. This is NOT file encryption and is not a remote account.
class PrivacyLock {
  final FlutterSecureStorage storage;
  PrivacyLock({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage();
  int _failures = 0;
  DateTime? _blockedUntil;

  Future<bool> get enabled async => (await storage.read(key: 'lock.verifier')) != null;

  Future<void> enable(String pin) async {
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 6–12 digits');
    }
    final salt = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final encodedSalt = base64Url.encode(salt);
    final hash = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    await storage.write(key: 'lock.verifier', value: '$encodedSalt:$hash');
    _failures = 0;
    _blockedUntil = null;
  }

  Future<bool> verify(String pin) async {
    if (_blockedUntil != null && DateTime.now().isBefore(_blockedUntil!)) {
      return false;
    }
    final stored = await storage.read(key: 'lock.verifier');
    if (stored == null) return true;
    // Corrupted secure-storage records must fail closed without throwing or
    // bypassing the normal failed-attempt lockout. Only the salted SHA-256
    // verifier produced by enable() is a valid record.
    final parts = stored.split(':');
    var matches = false;
    if (parts.length == 2 &&
        // Reject malformed or oversized PIN input before any UTF-8 hashing.
        // Invalid input still counts toward the regular lockout below.
        pin.length >= 6 &&
        pin.length <= 12 &&
        RegExp(r'^\d{6,12}$').hasMatch(pin) &&
        parts[0].length <= 64 &&
        parts[1].length == 64 &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(parts[1])) {
      try {
        final salt = base64Url.decode(parts[0]);
        if (salt.length == 32) {
          final hash =
              sha256.convert([...salt, ...utf8.encode(pin)]).toString();
          // Compare all digest bytes without an early mismatch exit.
          final a = utf8.encode(hash), b = utf8.encode(parts[1]);
          var diff = 0;
          for (var i = 0; i < a.length; i++) {
            diff |= a[i] ^ b[i];
          }
          matches = diff == 0;
        }
      } on FormatException {
        // Invalid base64 is a failed PIN check, not an uncaught exception.
      }
    }
    if (matches) {
      _failures = 0;
      _blockedUntil = null;
      return true;
    }
    _failures++;
    if (_failures >= 5) { _blockedUntil = DateTime.now().add(const Duration(minutes: 1)); _failures = 0; }
    return false;
  }

  Future<bool> disable(String pin) async {
    if (!await verify(pin)) return false;
    await storage.delete(key: 'lock.verifier');
    return true;
  }
}
