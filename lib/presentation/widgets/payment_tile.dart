import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/payment_list_item.dart';

class PaymentTile extends StatelessWidget {
  final PaymentListItem item;
  const PaymentTile({super.key, required this.item});

  Color _statusColor(String status) => switch (status.toLowerCase()) {
        'success' => Colors.green,
        'pending' => Colors.orange,
        'failed' => Colors.red,
        'refunded' => Colors.purple,
        _ => Colors.grey,
      };

  Future<void> _copyNumber(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.phone));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied ${item.phone}')),
      );
    }
  }

  Future<void> _callNumber() async {
    final uri = Uri(scheme: 'tel', path: item.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final p = item.payment;
    final color = _statusColor(p.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(p.status.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Store: ${item.storId}   •   Payment ID: ${p.paymentId}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(item.phone,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                IconButton(
                  tooltip: 'Copy number',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyNumber(context),
                ),
                IconButton(
                  tooltip: 'Call',
                  icon: const Icon(Icons.call, size: 18, color: Colors.green),
                  onPressed: _callNumber,
                ),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tk ${p.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Text(p.trxID,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(p.at, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
