import 'package:adnanload_mobile/services/quick_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('adnanload/quick_capture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    QuickCapture.visible.value = false;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    QuickCapture.visible.value = false;
  });

  test('successful native enable updates the settings switch', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'enableBubble');
      return true;
    });

    await QuickCapture.enableBubble();
    expect(QuickCapture.visible.value, isTrue);
  });

  test('native rejection never displays a bubble that was not enabled',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);

    await expectLater(QuickCapture.enableBubble(), throwsStateError);
    expect(QuickCapture.visible.value, isFalse);
  });

  test('null native acknowledgement is not treated as success', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    await expectLater(QuickCapture.enableBubble(), throwsStateError);
    expect(QuickCapture.visible.value, isFalse);
  });

  test('failed native disable retains the last confirmed visible state',
      () async {
    QuickCapture.visible.value = true;
    messenger.setMockMethodCallHandler(channel, (call) async => false);

    await expectLater(QuickCapture.disableBubble(), throwsStateError);
    expect(QuickCapture.visible.value, isTrue);
  });

  test('successful native disable clears the settings switch', () async {
    QuickCapture.visible.value = true;
    messenger.setMockMethodCallHandler(channel, (call) async => true);

    await QuickCapture.disableBubble();
    expect(QuickCapture.visible.value, isFalse);
  });

  test('platform exception preserves the confirmed bubble state', () async {
    QuickCapture.visible.value = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'OVERLAY_PERMISSION');
    });

    await expectLater(QuickCapture.disableBubble(), throwsA(isA<PlatformException>()));
    expect(QuickCapture.visible.value, isTrue);
  });
}
