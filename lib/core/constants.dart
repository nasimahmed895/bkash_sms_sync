/// Global constants for the app.
class AppConstants {
  AppConstants._();

  // ---- API ----
  /// TODO: set to the real backend origin before release.
  static const String baseUrl = 'https://api.example.com';

  /// Unified payment webhook (handles bKash + Nagad, SMS package +
  /// subscription). Full URL = baseUrl + webhookPath.
  static const String webhookPath = '/sms/v1/webhook/verification-payment';
  static const String paymentListPath = '/api/payment-list';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  // ---- Payment SMS detection ----
  /// Known bKash sender IDs. SMS from other senders is still parsed but
  /// flagged; tighten this list as needed.
  static const List<String> bkashSenderIds = ['bKash', 'BKASH', 'bkash', '16247'];

  /// Known Nagad sender IDs.
  static const List<String> nagadSenderIds = ['NAGAD', 'Nagad', 'nagad', '16167'];

  /// All of these substrings must be present for an SMS to be considered
  /// a bKash received-payment message.
  static const List<String> bkashKeywords = ['received', 'Tk', 'Balance', 'TrxID'];

  /// All of these substrings must be present for an SMS to be considered
  /// a Nagad received-payment message.
  static const List<String> nagadKeywords = ['Money Received', 'Amount', 'TxnID', 'Balance'];

  // ---- Retry schedule (index = retryCount) ----
  /// 30s, 1m, 5m, 15m, 30m, 1h, then every 6h forever.
  static const List<Duration> retrySchedule = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];
  static const Duration fallbackRetryInterval = Duration(hours: 6);

  static Duration retryDelayFor(int retryCount) {
    if (retryCount < retrySchedule.length) return retrySchedule[retryCount];
    return fallbackRetryInterval;
  }

  // ---- WorkManager task names ----
  static const String syncTaskName = 'bkash_payment_sync';
  static const String periodicSyncTaskName = 'bkash_payment_periodic_sync';
  static const String workManagerUniquePeriodic = 'periodic-sync';
}
