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

    test('sets provider to bkash', () {
      expect(BkashSmsParser.parse(valid)!.provider, 'bkash');
    });
  });

  group('NagadSmsParser', () {
    const valid = 'Money Received.\n'
        'Amount: Tk 1195.00\n'
        'Sender: 01781027895\n'
        'Ref: subho\n'
        'TxnID: 752C49K4\n'
        'Balance: Tk 1209.80\n'
        '14/03/2026 10:25';

    test('parses a valid Nagad received-payment SMS', () {
      final p = NagadSmsParser.parse(valid);
      expect(p, isNotNull);
      expect(p!.provider, 'nagad');
      expect(p.number, '01781027895');
      expect(p.amount, 1195.00);
      expect(p.balance, 1209.80);
      expect(p.trxID, '752C49K4');
      expect(p.at, '14/03/2026 10:25');
    });

    test('ignores a Nagad cash-out / sent SMS', () {
      const sent = 'Cash Out.\n'
          'Amount: Tk 500.00\n'
          'Receiver: 01711111111\n'
          'TxnID: AB12CD34\n'
          'Balance: Tk 100.00\n'
          '01/01/2026 10:00';
      expect(NagadSmsParser.parse(sent), isNull);
    });

    test('ignores random SMS', () {
      expect(NagadSmsParser.parse('Your OTP is 123456'), isNull);
    });

    test('ignores message missing TxnID', () {
      const noTrx = 'Money Received.\n'
          'Amount: Tk 100.00\n'
          'Sender: 01781027895\n'
          'Balance: Tk 200.00\n'
          '14/03/2026 10:25';
      expect(NagadSmsParser.parse(noTrx), isNull);
    });

    test('parses amounts with thousands separators', () {
      const big = 'Money Received.\n'
          'Amount: Tk 12,500.50\n'
          'Sender: 01781027895\n'
          'Ref: shop\n'
          'TxnID: ZZ99YY88\n'
          'Balance: Tk 13,000.00\n'
          '14/03/2026 10:25';
      final p = NagadSmsParser.parse(big);
      expect(p!.amount, 12500.50);
      expect(p.balance, 13000.00);
    });

    test('recognizes known Nagad senders', () {
      expect(NagadSmsParser.isKnownNagadSender('NAGAD'), isTrue);
      expect(NagadSmsParser.isKnownNagadSender('16167'), isTrue);
      expect(NagadSmsParser.isKnownNagadSender('+8801999999999'), isFalse);
    });
  });

  group('PaymentSmsParser', () {
    test('routes bKash SMS to bkash provider', () {
      const sms = 'You have received Tk 50.00 from 01540329236. Fee Tk 0.00. '
          'Balance Tk 2,064.29. TrxID DF40W73UA8 at 04/06/2026 12:12';
      expect(PaymentSmsParser.parse(sms)!.provider, 'bkash');
    });

    test('routes Nagad SMS to nagad provider', () {
      const sms = 'Money Received.\n'
          'Amount: Tk 1195.00\n'
          'Sender: 01781027895\n'
          'Ref: subho\n'
          'TxnID: 752C49K4\n'
          'Balance: Tk 1209.80\n'
          '14/03/2026 10:25';
      expect(PaymentSmsParser.parse(sms)!.provider, 'nagad');
    });

    test('notification parse tolerates missing timestamp', () {
      const noTime = 'Money Received.\n'
          'Amount: Tk 1195.00\n'
          'Sender: 01781027895\n'
          'TxnID: 752C49K4\n'
          'Balance: Tk 1209.80';
      expect(PaymentSmsParser.parse(noTime), isNull);
      final p = PaymentSmsParser.parseNotification(noTime);
      expect(p, isNotNull);
      expect(p!.at, isNotEmpty);
    });
  });
}
