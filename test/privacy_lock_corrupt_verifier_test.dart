import 'package:adnanload_mobile/services/privacy_lock.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avoid Android keystore/platform dependencies while exercising the real
/// PrivacyLock read/write/delete and failed-attempt behavior.
class _MemorySecureStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    if (invocation.memberName == #read) {
      return Future<String?>.value(values[key]);
    }
    if (invocation.memberName == #write) {
      values[key!] = invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  test('valid salted PIN verifier still unlocks and rejects wrong PINs',
      () async {
    final storage = _MemorySecureStorage();
    final lock = PrivacyLock(storage: storage);
    await lock.enable('123456');
    expect(await lock.enabled, isTrue);
    expect(await lock.verify('000000'), isFalse);
    expect(await lock.verify('123456'), isTrue);
    expect(await lock.disable('123456'), isTrue);
    expect(await lock.enabled, isFalse);
  });

  test('malformed stored verifiers fail closed without exceptions', () async {
    final invalid = <String>[
      'broken',
      '%%%%:deadbeef',
      'YWJj:${List.filled(64, 'a').join()}',
      ':${List.filled(64, 'a').join()}',
      'AAAA:${List.filled(64, 'g').join()}',
      'AAAA:${List.filled(64, 'a').join()}:extra',
      '${List.filled(65, 'A').join()}:${List.filled(64, 'a').join()}',
    ];
    for (final record in invalid) {
      final storage = _MemorySecureStorage()..values['lock.verifier'] = record;
      final lock = PrivacyLock(storage: storage);
      expect(await lock.enabled, isTrue);
      expect(await lock.verify('123456'), isFalse, reason: record);
      expect(await lock.disable('123456'), isFalse, reason: record);
    }
  });

  test('corrupt verifier attempts count toward lockout; PIN reset clears it',
      () async {
    final storage = _MemorySecureStorage();
    final lock = PrivacyLock(storage: storage);
    await lock.enable('123456');
    final correct = storage.values['lock.verifier']!;
    storage.values['lock.verifier'] = 'invalid-base64:bad-hash';
    for (var i = 0; i < 5; i++) {
      expect(await lock.verify('123456'), isFalse);
    }
    // Restoring the correct verifier must not bypass an active lockout.
    storage.values['lock.verifier'] = correct;
    expect(await lock.verify('123456'), isFalse);
    // A legitimate PIN reconfiguration resets the stale in-memory lockout.
    await lock.enable('654321');
    expect(await lock.verify('654321'), isTrue);
  });
}
