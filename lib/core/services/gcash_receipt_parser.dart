class GcashReceipt {
  final String? referenceNo;
  final double? amount;
  final String? date;
  final String? rawText;

  const GcashReceipt({
    String? referenceNo,
    String? referenceNumber,
    this.amount,
    this.date,
    this.rawText,
  }) : referenceNo = referenceNo ?? referenceNumber;

  String? get referenceNumber => referenceNo;
  bool get isComplete => referenceNo != null && referenceNo!.isNotEmpty && amount != null && amount! > 0;
}

class GcashReceiptParser {
  static GcashReceipt parse(String text) {
    if (text.isEmpty) {
      return GcashReceipt(rawText: text);
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? referenceNo;
    double? amount;
    String? date;

    // 1. Reference No. matching: Look for "Ref" or "Reference" label, check same line or next line for digits (with optional spaces/dashes)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (line.contains('ref') || line.contains('reference')) {
        // Check digits on same line (excluding the word 'ref' itself)
        final digitsOnlySame = lines[i].replaceAll(RegExp(r'[a-zA-Z\.\#\:]'), '');
        final cleanedSame = digitsOnlySame.replaceAll(RegExp(r'[\s\-]+'), '');
        if (cleanedSame.length >= 8 && cleanedSame.length <= 16 && !cleanedSame.startsWith('639')) {
          referenceNo = cleanedSame;
          break;
        }

        // Check next line
        if (i + 1 < lines.length) {
          final digitsOnlyNext = lines[i + 1].replaceAll(RegExp(r'[a-zA-Z\.\#\:]'), '');
          final cleanedNext = digitsOnlyNext.replaceAll(RegExp(r'[\s\-]+'), '');
          if (cleanedNext.length >= 8 && cleanedNext.length <= 16 && !cleanedNext.startsWith('639')) {
            referenceNo = cleanedNext;
            break;
          }
        }
      }
    }

    // Fallback: search for any 10-16 digit number starting with '5' (GCash reference number prefix)
    if (referenceNo == null) {
      final gcashRefRegExp = RegExp(r'\b(5[0-9\s\-]{9,15})\b');
      for (var line in lines) {
        final match = gcashRefRegExp.firstMatch(line);
        if (match != null) {
          final cleaned = match.group(1)?.replaceAll(RegExp(r'[\s\-]+'), '') ?? '';
          if (cleaned.length >= 10 && cleaned.length <= 16) {
            referenceNo = cleaned;
            break;
          }
        }
      }
    }

    // 2. Amount matching: peso values (₱, PHP, or P prefix) with two decimals and optional commas.
    // Prefer value on the same line as "amount" or "sent", or next line. Fall back to first peso amount in text.
    final amountRegExp = RegExp(r'(?:₱|PHP|P)\s*([\d,]+\.\d{2})', caseSensitive: false);
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.toLowerCase().contains('amount') || line.toLowerCase().contains('sent') || line.toLowerCase().contains('total')) {
        final match = amountRegExp.firstMatch(line);
        if (match != null) {
          final amtStr = match.group(1)?.replaceAll(',', '');
          amount = double.tryParse(amtStr ?? '');
          break;
        } else if (i + 1 < lines.length) {
          final nextMatch = amountRegExp.firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            final amtStr = nextMatch.group(1)?.replaceAll(',', '');
            amount = double.tryParse(amtStr ?? '');
            break;
          }
        }
      }
    }
    if (amount == null) {
      for (var line in lines) {
        final match = amountRegExp.firstMatch(line);
        if (match != null) {
          final amtStr = match.group(1)?.replaceAll(',', '');
          amount = double.tryParse(amtStr ?? '');
          if (amount != null) break;
        }
      }
    }

    // 3. Date matching: formats like "Oct 28, 2026" or "October 28, 2026"
    final dateRegExp = RegExp(r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4}', caseSensitive: false);
    for (var line in lines) {
      final match = dateRegExp.firstMatch(line);
      if (match != null) {
        date = match.group(0);
        break;
      }
    }

    return GcashReceipt(
      referenceNo: referenceNo,
      amount: amount,
      date: date,
      rawText: text,
    );
  }
}
