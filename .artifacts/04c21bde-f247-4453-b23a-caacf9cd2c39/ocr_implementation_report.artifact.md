# GCash Receipt OCR Scanning & Verification Implementation Report

This report outlines the implementation of on-device OCR receipt scanning using **Google ML Kit Text Recognition** for GCash payments, integrated seamlessly into the customer checkout flow.

## 1. Deliverables & Platform Setup

### Updated `pubspec.yaml`
```yaml
dependencies:
  google_mlkit_text_recognition: ^0.14.0
  image_picker: ^1.1.2
```

### Platform Setup Steps

#### Android (`android/app/build.gradle`)
Ensure `minSdkVersion` is at least 21:
```groovy
defaultConfig {
    minSdkVersion 21
    // ...
}
```

#### iOS (`ios/Podfile` & `ios/Runner/Info.plist`)
1. **Podfile:** Set minimum iOS platform version to 15.5:
   ```ruby
   platform :ios, '15.5'
   ```
2. **Info.plist:** Add camera and photo library usage descriptions:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>We need camera access to take a photo of your GCash payment receipt.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>We need photo library access to upload your GCash payment receipt screenshot.</string>
   ```

---

## 2. Core Components

### [ReceiptOcrService](file:///C:/Users/RONALYN/StudioProjects/pry_arr/lib/core/services/receipt_ocr_service.dart)
Takes an image path, runs Google ML Kit `TextRecognizer`, returns full OCR text, and guarantees `textRecognizer.close()` in a `finally` block.

### [GcashReceiptParser](file:///C:/Users/RONALYN/StudioProjects/pry_arr/lib/core/services/gcash_receipt_parser.dart)
Parses raw OCR text into nullable fields (`referenceNo`, `amount`, `date`) and provides an `isComplete` getter with robust fallbacks and zero exceptions on missing fields.

### Checkout Bottom Sheet & Flow
Integrated into `CheckoutScreen` (`lib/app/screens/checkout_screen.dart`), allowing customers to pick/capture an image, run OCR, review/correct extracted values in editable text fields, check amount tolerance (0.01 tolerance against order total), and submit.

### Firestore Submission & Fraud Rules
- Checks for duplicate `referenceNo` across existing orders.
- Validates expected total against Firestore/server order total.
- Sets `paymentStatus` to `"pending_verification"`.
- Secures receipt images.

---

## 3. Unit Tests
Parser unit tests implemented in [gcash_receipt_parser_test.dart](file:///C:/Users/RONALYN/StudioProjects/pry_arr/test/gcash_receipt_parser_test.dart) covering same-line amounts, next-line amounts, and missing references.

---

## 4. Real-Device Verification Checklist (10–20 GCash Screenshots)
When testing on a physical Android/iOS device with 10–20 sample GCash screenshots, verify:
1. **Camera vs Gallery:** Successfully picking from gallery and capturing via camera without permission crashes.
2. **Same-Line Amounts:** Accurate extraction when "₱ 350.00" is on the same line as "Total Amount Sent".
3. **Next-Line Amounts:** Accurate extraction when the amount appears on the line immediately following "Amount".
4. **Reference Numbers:** Correct extraction of 9 to 13-digit reference numbers (e.g., `523856147`, `5045970462943`).
5. **Dates:** Accurate date parsing (e.g., `Oct 28, 2026`).
6. **Tolerance Check:** Warning displayed if edited amount differs from order total by more than 0.01.
7. **Duplicate Rejection:** Attempting to submit a receipt with an already-used reference number correctly triggers a duplicate rejection error.
8. **Pending Status:** Order correctly stores `paymentStatus: "pending_verification"` in Firestore.
