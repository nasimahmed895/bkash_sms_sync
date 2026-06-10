import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/payment_list_item.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_repository.dart';
import '../../services/service_locator.dart';

/// Local dashboard stats (from SQLite).
final statsProvider = FutureProvider.autoDispose<PaymentStats>((ref) {
  return sl<PaymentRepository>().getStats();
});

/// Status filter for the payment list screen. null = all.
final statusFilterProvider = StateProvider<String?>((ref) => null);

/// Search query for the payment list screen.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Paginated remote payment list with pull-to-refresh support.
class PaymentListNotifier
    extends StateNotifier<AsyncValue<List<PaymentListItem>>> {
  PaymentListNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  Future<void> refresh() async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final items = await sl<PaymentRepository>().fetchPaymentList(page: 1);
      _hasMore = items.isNotEmpty;
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore) return;
    final current = state.valueOrNull;
    if (current == null) return;

    _loadingMore = true;
    try {
      final next =
          await sl<PaymentRepository>().fetchPaymentList(page: _page + 1);
      if (next.isEmpty) {
        _hasMore = false;
      } else {
        _page++;
        state = AsyncValue.data([...current, ...next]);
      }
    } catch (_) {
      // keep current data; user can retry by scrolling again
    } finally {
      _loadingMore = false;
    }
  }
}

final paymentListProvider = StateNotifierProvider.autoDispose<
    PaymentListNotifier, AsyncValue<List<PaymentListItem>>>(
  (ref) => PaymentListNotifier(),
);

/// Filtered + searched view of the payment list.
final filteredPaymentListProvider =
    Provider.autoDispose<AsyncValue<List<PaymentListItem>>>((ref) {
  final list = ref.watch(paymentListProvider);
  final filter = ref.watch(statusFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return list.whenData((items) {
    return items.where((item) {
      final matchesFilter =
          filter == null || item.payment.status.toLowerCase() == filter;
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          item.phone.toLowerCase().contains(query) ||
          item.storId.toLowerCase().contains(query) ||
          item.payment.trxID.toLowerCase().contains(query) ||
          item.payment.paymentId.toLowerCase().contains(query);
    }).toList();
  });
});
