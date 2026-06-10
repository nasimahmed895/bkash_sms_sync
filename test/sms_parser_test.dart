import 'package:flutter_test/flutter_test.dart';
import 'package:bkash_sms_sync/core/sms_parser.dart';

void main() {
  group('BkashSmsParser', () {
    const valid =
        'You have received Tk 50.00 from 01540329236. Fee Tk 0.00. '
        'Balance Tk 2,064.29. TrxID DFSJEI37HR83 at 04/06/2026 12:12';

    test('parses a valid bKash received-payment SMS', () {
      final p = BkashSmsParser.parse(valid);
      expect(p, isNotNull);
      expect(p!.number, '01540329236');
      expect(p.amount, 50.00);
      expect(p.balance, 2064.29);
      expect(p.trxID, 'DFSJEI37HR83');
      expect(p.at, '04/06/2026 12:12');
    });

    test('ignores a sent-money SMS', () {
      const sent =
          'You have sent Tk 100.00 to 01711111111. Fee Tk 5.00. '
          'Balance Tk 500.00. TrxID ABCD1234 at 01/01/2026 10:00';
      expect(BkashSmsParser.parse(sent), isNull);
    });

    test('ignores random SMS', () {
      expect(BkashSmsParser.parse('Your OTP is 123456'), isNull);
    });

    test('ignores message missing TrxID', () {
      const noTrx =
          'You have received Tk 50.00 from 01540329236. Balance Tk 100.00.';
      expect(BkashSmsParser.parse(noTrx), isNull);
    });

    test('parses amounts with thousands separators', () {
      const big =
          'You have received Tk 1,250.50 from 01540329236. Fee Tk 0.00. '
          'Balance Tk 12,064.29. TrxID XYZ987 at 04/06/2026 12:12';
      final p = BkashSmsParser.parse(big);
      expect(p!.amount, 1250.50);
      expect(p.balance, 12064.29);
    });

    test('recognizes known bKash senders', () {
      expect(BkashSmsParser.isKnownBkashSender('bKash'), isTrue);
      expect(BkashSmsParser.isKnownBkashSender('16247'), isTrue);
      expect(BkashSmsParser.isKnownBkashSender('+8801999999999'), isFalse);
    });
  });
}
