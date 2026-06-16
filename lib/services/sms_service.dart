import 'package:another_telephony/telephony.dart';

import '../core/app_logger.dart';
import '../core/constants.dart';
import '../core/sms_parser.dart';
import '../data/local/payment_db.dart';
import '../domain/entities/payment.dart';
import 'background_tasks.dart';
import 'service_locator.dart';
import 'sync_engine.dart';

/// Shared pipeline: persist → sync → schedule retry.
/// Called by SMS path, notification path, and WorkManager.
Future<void> handleParsedPayment(ParsedPayment parsed) async {
  await setupServiceLocator();

  final payment = Payment(
    provider: parsed.provider,
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
    return;
  }
  appLogger.i('Stored payment trxID=${parsed.trxID} amount=${parsed.amount}');

  final allDone = await sl<SyncEngine>().syncPending();
  if (!allDone) await BackgroundTasks.scheduleRetry(0);
}

/// Handles one incoming SMS (foreground + background isolate paths).
Future<void> handleIncomingSms(SmsMessage message) async {
  final body = message.body;
  if (body == null) return;

  final parsed = PaymentSmsParser.parse(body);
  if (parsed == null) return;

  if (!PaymentSmsParser.isKnownSender(parsed.provider, message.address)) {
    appLogger.w(
        '${parsed.provider}-pattern SMS from unverified sender '
        '"${message.address}" — rejected.');
    return;
  }

  await handleParsedPayment(parsed);
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
      onNewMessage: handleIncomingSms,
      onBackgroundMessage: backgroundSmsHandler,
      listenInBackground: true,
    );
    appLogger.i('SMS listener active (foreground + background).');
    return true;
  }

  /// Safety-net: scans the SMS inbox for any payment messages from the last
  /// [daysBack] days that were missed while the app was force-stopped or while
  /// the background isolate was killed by Doze / battery-saver.
  ///
  /// Called on every app open. Duplicate trxIDs are silently ignored by the
  /// SQLite UNIQUE constraint (ConflictAlgorithm.ignore), so this is safe to
  /// run repeatedly without double-submitting any payment.
  Future<void> scanInbox({int daysBack = 7}) async {
    try {
      final since = DateTime.now()
          .subtract(Duration(days: daysBack))
          .millisecondsSinceEpoch;

      final knownSenders = [
        ...AppConstants.bkashSenderIds,
        ...AppConstants.nagadSenderIds,
      ];

      int found = 0;
      int submitted = 0;

      for (final sender in knownSenders) {
        final messages = await _telephony.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
          filter: SmsFilter.where(SmsColumn.ADDRESS)
              .equals(sender)
              .and(SmsColumn.DATE)
              .greaterThan(since.toString()),
          sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.ASC)],
        );

        for (final msg in messages) {
          final body = msg.body;
          if (body == null) continue;
          found++;
          final parsed = PaymentSmsParser.parse(body);
          if (parsed == null) continue;
          await handleParsedPayment(parsed);
          submitted++;
        }
      }

      appLogger.i(
        'Inbox scan (last ${daysBack}d): $found SMS read, '
        '$submitted payment(s) processed.',
      );
    } catch (e, st) {
      appLogger.e('scanInbox failed', error: e, stackTrace: st);
    }
  }
}
