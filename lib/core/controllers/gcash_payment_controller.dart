import '../services/gcash_receipt_parser.dart';

class GcashPaymentResult {
  final String paymentStatus; // "paid" or "pending_review"
  final String? reviewReason; // "wrong_amount", "missing_reference", "unreadable_image", "duplicate_reference"
  final bool blocked; // true only for duplicate reference

  const GcashPaymentResult({
    required this.paymentStatus,
    this.reviewReason,
    this.blocked = false,
  });
}

class GcashPaymentController {
  GcashPaymentResult evaluate(
    double orderTotal, {
    GcashReceipt? receipt,
    bool referenceAlreadyUsed = false,
  }) {
    // Rules, in this order:
    // a. If referenceNumber is already used in an existing order: blocked = true, reason "duplicate_reference".
    if (referenceAlreadyUsed) {
      return const GcashPaymentResult(
        paymentStatus: 'rejected',
        reviewReason: 'duplicate_reference',
        blocked: true,
      );
    }

    // b. If receipt is null or the image could not be read: paymentStatus "pending_review", reason "unreadable_image".
    if (receipt == null || receipt.rawText == null || receipt.rawText!.isEmpty || receipt.rawText!.contains('Failed')) {
      return const GcashPaymentResult(
        paymentStatus: 'pending_review',
        reviewReason: 'unreadable_image',
      );
    }

    // c. If referenceNumber is null: "pending_review", reason "missing_reference".
    if (receipt.referenceNumber == null || receipt.referenceNumber!.trim().isEmpty) {
      return const GcashPaymentResult(
        paymentStatus: 'pending_review',
        reviewReason: 'missing_reference',
      );
    }

    // d. If amount is null or differs from orderTotal by more than 0.01: "pending_review", reason "wrong_amount".
    if (receipt.amount == null || (receipt.amount! - orderTotal).abs() > 0.01) {
      return const GcashPaymentResult(
        paymentStatus: 'pending_review',
        reviewReason: 'wrong_amount',
      );
    }

    // e. Otherwise: paymentStatus "paid", reason null.
    return const GcashPaymentResult(
      paymentStatus: 'paid',
      reviewReason: null,
    );
  }
}
