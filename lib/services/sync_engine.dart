import '../core/app_logger.dart';
import '../data/remote/api_client.dart';
import '../domain/entities/payment.dart';
import '../domain/repositories/payment_repository.dart';

/// Drives webhook delivery of pending payments.
///
/// Guarantees:
///  - Payments are loaded from DB and submitted one by one (FIFO).
///  - success  -> markSynced (stores backend id, never retried again)
///  - rejected -> markFailed (backend said "payment not found"; backend owns it)
///  - transient (offline / timeout / 5xx) -> retryCount++ and stays
///    pending_sync, so WorkManager / connectivity recovery picks it up later.
class SyncEngine {
  final PaymentRepository _repo;
  final ApiClient _api;

  bool _running = false;

  SyncEngine(this._repo, this._api);

  /// Resets failed payments to pending, then syncs everything.
  /// Use on manual pull-to-refresh so previously-rejected payments get
  /// one more chance (e.g. a 409-without-id that was wrongly marked failed).
  Future<bool> syncAll() async {
    await _repo.retryFailed();
    return syncPending();
  }

  /// Syncs all pending payments. Returns true if nothing is left pending
  /// (i.e. no further retry needs to be scheduled).
  Future<bool> syncPending() async {
    if (_running) return false; // simple re-entrancy guard per isolate
    _running = true;
    try {
      final pending = await _repo.getPendingPayments();
      if (pending.isEmpty) return true;

      appLogger.i('SyncEngine: ${pending.length} pending payment(s)');
      var allDone = true;

      for (final pmt in pending) {
        final result = await _api.submitPayment(pmt.toWebhookJson());
        switch (result) {
          case WebhookSuccess(:final backendId):
            await _repo.markSynced(pmt.localId!, backendId);
            appLogger.i('Synced trxID=${pmt.trxID} backendId=$backendId');
          case WebhookRejected(:final message):
            await _repo.markFailed(pmt.localId!);
            appLogger.w('Rejected trxID=${pmt.trxID}: $message');
          case WebhookTransientError(:final reason):
            await _repo.bumpRetry(pmt.localId!);
            appLogger.w('Transient error trxID=${pmt.trxID}: $reason');
            allDone = false;
        }
      }
      return allDone;
    } finally {
      _running = false;
    }
  }
}
