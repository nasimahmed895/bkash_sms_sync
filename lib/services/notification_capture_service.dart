import 'package:flutter/services.dart';

import '../core/app_logger.dart';
import '../core/sms_parser.dart';
import 'sms_service.dart';

const _eventChannel =
    EventChannel('com.example.bkash_sms_sync/bkash_notifications');
const _methodChannel =
    MethodChannel('com.example.bkash_sms_sync/notification_permission');

class NotificationCaptureService {
  bool _started = false;

  Future<bool> isAccessGranted() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isGranted') ?? false;
    } on PlatformException catch (e) {
      appLogger.e('isAccessGranted error: $e');
      return false;
    }
  }

  Future<void> openAccessSettings() async {
    try {
      await _methodChannel.invokeMethod<void>('openSettings');
    } on PlatformException catch (e) {
      appLogger.e('openAccessSettings error: $e');
    }
  }

  void start() {
    if (_started) return;
    _started = true;
    _eventChannel.receiveBroadcastStream().listen(
      (data) => _onNotification(data as String),
      onError: (Object e) => appLogger.e('Notification stream error: $e'),
    );
    appLogger.i('Notification capture listener active.');
  }

  Future<void> _onNotification(String text) async {
    final parsed = BkashSmsParser.parseNotification(text);
    if (parsed == null) return;
    await handleParsedPayment(parsed);
  }
}
