import '../../core/app_logger.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../local/payment_db.dart';
import '../models/payment_list_item.dart';
import '../remote/api_client.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentDb _db;
  final ApiClient _api;

  PaymentRepositoryImpl(this._db, this._api);

  @override
  Future<Payment?> savePaymentIfNew(Payment payment) =>
      _db.insertIfNew(payment);

  @override
  Future<List<Payment>> getPendingPayments() => _db.pending();

  @override
  Future<PaymentStats> getStats() => _db.stats();

  @override
  Future<void> markSynced(int localId, int backendId) =>
      _db.markSynced(localId, backendId);

  @override
  Future<void> markFailed(int localId) => _db.markFailed(localId);

  @override
  Future<void> bumpRetry(int localId) => _db.bumpRetry(localId);

  @override
  Future<List<PaymentListItem>> fetchPaymentList({int page = 1}) async {
    final res = await _api.getPaymentList(page: page);
    final data = res.data;
    if (data is Map<String, dynamic> && data['status'] == 'success') {
      final list = data['data'] as List<dynamic>? ?? [];
      return list
          .map((e) => PaymentListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    appLogger.w('payment-list failed: ${res.statusCode} ${res.data}');
    throw Exception(
        (data is Map ? data['message'] : null) ?? 'Failed to load payments');
  }
}
