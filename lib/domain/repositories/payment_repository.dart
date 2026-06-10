import '../entities/payment.dart';
import '../../data/models/payment_list_item.dart';

abstract class PaymentRepository {
  /// Inserts a payment if its trxID is new. Returns the stored payment,
  /// or `null` if it was a duplicate (already exists).
  Future<Payment?> savePaymentIfNew(Payment payment);

  Future<List<Payment>> getPendingPayments();
  Future<PaymentStats> getStats();

  Future<void> markSynced(int localId, int backendId);
  Future<void> markFailed(int localId);
  Future<void> bumpRetry(int localId);

  /// Fetches the remote payment list (Payment List screen).
  Future<List<PaymentListItem>> fetchPaymentList({int page = 1});
}
