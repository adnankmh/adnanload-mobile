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
}
