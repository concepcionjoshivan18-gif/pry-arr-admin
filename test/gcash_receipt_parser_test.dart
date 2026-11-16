import 'package:flutter_test/flutter_test.dart';
import 'package:pry_arr/core/services/gcash_receipt_parser.dart';

void main() {
  group('GcashReceiptParser Tests', () {
    test('Variation 1: Same-line amount and reference', () {
      const sampleText = '''
        GP TSJVS Sta Cruz
        Paid via GCash
        Total Amount Sent P 350.00
        Date Oct 28, 2026 3:08 PM
        Reference No. 523856147
      ''';

      final receipt = GcashReceiptParser.parse(sampleText);
      expect(receipt.referenceNo, '523856147');
      expect(receipt.amount, 350.00);
      expect(receipt.date, 'Oct 28, 2026');
      expect(receipt.isComplete, true);
    });

    test('Variation 2: Amount on the next line', () {
      const sampleText = '''
        JO•N DA•E R.
        Sent via GCash
        Amount
        399.00
        Total Amount Sent P 399.00
        Ref No. 5045970462943
        Oct 10, 2026 4:09 PM
      ''';

      final receipt = GcashReceiptParser.parse(sampleText);
      expect(receipt.referenceNo, '5045970462943');
      expect(receipt.amount, 399.00);
      expect(receipt.date, 'Oct 10, 2026');
      expect(receipt.isComplete, true);
    });

    test('Variation 3: Missing reference number', () {
      const sampleText = '''
        GP TSJVS Sta Cruz
        Paid via GCash
        Total Amount Sent PHP 150.00
        October 28, 2026
      ''';

      final receipt = GcashReceiptParser.parse(sampleText);
      expect(receipt.referenceNo, null);
      expect(receipt.amount, 150.00);
      expect(receipt.date, 'October 28, 2026');
      expect(receipt.isComplete, false);
    });

    test('Variation 4: Spaced reference number with 100.00 amount', () {
      const sampleText = '''
        RE.....O J. C.
        +63 985 079 8279
        Sent via GCash
        Amount 100.00
        Total Amount Sent P 100.00
        Ref No. 5046 347 120037
        Oct 20, 2026 8:39 PM
      ''';

      final receipt = GcashReceiptParser.parse(sampleText);
      expect(receipt.referenceNo, '5046347120037');
      expect(receipt.amount, 100.00);
      expect(receipt.date, 'Oct 20, 2026');
      expect(receipt.isComplete, true);
    });
  });
}
