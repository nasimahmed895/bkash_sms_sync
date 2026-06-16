import 'package:permission_handler/permission_handler.dart';

import '../core/app_logger.dart';

/// Manages battery-optimization exemption.
///
/// Why this matters:
///  - Android Doze mode blocks all network access for background processes.
///  - Without exemption, backgroundSmsHandler stores the payment in SQLite but
///    syncPending() HTTP call fails → payment stays pending_sync.
///  - WorkManager retries are also deferred in Doze.
///  - Apps not opened for weeks can be put in "Restricted" standby bucket or
///    even force-stopped by Android's "Unused apps" feature, killing all
///    broadcast receivers (including SMS_RECEIVED).
///
/// With exemption the app is on the Doze whitelist → background network works.
class BatteryOptimizationService {
  BatteryOptimizationService._();

  /// Returns true if the OS has already granted exemption.
  static Future<bool> isExempted() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }

  /// Opens the system dialog asking the user to exempt this app.
  /// Returns true if the user granted exemption.
  ///
  /// Android shows a native dialog — no extra UI needed in the app.
  static Future<bool> requestExemption() async {
    if (await isExempted()) return true;
    final result = await Permission.ignoreBatteryOptimizations.request();
    final granted = result.isGranted;
    if (granted) {
      appLogger.i('Battery optimization exemption granted.');
    } else {
      appLogger.w(
        'Battery optimization exemption denied. '
        'Background sync may be unreliable on this device.',
      );
    }
    return granted;
  }
}
