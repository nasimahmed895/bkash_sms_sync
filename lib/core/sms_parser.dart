import 'constants.dart';

/// Result of parsing a bKash received-payment SMS.
class ParsedBkashPayment {
  final String number;
  final double amount;
  final double balance;
  final String trxID;
  final String at; // raw "dd/MM/yyyy HH:mm" string, as required by the API

  const ParsedBkashPayment({
    required this.number,
    required this.amount,
    required this.balance,
    required this.trxID,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'amount': amount,
        'balance': balance,
        'trxID': trxID,
        'at': at,
      };
}

/// Parses & validates bKash "received payment" SMS messages.
///
/// Example:
///   You have received Tk 50.00 from 01540329236. Fee Tk 0.00.
///   Balance Tk 2,064.29. TrxID DFSJEI37HR83 at 04/06/2026 12:12
class BkashSmsParser {
  BkashSmsParser._();

  static final RegExp _receivedRe = RegExp(
    r'You have received Tk\s+([\d,]+(?:\.\d+)?)\s+from\s+(\+?\d{6,15})',
    caseSensitive: false,
  );
  static final RegExp _balanceRe = RegExp(
    r'Balance\s+Tk\s+([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  static final RegExp _trxRe = RegExp(r'TrxID\s+([A-Za-z0-9]+)');
  static final RegExp _atRe =
      RegExp(r'\bat\s+(\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2})');

  /// Quick keyword gate: every required keyword must be present.
  static bool looksLikeBkashPayment(String body) {
    return AppConstants.requiredKeywords.every(body.contains);
  }

  /// Whether the SMS sender matches a known bKash sender ID.
  static bool isKnownBkashSender(String? sender) {
    if (sender == null) return false;
    final s = sender.trim().toLowerCase();
    return AppConstants.bkashSenderIds.any((id) => s == id.toLowerCase());
  }

  static double _toDouble(String raw) =>
      double.parse(raw.replaceAll(',', ''));

  /// Returns the parsed payment, or `null` if the SMS is NOT a valid
  /// bKash received-payment message (in which case it must be ignored).
  static ParsedBkashPayment? parse(String body) {
    if (!looksLikeBkashPayment(body)) return null;

    final received = _receivedRe.firstMatch(body);
    final balance = _balanceRe.firstMatch(body);
    final trx = _trxRe.firstMatch(body);
    final at = _atRe.firstMatch(body);

    if (received == null || balance == null || trx == null || at == null) {
      return null;
    }

    try {
      return ParsedBkashPayment(
        amount: _toDouble(received.group(1)!),
        number: received.group(2)!,
        balance: _toDouble(balance.group(1)!),
        trxID: trx.group(1)!,
        at: at.group(1)!.replaceAll(RegExp(r'\s+'), ' '),
      );
    } catch (_) {
      return null;
    }
  }

  /// Like [parse] but tolerates missing timestamp — falls back to now.
  /// Use for notification text where the `at` field may be absent.
  static ParsedBkashPayment? parseNotification(String body) {
    if (!looksLikeBkashPayment(body)) return null;

    final received = _receivedRe.firstMatch(body);
    final balance = _balanceRe.firstMatch(body);
    final trx = _trxRe.firstMatch(body);

    if (received == null || balance == null || trx == null) return null;

    final atMatch = _atRe.firstMatch(body);
    final at = atMatch != null
        ? atMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ')
        : _nowFormatted();

    try {
      return ParsedBkashPayment(
        amount: _toDouble(received.group(1)!),
        number: received.group(2)!,
        balance: _toDouble(balance.group(1)!),
        trxID: trx.group(1)!,
        at: at,
      );
    } catch (_) {
      return null;
    }
  }

  static String _nowFormatted() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$d/$m/${now.year} $h:$min';
  }
}
