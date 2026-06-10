import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/payment_tile.dart';

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen> {
  final _scrollController = ScrollController();

  static const _filters = <String?, String>{
    null: 'All',
    'success': 'Success',
    'pending': 'Pending',
    'failed': 'Failed',
    'refunded': 'Refunded',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      // Pagination: load next page when near the bottom.
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(paymentListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredPaymentListProvider);
    final activeFilter = ref.watch(statusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search name, phone, TrxID, store...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filters.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: activeFilter == e.key,
                    onSelected: (_) =>
                        ref.read(statusFilterProvider.notifier).state = e.key,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(paymentListProvider.notifier).refresh(),
              child: filtered.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('Failed to load: $e'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref
                              .read(paymentListProvider.notifier)
                              .refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ]),
                data: (items) => items.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: Text('No payments found')),
                        ),
                      ])
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: items.length,
                        itemBuilder: (_, i) => PaymentTile(item: items[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
