import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// On-device quick capture. Overlay only after explicit Android permission.
class QuickCapture {
  static const MethodChannel _channel = MethodChannel('adnanload/quick_capture');
  static void Function(String)? onLink;
  static void Function()? onBubbleTapped;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incomingLink' && call.arguments is String) {
        onLink?.call(call.arguments as String);
      } else if (call.method == 'bubbleTapped') {
        onBubbleTapped?.call();
      }
    });
  }

  static Future<String?> initialLink() =>
      _channel.invokeMethod<String>('initialLink');
  static Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;
  static Future<void> requestPermission() async =>
      _channel.invokeMethod<void>('requestPermission');
  static Future<void> enableBubble() async {
    await _channel.invokeMethod<bool>('enableBubble');
    visible.value = true;
  }
  static Future<void> disableBubble() async {
    await _channel.invokeMethod<bool>('disableBubble');
    visible.value = false;
  }

  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);
}
