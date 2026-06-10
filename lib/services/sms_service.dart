import 'package:another_telephony/telephony.dart';

import '../core/app_logger.dart';
import '../core/sms_parser.dart';
import '../data/local/payment_db.dart';
import '../domain/entities/payment.dart';
import 'background_tasks.dart';
import 'service_locator.dart';
import 'sync_engine.dart';

/// Handles one incoming SMS. Used by BOTH the foreground and the
/// background (app-killed) paths, so the pipeline is identical:
///
///   1. keyword + regex validation  -> not bKash? ignore, no API call
///   2. INSERT with UNIQUE(trxID)   -> duplicate? ignore, no API call
///   3. status = pending_sync (persisted BEFORE any network attempt)
///   4. immediate sync attempt + WorkManager retry scheduling
Future<void> handleIncomingSms(SmsMessage message) async {
  final body = message.body;
  if (body == null) return;

  final parsed = BkashSmsParser.parse(body);
  if (parsed == null) return; // not a bKash payment SMS -> ignore

  if (!BkashSmsParser.isKnownBkashSender(message.address)) {
    appLogger.w(
        'bKash-pattern SMS from unverified sender "${message.address}" — '
        'stored anyway; tighten AppConstants.bkashSenderIds to reject.');
  }

  await setupServiceLocator();

  // 1. Persist FIRST — this is the no-payment-can-ever-be-lost guarantee.
  final payment = Payment(
    phone: parsed.number,
    amount: parsed.amount,
    balance: parsed.balance,
    trxID: parsed.trxID,
    paymentTime: parsed.at,
    syncStatus: SyncStatus.pendingSync,
    createdAt: DateTime.now(),
  );
  final stored = await sl<PaymentDb>().insertIfNew(payment);
  if (stored == null) {
    appLogger.i('Duplicate trxID ${parsed.trxID} — ignored.');
    return; // duplicate SMS -> never submit duplicate webhook
  }
  appLogger.i('Stored payment trxID=${parsed.trxID} amount=${parsed.amount}');

  // 2. Try to deliver right now (if online)...
  final allDone = await sl<SyncEngine>().syncPending();

  // 3. ...and make sure WorkManager owns the retry chain if it didn't go
  //    through (offline, timeout, server down, etc.).
  if (!allDone) {
    await BackgroundTasks.scheduleRetry(0); // first retry in 30s
  }
}

/// Top-level background entry point for `another_telephony`.
/// Runs in a background isolate even when the Flutter app is killed.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  try {
    await handleIncomingSms(message);
  } catch (e, st) {
    appLogger.e('backgroundSmsHandler error', error: e, stackTrace: st);
  }
}

class SmsService {
  final Telephony _telephony = Telephony.instance;

  /// Requests SMS permissions and starts listening (foreground +
  /// background). Call once from the UI isolate at startup.
  Future<bool> start() async {
    final granted =
        await _telephony.requestPhoneAndSmsPermissions ?? false;
    if (!granted) {
      appLogger.e('SMS permissions denied — cannot capture payments.');
      return false;
    }

    _telephony.listenIncomingSms(
      onNewMessage: handleIncomingSms,        // app in foreground
      onBackgroundMessage: backgroundSmsHandler, // app killed/minimized
      listenInBackground: true,
    );
    appLogger.i('SMS listener active (foreground + background).');
    return true;
  }
}
