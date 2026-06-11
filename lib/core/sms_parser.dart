import 'constants.dart';

/// Result of parsing a mobile-banking received-payment SMS (bKash / Nagad).
class ParsedPayment {
  final String provider; // 'bkash' | 'nagad'
  final String number;
  final double amount;
  final double balance;
  final String trxID;
  final String at; // raw "dd/MM/yyyy HH:mm" string, as required by the API

  const ParsedPayment({
    required this.provider,
    required this.number,
    required this.amount,
    required this.balance,
    required this.trxID,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'number': number,
        'amount': amount,
        'balance': balance,
        'trxID': trxID,
        'at': at,
      };
}

double _toDouble(String raw) => double.parse(raw.replaceAll(',', ''));

String _nowFormatted() {
  final now = DateTime.now();
  final d = now.day.toString().padLeft(2, '0');
  final m = now.month.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final min = now.minute.toString().padLeft(2, '0');
  return '$d/$m/${now.year} $h:$min';
}

/// Parses & validates bKash "received payment" SMS messages.
///
/// Example:
///   You have received Tk 50.00 from 01540329236. Fee Tk 0.00.
///   Balance Tk 2,064.29. TrxID DF40W73UA8 at 04/06/2026 12:12
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
    return AppConstants.bkashKeywords.every(body.contains);
  }

  /// Whether the SMS sender matches a known bKash sender ID.
  static bool isKnownBkashSender(String? sender) {
    if (sender == null) return false;
    final s = sender.trim().toLowerCase();
    return AppConstants.bkashSenderIds.any((id) => s == id.toLowerCase());
  }

  /// Returns the parsed payment, or `null` if the SMS is NOT a valid
  /// bKash received-payment message (in which case it must be ignored).
  static ParsedPayment? parse(String body, {bool requireTimestamp = true}) {
    if (!looksLikeBkashPayment(body)) return null;

    final received = _receivedRe.firstMatch(body);
    final balance = _balanceRe.firstMatch(body);
    final trx = _trxRe.firstMatch(body);
    final atMatch = _atRe.firstMatch(body);

    if (received == null || balance == null || trx == null) return null;
    if (requireTimestamp && atMatch == null) return null;

    final at = atMatch != null
        ? atMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ')
        : _nowFormatted();

    try {
      return ParsedPayment(
        provider: 'bkash',
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
}

/// Parses & validates Nagad "Money Received" SMS messages.
///
/// Example:
///   Money Received.
///   Amount: Tk 1195.00
///   Sender: 01781027895
///   Ref: subho
///   TxnID: 752C49K4
///   Balance: Tk 1209.80
///   14/03/2026 10:25
class NagadSmsParser {
  NagadSmsParser._();

  static final RegExp _amountRe = RegExp(
    r'Amount:\s*Tk\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  static final RegExp _senderRe = RegExp(
    r'Sender:\s*(\+?\d{6,15})',
    caseSensitive: false,
  );
  static final RegExp _trxRe = RegExp(
    r'TxnID:\s*([A-Za-z0-9]+)',
    caseSensitive: false,
  );
  static final RegExp _balanceRe = RegExp(
    r'Balance:\s*Tk\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );
  static final RegExp _atRe =
      RegExp(r'(\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2})');

  /// Quick keyword gate: every required keyword must be present.
  static bool looksLikeNagadPayment(String body) {
    return AppConstants.nagadKeywords.every(body.contains);
  }

  /// Whether the SMS sender matches a known Nagad sender ID.
  static bool isKnownNagadSender(String? sender) {
    if (sender == null) return false;
    final s = sender.trim().toLowerCase();
    return AppConstants.nagadSenderIds.any((id) => s == id.toLowerCase());
  }

  /// Returns the parsed payment, or `null` if the SMS is NOT a valid
  /// Nagad received-payment message (in which case it must be ignored).
  static ParsedPayment? parse(String body, {bool requireTimestamp = true}) {
    if (!looksLikeNagadPayment(body)) return null;

    final amount = _amountRe.firstMatch(body);
    final sender = _senderRe.firstMatch(body);
    final trx = _trxRe.firstMatch(body);
    final balance = _balanceRe.firstMatch(body);
    final atMatch = _atRe.firstMatch(body);

    if (amount == null || sender == null || trx == null || balance == null) {
      return null;
    }
    if (requireTimestamp && atMatch == null) return null;

    final at = atMatch != null
        ? atMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ')
        : _nowFormatted();

    try {
      return ParsedPayment(
        provider: 'nagad',
        amount: _toDouble(amount.group(1)!),
        number: sender.group(1)!,
        balance: _toDouble(balance.group(1)!),
        trxID: trx.group(1)!,
        at: at,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Unified entry point — tries every supported provider in order.
class PaymentSmsParser {
  PaymentSmsParser._();

  /// Strict parse for SMS bodies (timestamp required).
  static ParsedPayment? parse(String body) {
    return BkashSmsParser.parse(body) ?? NagadSmsParser.parse(body);
  }

  /// Lenient parse for notification text — missing timestamp falls
  /// back to the current time.
  static ParsedPayment? parseNotification(String body) {
    return BkashSmsParser.parse(body, requireTimestamp: false) ??
        NagadSmsParser.parse(body, requireTimestamp: false);
  }

  /// Whether the SMS sender is a known sender ID for the given provider.
  static bool isKnownSender(String provider, String? sender) {
    return switch (provider) {
      'bkash' => BkashSmsParser.isKnownBkashSender(sender),
      'nagad' => NagadSmsParser.isKnownNagadSender(sender),
      _ => false,
    };
  }
}
