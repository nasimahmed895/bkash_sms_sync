/// Item from GET /api/payment-list.
class PaymentListItem {
  final String name;
  final String phone;
  final String storId;
  final RemotePayment payment;

  const PaymentListItem({
    required this.name,
    required this.phone,
    required this.storId,
    required this.payment,
  });

  factory PaymentListItem.fromJson(Map<String, dynamic> json) =>
      PaymentListItem(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        storId: json['storId'] as String? ?? '',
        payment:
            RemotePayment.fromJson(json['payment'] as Map<String, dynamic>),
      );
}

class RemotePayment {
  final String id;
  final String paymentId;
  final String phone;
  final String status; // success | pending | failed | refunded
  final double amount;
  final String trxID;
  final String at;

  const RemotePayment({
    required this.id,
    required this.paymentId,
    required this.phone,
    required this.status,
    required this.amount,
    required this.trxID,
    required this.at,
  });

  factory RemotePayment.fromJson(Map<String, dynamic> json) => RemotePayment(
        id: json['id'].toString(),
        paymentId: json['paymentId'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        trxID: json['trxID'] as String? ?? '',
        at: json['at'] as String? ?? '',
      );
}
