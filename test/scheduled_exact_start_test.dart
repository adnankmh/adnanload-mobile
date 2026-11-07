import 'package:adnanload_mobile/services/android_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scheduled = 2000000000000;

  test('scheduled native task does not start one millisecond early', () {
    expect(scheduledStartDecision(scheduled, scheduled - 1),
        ScheduledStartDecision.retryLater);
  });

  test('scheduled native task does not use the former 60-second early grace', () {
    expect(scheduledStartDecision(scheduled, scheduled - 59000),
        ScheduledStartDecision.retryLater);
  });

  test('scheduled native task may start at the requested instant', () {
    expect(scheduledStartDecision(scheduled, scheduled),
        ScheduledStartDecision.start);
  });

  test('late Android execution is allowed without losing the task', () {
    expect(scheduledStartDecision(scheduled, scheduled + 86400000),
        ScheduledStartDecision.start);
  });

  test('invalid timestamps are discarded without endless retries', () {
    expect(scheduledStartDecision(0, scheduled),
        ScheduledStartDecision.discard);
    expect(scheduledStartDecision(-1, scheduled),
        ScheduledStartDecision.discard);
  });
  test('scheduled payload rejects permanent URL and filename errors', () {
    expect(scheduledDirectUrl('job', 'file:///tmp/file', 'file.bin'), isNull);
    expect(scheduledDirectUrl('job',
        'https://user:pass@example.org/file', 'file.bin'), isNull);
    expect(scheduledDirectUrl('job', 'https://example.org/file',
        '../unsafe.apk'), isNull);
    expect(scheduledDirectUrl('', 'https://example.org/file',
        'file.bin'), isNull);
  });

  test('scheduled payload enforces the native input length limit', () {
    final tooLong = 'https://example.org/' + ('a' * 3500);
    expect(scheduledDirectUrl('job', tooLong, 'file.bin'), isNull);
  });

  test('scheduled payload preserves public signed download URL', () {
    const signed = 'https://example.org/file.bin?token=a%2Fb&expires=123';
    expect(scheduledDirectUrl('job', signed, 'file.bin')?.toString(),
        signed);
  });
}
