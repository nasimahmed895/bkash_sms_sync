/// Sync status of a locally captured payment.
enum SyncStatus { pendingSync, synced, failed }

extension SyncStatusX on SyncStatus {
  String get dbValue => switch (this) {
        SyncStatus.pendingSync => 'pending_sync',
        SyncStatus.synced => 'synced',
        SyncStatus.failed => 'failed',
      };

  static SyncStatus fromDb(String v) => switch (v) {
        'synced' => SyncStatus.synced,
        'failed' => SyncStatus.failed,
        _ => SyncStatus.pendingSync,
      };
}

/// A mobile-banking payment (bKash / Nagad) captured from SMS, queued
/// for webhook delivery.
class Payment {
  final int? localId;
  final String provider; // 'bkash' | 'nagad'
  final String phone;
  final double amount;
  final double balance;
  final String trxID;
  final String paymentTime; // raw "dd/MM/yyyy HH:mm"
  final SyncStatus syncStatus;
  final int? backendId;
  final int retryCount;
  final DateTime? lastAttempt;
  final DateTime createdAt;

  const Payment({
    this.localId,
    this.provider = 'bkash',
    required this.phone,
    required this.amount,
    required this.balance,
    required this.trxID,
    required this.paymentTime,
    this.syncStatus = SyncStatus.pendingSync,
    this.backendId,
    this.retryCount = 0,
    this.lastAttempt,
    required this.createdAt,
  });

  Payment copyWith({
    int? localId,
    SyncStatus? syncStatus,
    int? backendId,
    int? retryCount,
    DateTime? lastAttempt,
  }) =>
      Payment(
        localId: localId ?? this.localId,
        provider: provider,
        phone: phone,
        amount: amount,
        balance: balance,
        trxID: trxID,
        paymentTime: paymentTime,
        syncStatus: syncStatus ?? this.syncStatus,
        backendId: backendId ?? this.backendId,
        retryCount: retryCount ?? this.retryCount,
        lastAttempt: lastAttempt ?? this.lastAttempt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toWebhookJson() => {
        'provider': provider,
        'number': phone,
        'amount': amount,
        'balance': balance,
        'trxID': trxID,
        'at': paymentTime,
      };
}

/// Local dashboard statistics.
class PaymentStats {
  final int totalPayments;
  final double totalAmount;
  final int successful;
  final int pendingSync;
  final int failed;

  const PaymentStats({
    required this.totalPayments,
    required this.totalAmount,
    required this.successful,
    required this.pendingSync,
    required this.failed,
  });
}
