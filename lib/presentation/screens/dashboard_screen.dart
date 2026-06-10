import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final money = NumberFormat.currency(symbol: 'Tk ', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(statsProvider.future),
        child: stats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load stats: $e'),
            )
          ]),
          data: (s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(
                title: 'Total Payments',
                value: '${s.totalPayments}',
                icon: Icons.receipt_long,
                color: Colors.blue,
              ),
              _StatCard(
                title: 'Total Amount',
                value: money.format(s.totalAmount),
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
              ),
              _StatCard(
                title: 'Successful Payments',
                value: '${s.successful}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _StatCard(
                title: 'Pending Sync',
                value: '${s.pendingSync}',
                icon: Icons.sync,
                color: Colors.orange,
              ),
              _StatCard(
                title: 'Failed Payments',
                value: '${s.failed}',
                icon: Icons.error,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        trailing: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
