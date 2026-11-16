/// Payment policy configuration constants.

const String pendingReviewMessage = "Your payment is being checked. We'll confirm within 24 hours.";

/// Merchant GCash details for customer payments.
const String merchantGcashName = "PRY-ARR HARDWARE";
const String merchantGcashNumber = "0912 345 6789";

/// TODO: Owner to fill in underpaid refund/adjustment policy.
const String underpaidPolicy = "TODO: Underpaid orders require customer balance settlement or review.";

/// TODO: Owner to fill in overpaid refund policy.
const String overpaidPolicy = "TODO: Overpaid orders are credited or refunded upon verification.";

/// TODO: Owner to fill in payment not found / unmatched receipt policy.
const String notFoundPolicy = "TODO: Unmatched receipts are held for manual staff investigation.";

/// Orders at or above this amount require manual confirmation before fulfillment.
/// Set to 0 for now, so that all orders require review until the owner changes it.
const double highValueHoldThreshold = 0.0;
