import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/order.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_database_service.dart';
import '../../core/services/receipt_ocr_service.dart';
import '../../core/services/gcash_receipt_parser.dart';
import '../../core/controllers/gcash_payment_controller.dart';
import '../../core/config/payment_policy.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';
import '../../core/services/google_maps_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'digital_receipt_screen.dart';

const double expressFee = 150.0;

class CheckoutScreen extends StatefulWidget {
  final List<CartItem>? buyNowItems;
  const CheckoutScreen({super.key, this.buyNowItems});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final addressController = TextEditingController();
  String speed = 'Standard'; // 'Standard' | 'Express'
  String payment = 'GCash'; // 'GCash' | 'Card' | 'COD'
  bool redeem = false;
  int redeemPts = 0;
  bool placing = false, addressError = false;

  // Pinned location for delivery map navigation
  double? pinnedLat = 14.2818;
  double? pinnedLng = 121.4167;
  bool isLocationPinned = false;

  // GCash receipt state
  GcashReceipt? uploadedReceipt;
  String? receiptImageUrl;
  bool isScanning = false;
  final gcashRefController = TextEditingController();
  final gcashAmountController = TextEditingController();
  final pointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultAddressAndGps();
    });
  }

  void _initDefaultAddressAndGps() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      if (user.shippingAddresses.isNotEmpty && user.shippingAddresses.first.isNotEmpty) {
        setState(() {
          addressController.text = user.shippingAddresses.first;
          addressError = false;
          isLocationPinned = true;
        });
      } else if (user.address != null && user.address!.isNotEmpty) {
        setState(() {
          addressController.text = user.address!;
          addressError = false;
          isLocationPinned = true;
        });
      }
    }

    // Auto-detect phone GPS location if address field is still empty
    if (addressController.text.trim().isEmpty) {
      _autoDetectGpsLocation();
    }
  }

  void _autoDetectGpsLocation() async {
    final liveGps = await GoogleMapsService.getCurrentGpsLocation();
    final phoneLat = liveGps?['lat'] ?? 14.2818;
    final phoneLng = liveGps?['lng'] ?? 121.4167;
    final resolvedAddr = await GoogleMapsService.reverseGeocode(phoneLat, phoneLng);

    if (mounted) {
      setState(() {
        pinnedLat = phoneLat;
        pinnedLng = phoneLng;
        isLocationPinned = true;
        addressController.text = resolvedAddr ?? 'Santa Cruz, Laguna, Philippines';
        addressError = false;
      });
      showTopNotification(context, 'Live phone GPS location auto-filled!', isSuccess: true);
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    gcashRefController.dispose();
    gcashAmountController.dispose();
    pointsController.dispose();
    super.dispose();
  }

  List<CartItem> _getCheckoutItems(CartProvider cartProvider) {
    if (widget.buyNowItems != null && widget.buyNowItems!.isNotEmpty) {
      return widget.buyNowItems!;
    }
    return cartProvider.selectedItems;
  }

  double get subtotal {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final items = _getCheckoutItems(cartProvider);
    return items.fold<double>(0.0, (sum, item) => sum + (item.price * item.qty));
  }

  double get shipping => speed == 'Express' ? expressFee : 0.0;
  
  int get userPoints {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    return user?.loyaltyPoints ?? 0;
  }

  int get maxRedeem => math.min(userPoints, ((subtotal + shipping) / 0.2).floor());
  int get usedPts => redeem ? math.min(redeemPts, maxRedeem) : 0;
  double get discount => usedPts * 0.2;
  double get total => subtotal + shipping - discount;
  int get earn => (subtotal * 0.1).toInt();

  void snack(String msg, {bool error = false}) {
    showTopNotification(context, msg, isError: error, isSuccess: !error);
  }

  void _showImageSourceDialog() {
    if (kIsWeb) {
      _scanGcashReceipt(ImageSource.gallery);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload GCash Receipt'),
        content: const Text('Choose how you would like to attach your receipt:'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _scanGcashReceipt(ImageSource.camera);
            },
            icon: const Icon(Icons.camera_alt_rounded, color: hwOrange),
            label: const Text('Take Photo (Camera)'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _scanGcashReceipt(ImageSource.gallery);
            },
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Choose from Gallery'),
            style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _scanGcashReceipt(ImageSource source) async {
    try {
      Uint8List? fileBytes;
      String? filePath;

      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
        if (result == null || result.files.single.bytes == null) return;
        fileBytes = result.files.single.bytes;
        filePath = result.files.single.name;
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile == null) return;
        fileBytes = await pickedFile.readAsBytes();
        filePath = pickedFile.path;
      }

      setState(() => isScanning = true);

      final base64Image = 'data:image/jpeg;base64,${base64Encode(fileBytes!)}';
      final receipt = await ReceiptOcrService().scanReceipt(filePath);

      if (receipt.referenceNo == null || receipt.amount == null) {
        snack('Invalid GCash receipt: Could not detect reference number or amount. Please upload a valid GCash receipt screenshot.', error: true);
        setState(() {
          uploadedReceipt = null;
          receiptImageUrl = null;
          gcashRefController.clear();
          gcashAmountController.clear();
        });
        return;
      }

      setState(() {
        uploadedReceipt = receipt;
        receiptImageUrl = base64Image;
        gcashRefController.text = receipt.referenceNo ?? '';
        gcashAmountController.text = receipt.amount != null ? receipt.amount!.toStringAsFixed(2) : total.toStringAsFixed(2);
      });
      snack('GCash receipt attached successfully!', error: false);
    } catch (e) {
      snack('Failed to pick or scan receipt: $e', error: true);
    } finally {
      setState(() => isScanning = false);
    }
  }

  Future<void> place() async {
    if (addressController.text.trim().isEmpty) {
      setState(() => addressError = true);
      snack('Please enter your delivery address', error: true);
      return;
    }

    if (payment == 'GCash' && uploadedReceipt == null) {
      snack('Please upload your GCash receipt to proceed with GCash payment', error: true);
      return;
    }

    // Capture total and other checkout values before cart modification
    final double checkoutTotal = total;
    final double checkoutDiscount = discount;
    final int checkoutEarn = earn;
    final List<CartItem> checkoutItemsCopy = List.from(_getCheckoutItems(Provider.of<CartProvider>(context, listen: false)));
    final String checkoutPaymentMethod = payment == 'COD' ? 'Cash on Delivery (COD)' : 'GCash';

    if (checkoutItemsCopy.isEmpty) {
      snack('Your cart is empty', error: true);
      return;
    }

    setState(() => placing = true);

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        setState(() => placing = false);
        return;
      }

      final String? refNo = gcashRefController.text.trim().isNotEmpty ? gcashRefController.text.trim() : uploadedReceipt?.referenceNumber;
      final double? amt = double.tryParse(gcashAmountController.text.trim()) ?? uploadedReceipt?.amount;

      // GCash Strict Validation & Error Handling
      if (payment == 'GCash') {
        if (refNo == null || refNo.isEmpty) {
          setState(() => placing = false);
          snack('Please provide a valid GCash reference number', error: true);
          return;
        }

        if (amt == null || (amt - checkoutTotal).abs() > 0.01) {
          setState(() => placing = false);
          snack('GCash amount paid (₱${amt?.toStringAsFixed(2) ?? '0.00'}) does not match order total (₱${checkoutTotal.toStringAsFixed(2)})', error: true);
          return;
        }

        // Duplicate reference number check
        final bool alreadyUsed = await firestoreService.checkGcashReferenceExists(refNo);
        if (alreadyUsed) {
          setState(() => placing = false);
          snack('This GCash receipt was already used.', error: true);
          return;
        }
      }

      String paymentStatus = payment == 'GCash' ? 'paid' : 'paid';
      String? reviewReason;

      final address = addressController.text.trim();

      await firestoreService.placeOrder(
        customerId: user.uid,
        items: checkoutItemsCopy,
        total: checkoutTotal,
        pointsEarned: checkoutEarn,
        pointsRedeemed: usedPts,
        discountAmount: checkoutDiscount,
        fulfillmentType: 'Home Delivery ($speed) - $address',
        paymentMethod: payment,
        paymentStatus: paymentStatus,
        gcashReferenceNumber: refNo,
        gcashAmount: amt,
        reviewReason: reviewReason,
        receiptImageUrl: receiptImageUrl,
        deliveryLat: pinnedLat ?? 14.2818,
        deliveryLng: pinnedLng ?? 121.4167,
        deliveryAddress: address,
      );

      if (widget.buyNowItems == null || widget.buyNowItems!.isEmpty) {
        cartProvider.removeSelected();
      }

      if (!mounted) return;
      setState(() => placing = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DigitalReceiptScreen(
            items: checkoutItemsCopy,
            total: checkoutTotal,
            pointsEarned: checkoutEarn,
            discount: checkoutDiscount,
            paymentMethod: checkoutPaymentMethod,
          ),
        ),
      );
    } catch (e) {
      try {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;
        if (user != null) {
          final orderId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
          final orderMap = OrderModel(
            id: orderId,
            customerId: user.uid,
            items: checkoutItemsCopy,
            status: 'pending',
            total: checkoutTotal,
            createdAt: DateTime.now(),
            pointsEarned: checkoutEarn,
            pointsRedeemed: usedPts,
            fulfillmentType: 'Home Delivery ($speed) - ${addressController.text.trim()}',
            paymentMethod: payment,
            paymentStatus: 'paid',
            gcashReferenceNumber: uploadedReceipt?.referenceNumber,
            gcashAmount: uploadedReceipt?.amount,
            receiptImageUrl: receiptImageUrl,
          ).toMap();

          await LocalDatabaseService().saveOfflineOrder(orderId, orderMap);

          if (widget.buyNowItems == null || widget.buyNowItems!.isEmpty) {
            cartProvider.removeSelected();
          }

          if (!mounted) return;
          setState(() => placing = false);

          snack('Offline mode: Order saved locally & queued for sync!');

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DigitalReceiptScreen(
                items: checkoutItemsCopy,
                total: checkoutTotal,
                pointsEarned: checkoutEarn,
                discount: checkoutDiscount,
                paymentMethod: checkoutPaymentMethod,
              ),
            ),
          );
          return;
        }
      } catch (localErr) {
        debugPrint('Local offline save error: $localErr');
      }

      if (mounted) {
        snack('Error: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => placing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = Provider.of<AuthService>(context).currentUser;

    return StreamBuilder<List<OrderModel>>(
      stream: firestoreService.streamAllOrders(),
      builder: (context, snapshot) {
        final allOrders = snapshot.data ?? [];
        final customerOrders = allOrders.where((o) => o.customerId == (user?.uid ?? '')).toList();
        final bool verified = customerOrders.any((o) => o.status == 'completed' || o.paymentMethod == 'GCash' || o.paymentMethod == 'Card');

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _header(p, verified),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    children: [
                      _title(p, 'Delivery address'),
                      _addressCard(p),
                      _title(p, 'Delivery speed'),
                      _speedRow(p),
                      _title(p, 'Payment method'),
                      _paymentSection(p, verified),
                      if (payment == 'GCash') ...[
                        const SizedBox(height: 12),
                        _gcashReceiptSection(p),
                      ],
                      _title(p, 'Rewards'),
                      _rewards(p),
                      _title(p, 'Order summary'),
                      _summary(p),
                    ],
                  ),
                ),
                _bottomBar(p),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(Pal p, bool verified) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Glass(
            radius: 22,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_rounded, color: p.text, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Checkout & Delivery', style: ts(p.faint, 13)),
                const SizedBox(height: 2),
                Text('Secure Payment', style: ts(p.text, 24, FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(Pal p, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(t, style: ts(p.text, 16, FontWeight.w800)),
      );

  Widget _addressCard(Pal p) {
    final user = Provider.of<AuthService>(context).currentUser;
    final registeredAddresses = user?.shippingAddresses ?? [];

    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (registeredAddresses.isNotEmpty) ...[
            Text('Pick from your registered addresses:', style: ts(p.sub, 12, FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: p.fill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text('Select registered address...', style: ts(p.faint, 13)),
                  items: registeredAddresses.map((addr) => DropdownMenuItem<String>(
                    value: addr,
                    child: Text(addr, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(p.text, 13)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        addressController.text = val;
                        addressError = false;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Or enter manually below:', style: ts(p.sub, 12, FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: addressController,
            maxLines: 2,
            style: ts(p.text, 14),
            onChanged: (_) => setState(() => addressError = false),
            decoration: InputDecoration(
              hintText: 'Enter complete delivery address or detect GPS...',
              hintStyle: ts(p.faint, 14),
              prefixIcon: Icon(Icons.location_on_outlined, color: addressError ? p.danger : p.faint),
              suffixIcon: IconButton(
                icon: const Icon(Icons.my_location_rounded, color: hwOrange),
                tooltip: 'Auto-Detect Phone GPS Location',
                onPressed: () => _autoDetectGpsLocation(),
              ),
              filled: true,
              fillColor: p.fill,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              border: b(addressError ? p.danger : p.line),
              enabledBorder: b(addressError ? p.danger : p.line),
              focusedBorder: b(addressError ? p.danger : hwOrange, 1.5),
            ),
          ),
          if (addressError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Address is required', style: ts(p.danger, 12, FontWeight.w600)),
            ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showPinLocationModal(context, p),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isLocationPinned ? hwOrange.withValues(alpha: 0.15) : p.fill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isLocationPinned ? hwOrange : p.line),
              ),
              child: Row(
                children: [
                  Icon(
                    isLocationPinned ? Icons.pin_drop_rounded : Icons.add_location_alt_rounded,
                    color: isLocationPinned ? hwOrange : p.sub,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLocationPinned ? 'Delivery Location Pinned on Map' : 'Pin Location on Google Maps for Driver',
                          style: ts(isLocationPinned ? hwOrange : p.text, 13, FontWeight.w700),
                        ),
                        Text(
                          isLocationPinned
                              ? 'GPS Coordinates: ${pinnedLat?.toStringAsFixed(4)}° N, ${pinnedLng?.toStringAsFixed(4)}° E'
                              : 'Tap to set exact Google Maps pin for rider navigation',
                          style: ts(p.faint, 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.faint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPinLocationModal(BuildContext context, Pal p) {
    GoogleMapController? modalMapController;
    final sanitizedInit = GoogleMapsService.sanitizeCoordinates(pinnedLat ?? 14.2818, pinnedLng ?? 121.4167);
    double tempLat = sanitizedInit['lat']!;
    double tempLng = sanitizedInit['lng']!;
    bool isGeocoding = false;
    bool isDetectingGps = false;
    bool saveToProfile = false;
    final searchCtrl = TextEditingController(text: addressController.text.trim());
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = authService.currentUser;
    final savedAddresses = user?.shippingAddresses ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.pop(ctx),
                        onVerticalDragEnd: (details) {
                          if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                            Navigator.pop(ctx);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 5,
                              decoration: BoxDecoration(color: p.faint.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded, color: hwOrange, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Pin Delivery Location', style: ts(p.text, 18, FontWeight.w800)),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: p.faint),
                            onPressed: () => Navigator.pop(ctx),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Choose how you want to pin your exact house location for your rider:', style: ts(p.faint, 12)),
                      const SizedBox(height: 14),

                      // OPTION 1: DETECT PHONE GPS LOCATION
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: isDetectingGps
                              ? null
                              : () async {
                                  setModalState(() => isDetectingGps = true);
                                  final liveGps = await GoogleMapsService.getCurrentGpsLocation();
                                  final phoneLat = liveGps?['lat'] ?? 14.2818;
                                  final phoneLng = liveGps?['lng'] ?? 121.4167;

                                  final resolvedAddr = await GoogleMapsService.reverseGeocode(phoneLat, phoneLng) ?? 'Santa Cruz, Laguna, Philippines';
                                  setModalState(() {
                                    tempLat = phoneLat;
                                    tempLng = phoneLng;
                                    searchCtrl.text = resolvedAddr;
                                    isDetectingGps = false;
                                  });
                                  setState(() {
                                    pinnedLat = phoneLat;
                                    pinnedLng = phoneLng;
                                    isLocationPinned = true;
                                    addressController.text = resolvedAddr;
                                    addressError = false;
                                  });
                                  if (ctx.mounted) {
                                    showTopNotification(ctx, 'Live phone GPS location pinned successfully!', isSuccess: true);
                                  }
                                },
                          icon: isDetectingGps
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            isDetectingGps ? 'DETECTING PHONE GPS...' : 'USE MY PHONE GPS LOCATION',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // OPTION 2: SEARCH HOUSE / STREET ADDRESS ON GOOGLE MAPS
                      Text('Or Search House / Street Address:', style: ts(p.text, 13, FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              style: ts(p.text, 13),
                              decoration: InputDecoration(
                                hintText: 'Enter house no., street, barangay, city...',
                                hintStyle: ts(p.faint, 12),
                                prefixIcon: const Icon(Icons.search_rounded, color: hwOrange, size: 20),
                                filled: true,
                                fillColor: p.fill,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: hwOrange, width: 1.5)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isGeocoding
                                ? null
                                : () async {
                                    if (searchCtrl.text.trim().isEmpty) return;
                                    setModalState(() => isGeocoding = true);
                                    final result = await GoogleMapsService.geocodeAddress(searchCtrl.text.trim());
                                    setModalState(() => isGeocoding = false);
                                    if (result != null) {
                                      final nLat = result['lat'] as double;
                                      final nLng = result['lng'] as double;
                                      setModalState(() {
                                        tempLat = nLat;
                                        tempLng = nLng;
                                        searchCtrl.text = result['formattedAddress'];
                                      });
                                      modalMapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(LatLng(nLat, nLng), 17),
                                      );
                                      if (ctx.mounted) {
                                        showTopNotification(ctx, 'Google Maps house location pinned!', isSuccess: true);
                                      }
                                    } else {
                                      if (ctx.mounted) {
                                        showTopNotification(ctx, 'Location updated to entered address area.', isSuccess: true);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hwOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            child: isGeocoding
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('SEARCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // OPTION 3: PICK FROM SAVED REGISTERED ADDRESSES
                      if (savedAddresses.isNotEmpty) ...[
                        Text('Or Pick from Saved Addresses:', style: ts(p.text, 13, FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text('Select saved address...', style: ts(p.faint, 12)),
                              items: savedAddresses.map((addr) => DropdownMenuItem<String>(
                                value: addr,
                                child: Text(addr, style: ts(p.text, 12), overflow: TextOverflow.ellipsis),
                              )).toList(),
                              onChanged: (selectedAddr) async {
                                if (selectedAddr != null) {
                                  searchCtrl.text = selectedAddr;
                                  setModalState(() => isGeocoding = true);
                                  final res = await GoogleMapsService.geocodeAddress(selectedAddr);
                                  setModalState(() => isGeocoding = false);
                                  if (res != null) {
                                    final nLat = res['lat'] as double;
                                    final nLng = res['lng'] as double;
                                    setModalState(() {
                                      tempLat = nLat;
                                      tempLng = nLng;
                                    });
                                    modalMapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(LatLng(nLat, nLng), 17),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // GOOGLE MAPS LOCATION PIN CONTAINER (Web Protected)
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: p.fill,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: hwOrange, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: kIsWeb
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        color: const Color(0xFF1F2429),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.pin_drop_rounded, size: 42, color: hwOrange),
                                            const SizedBox(height: 6),
                                            Text('Google Maps Pinned House Location', style: ts(p.text, 14, FontWeight.w800)),
                                            if (searchCtrl.text.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                searchCtrl.text,
                                                style: ts(p.sub, 12),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: hwOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                              child: Text('GPS: ${tempLat.toStringAsFixed(4)}° N, ${tempLng.toStringAsFixed(4)}° E', style: ts(hwOrange, 12, FontWeight.w800)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    GoogleMap(
                                      key: ValueKey('gmap_${tempLat}_$tempLng'),
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(tempLat, tempLng),
                                        zoom: 17,
                                      ),
                                      onMapCreated: (ctrl) => modalMapController = ctrl,
                                      mapType: MapType.normal,
                                      myLocationEnabled: true,
                                      myLocationButtonEnabled: true,
                                      zoomControlsEnabled: true,
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('customer_house_pin'),
                                          position: LatLng(tempLat, tempLng),
                                          draggable: true,
                                          infoWindow: const InfoWindow(title: 'Customer House Delivery Pin'),
                                          onDragEnd: (newPos) async {
                                            setModalState(() {
                                              tempLat = newPos.latitude;
                                              tempLng = newPos.longitude;
                                            });
                                            final addr = await GoogleMapsService.reverseGeocode(newPos.latitude, newPos.longitude);
                                            if (addr != null && addr.isNotEmpty) {
                                              setModalState(() {
                                                searchCtrl.text = addr;
                                              });
                                            }
                                          },
                                        ),
                                      },
                                      onTap: (newPos) async {
                                        setModalState(() {
                                          tempLat = newPos.latitude;
                                          tempLng = newPos.longitude;
                                        });
                                        final addr = await GoogleMapsService.reverseGeocode(newPos.latitude, newPos.longitude);
                                        if (addr != null && addr.isNotEmpty) {
                                          setModalState(() {
                                            searchCtrl.text = addr;
                                          });
                                        }
                                      },
                                    ),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Material(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            _showFullScreenMapDialog(context, tempLat, tempLng, (newLat, newLng, newAddr) {
                                              setModalState(() {
                                                tempLat = newLat;
                                                tempLng = newLng;
                                                if (newAddr != null && newAddr.isNotEmpty) {
                                                  searchCtrl.text = newAddr;
                                                }
                                              });
                                              setState(() {
                                                pinnedLat = newLat;
                                                pinnedLng = newLng;
                                                isLocationPinned = true;
                                                if (newAddr != null && newAddr.isNotEmpty) {
                                                  addressController.text = newAddr;
                                                  addressError = false;
                                                }
                                              });
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.fullscreen_rounded, color: hwOrange, size: 18),
                                                SizedBox(width: 4),
                                                Text('Full Screen', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                                        child: Text(
                                          '${tempLat.toStringAsFixed(4)}° N, ${tempLng.toStringAsFixed(4)}° E',
                                          style: ts(Colors.white, 11, FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // OPTION TO SAVE THIS ADDRESS TO PROFILE
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: saveToProfile,
                          onChanged: (val) => setModalState(() => saveToProfile = val == true),
                          activeColor: hwOrange,
                          title: Text('Save this address to my saved shipping addresses', style: ts(p.text, 12, FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final finalAddr = searchCtrl.text.trim();
                            setState(() {
                              pinnedLat = tempLat;
                              pinnedLng = tempLng;
                              isLocationPinned = true;
                              if (finalAddr.isNotEmpty) {
                                addressController.text = finalAddr;
                              }
                            });

                            // If user checked save address
                            if (saveToProfile && user != null && finalAddr.isNotEmpty) {
                              final updatedList = List<String>.from(user.shippingAddresses);
                              if (!updatedList.contains(finalAddr)) {
                                updatedList.add(finalAddr);
                                await firestoreService.updateUserProfile(user.uid, {'shippingAddresses': updatedList});
                                authService.updateLocalUser({'shippingAddresses': updatedList});
                              }
                            }

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              showTopNotification(dialogCtx, 'Delivery location pinned successfully!', isSuccess: true);
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('CONFIRM & SAVE HOUSE LOCATION PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFullScreenMapDialog(
    BuildContext context,
    double initialLat,
    double initialLng,
    Function(double lat, double lng, String? address) onLocationSelected,
  ) {
    GoogleMapController? fullMapController;
    double currentLat = initialLat;
    double currentLng = initialLng;
    String? currentAddress;
    bool isFullGeocoding = false;
    final fullSearchCtrl = TextEditingController(text: addressController.text.trim());

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (fullCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setFullState) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: const Color(0xFF1F2429),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(fullCtx),
                ),
                title: const Text('Full Screen Map Pin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        onLocationSelected(currentLat, currentLng, currentAddress);
                        Navigator.pop(fullCtx);
                        showTopNotification(context, 'Delivery location pinned successfully!', isSuccess: true);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('CONFIRM PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GoogleMap(
                      key: ValueKey('full_gmap_${currentLat}_$currentLng'),
                      initialCameraPosition: CameraPosition(
                        target: LatLng(currentLat, currentLng),
                        zoom: 17,
                      ),
                      onMapCreated: (ctrl) => fullMapController = ctrl,
                      mapType: MapType.normal,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      markers: {
                        Marker(
                          markerId: const MarkerId('fullscreen_house_pin'),
                          position: LatLng(currentLat, currentLng),
                          draggable: true,
                          infoWindow: const InfoWindow(title: 'Customer House Delivery Pin'),
                          onDragEnd: (newPos) async {
                            setFullState(() {
                              currentLat = newPos.latitude;
                              currentLng = newPos.longitude;
                            });
                            final addr = await GoogleMapsService.reverseGeocode(newPos.latitude, newPos.longitude);
                            if (addr != null && addr.isNotEmpty) {
                              setFullState(() {
                                currentAddress = addr;
                                fullSearchCtrl.text = addr;
                              });
                            }
                          },
                        ),
                      },
                      onTap: (newPos) async {
                        setFullState(() {
                          currentLat = newPos.latitude;
                          currentLng = newPos.longitude;
                        });
                        final addr = await GoogleMapsService.reverseGeocode(newPos.latitude, newPos.longitude);
                        if (addr != null && addr.isNotEmpty) {
                          setFullState(() {
                            currentAddress = addr;
                            fullSearchCtrl.text = addr;
                          });
                        }
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Full Screen Address Search Input Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2429),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                            border: Border.all(color: hwOrange, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: hwOrange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: fullSearchCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    hintText: 'Search house no., street, barangay...',
                                    hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (val) async {
                                    if (val.trim().isEmpty) return;
                                    setFullState(() => isFullGeocoding = true);
                                    final res = await GoogleMapsService.geocodeAddress(val.trim());
                                    setFullState(() => isFullGeocoding = false);
                                    if (res != null) {
                                      final nLat = res['lat'] as double;
                                      final nLng = res['lng'] as double;
                                      setFullState(() {
                                        currentLat = nLat;
                                        currentLng = nLng;
                                        currentAddress = res['formattedAddress'];
                                        fullSearchCtrl.text = res['formattedAddress'];
                                      });
                                      fullMapController?.animateCamera(
                                        CameraUpdate.newLatLngZoom(LatLng(nLat, nLng), 17),
                                      );
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: isFullGeocoding
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: hwOrange, strokeWidth: 2))
                                    : const Icon(Icons.arrow_forward_rounded, color: hwOrange),
                                onPressed: isFullGeocoding
                                    ? null
                                    : () async {
                                        if (fullSearchCtrl.text.trim().isEmpty) return;
                                        setFullState(() => isFullGeocoding = true);
                                        final res = await GoogleMapsService.geocodeAddress(fullSearchCtrl.text.trim());
                                        setFullState(() => isFullGeocoding = false);
                                        if (res != null) {
                                          final nLat = res['lat'] as double;
                                          final nLng = res['lng'] as double;
                                          setFullState(() {
                                            currentLat = nLat;
                                            currentLng = nLng;
                                            currentAddress = res['formattedAddress'];
                                            fullSearchCtrl.text = res['formattedAddress'];
                                          });
                                          fullMapController?.animateCamera(
                                            CameraUpdate.newLatLngZoom(LatLng(nLat, nLng), 17),
                                          );
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Coordinates & Address Info Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pin_drop_rounded, color: hwOrange, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentAddress ?? 'Tap or drag pin to exact house roof',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${currentLat.toStringAsFixed(4)}° N, ${currentLng.toStringAsFixed(4)}° E',
                                style: const TextStyle(color: hwOrange, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _speedRow(Pal p) {
    return Row(
      children: [
        Expanded(
          child: SpeedCard(
            icon: Icons.local_shipping_rounded,
            title: 'Standard',
            subtitle: '2-3 days',
            price: 'Free',
            selected: speed == 'Standard',
            onTap: () => setState(() => speed = 'Standard'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpeedCard(
            icon: Icons.bolt_rounded,
            title: 'Express',
            subtitle: 'Same-day',
            price: '+${peso(expressFee)}',
            selected: speed == 'Express',
            onTap: () => setState(() => speed = 'Express'),
          ),
        ),
      ],
    );
  }

  Widget _paymentSection(Pal p, bool verified) {
    Widget tile(String id, String name, String sub, IconData icon,
            {String? badge, bool locked = false}) =>
        PayTile(
          icon: icon,
          title: name,
          subtitle: sub,
          badge: badge,
          locked: locked,
          selected: payment == id && !locked,
          onTap: locked
              ? () => snack('Requires 1 completed online delivery first')
              : () => setState(() => payment = id),
        );

    final tint = verified ? p.ok : p.amber;
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tint.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(verified ? Icons.verified_user_rounded : Icons.shield_outlined,
                  color: tint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verified
                      ? 'Verified customer: Cash on Delivery is unlocked!'
                      : 'First-time protection: your first order must be paid via GCash. Cash on Delivery unlocks after your first completed delivery.',
                  style: ts(p.text, 12, FontWeight.w600).copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
        if (verified) ...[
          tile('COD', 'Cash on Delivery', 'Pay when your order arrives', Icons.payments_rounded),
          tile('GCash', 'GCash / E-Wallet', 'Pay with your e-wallet',
              Icons.account_balance_wallet_rounded),
        ] else ...[
          tile('GCash', 'GCash / E-Wallet', 'Pay with your e-wallet',
              Icons.account_balance_wallet_rounded,
              badge: 'Recommended'),
          tile('COD', 'Cash on Delivery', 'Unlocks after your first delivery', Icons.payments_rounded,
              locked: true),
        ],
      ],
    );
  }

  Widget _gcashReceiptSection(Pal p) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: hwOrange),
              const SizedBox(width: 10),
              Expanded(child: Text('GCash Payment Details', style: ts(p.text, 15, FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hwOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hwOrange.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send GCash payment to:', style: ts(p.faint, 12, FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Account Name: $merchantGcashName', style: ts(p.text, 13, FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Mobile Number: $merchantGcashNumber', style: ts(p.amber, 16, FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // IMPORTANT NOTE TO PAY EXACT AMOUNT
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: ts(p.text, 12, FontWeight.w500).copyWith(height: 1.35),
                      children: [
                        const TextSpan(text: 'Important Note: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                        const TextSpan(text: 'Please make sure to pay the '),
                        TextSpan(
                          text: 'EXACT amount of ${peso(total)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: p.amber),
                        ),
                        const TextSpan(text: ' to avoid order verification delays.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Upload your GCash payment receipt screenshot for verification.', style: ts(p.faint, 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: hwOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: isScanning ? null : _showImageSourceDialog,
              icon: isScanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isScanning ? 'Scanning receipt...' : 'Upload GCash receipt', style: ts(Colors.white, 14, FontWeight.w700)),
            ),
          ),
          if (uploadedReceipt != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.fill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Extracted GCash Details:', style: ts(p.text, 13, FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Uploaded Receipt', style: ts(p.text, 16, FontWeight.w800)),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded),
                                          onPressed: () => Navigator.pop(ctx),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: receiptImageUrl != null && receiptImageUrl!.startsWith('data:image')
                                            ? Image.memory(
                                                base64Decode(receiptImageUrl!.split(',').last),
                                                fit: BoxFit.contain,
                                              )
                                            : (receiptImageUrl != null
                                                ? Image.network(receiptImageUrl!, fit: BoxFit.contain)
                                                : const Center(child: Text('No image available'))),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_rounded, size: 16, color: hwOrange),
                        label: const Text('View Receipt', style: TextStyle(color: hwOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Reference Number: ${gcashRefController.text.isNotEmpty ? gcashRefController.text : (uploadedReceipt?.referenceNumber ?? 'N/A')}', style: ts(p.text, 13, FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Amount Paid: ₱${gcashAmountController.text.isNotEmpty ? gcashAmountController.text : (uploadedReceipt?.amount?.toStringAsFixed(2) ?? '0.00')}', style: ts(p.amber, 14, FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(pendingReviewMessage, style: ts(hwOrange, 11, FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rewards(Pal p) {
    final max = maxRedeem;
    final pts = usedPts;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars_rounded, color: p.amber),
              const SizedBox(width: 10),
              Expanded(child: Text('Loyalty & Rewards', style: ts(p.text, 15, FontWeight.w800))),
              Text('$userPoints pts', style: ts(p.amber, 15, FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text('You will earn +$earn pts with this order', style: ts(p.ok, 12, FontWeight.w700)),
          if (max > 0) ...[
            Divider(color: p.line, height: 24),
            Row(
              children: [
                Expanded(child: Text('Use my points', style: ts(p.text, 14, FontWeight.w700))),
                Switch(
                  value: redeem,
                  activeColor: Colors.white,
                  activeTrackColor: hwOrange,
                  onChanged: (v) => setState(() {
                    redeem = v;
                    if (v && redeemPts == 0) {
                      redeemPts = max;
                      pointsController.text = redeemPts.toString();
                    }
                  }),
                ),
              ],
            ),
            if (redeem) ...[
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: hwOrange,
                  inactiveTrackColor: p.track,
                  thumbColor: hwOrange,
                  overlayColor: hwOrange.withValues(alpha: 0.15),
                  activeTickMarkColor: Colors.transparent,
                  inactiveTickMarkColor: Colors.transparent,
                ),
                child: Slider(
                  value: pts.toDouble(),
                  min: 0,
                  max: max.toDouble(),
                  divisions: max > 0 ? max : 1,
                  onChanged: (v) => setState(() {
                    redeemPts = v.round();
                    pointsController.text = redeemPts.toString();
                  }),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rate: 1 pt = ₱0.20', style: ts(p.faint, 12)),
                  Text('-${peso(discount)}', style: ts(p.ok, 14, FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Points to redeem ($pts pts):', style: ts(p.sub, 12, FontWeight.w700)),
                  SizedBox(
                    width: 75,
                    height: 36,
                    child: TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      style: ts(p.text, 13, FontWeight.w700),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: pts.toString(),
                        filled: true,
                        fillColor: p.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null) {
                          setState(() {
                            redeemPts = math.max(0, math.min(parsed, max));
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _summary(Pal p) {
    final cartProvider = Provider.of<CartProvider>(context);
    final items = _getCheckoutItems(cartProvider);

    Widget row(String l, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l, style: ts(p.faint, 13)),
              Text(v, style: ts(color ?? p.text, 13, FontWeight.w600)),
            ],
          ),
        );

    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: hwOrange.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${it.qty}×', style: ts(hwOrange, 11, FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(it.variant == null ? it.name : '${it.name} (${it.variant})',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(p.text, 14, FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(peso(it.price * it.qty), style: ts(p.text, 14, FontWeight.w700)),
                ],
              ),
            ),
          Divider(color: p.line, height: 16),
          row('Subtotal', peso(subtotal)),
          row('Shipping ($speed)', shipping == 0 ? 'Free' : peso(shipping),
              color: shipping == 0 ? p.ok : null),
          if (discount > 0) row('Loyalty discount', '-${peso(discount)}', color: p.ok),
          Divider(color: p.line, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total to pay', style: ts(p.text, 16, FontWeight.w800)),
              Text(peso(total), style: ts(p.amber, 22, FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(Pal p) {
    final payLabel = {'GCash': 'GCash', 'Card': 'Card', 'COD': 'Cash on Delivery'}[payment] ?? payment;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Glass(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total', style: ts(p.faint, 12)),
                  Text(peso(total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(p.amber, 22, FontWeight.w800)),
                  Text('$payLabel • $speed', style: ts(p.faint, 11)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: placing ? null : place,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hwOrange,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: hwOrange.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: placing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Place order', style: ts(Colors.white, 15, FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpeedCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, price;
  final bool selected;
  final VoidCallback onTap;
  const SpeedCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.price,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? hwOrange.withValues(alpha: 0.12) : p.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? hwOrange : p.line, width: selected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: hwOrange, size: 26),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? hwOrange : p.faint,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: ts(p.text, 15, FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: ts(p.faint, 12)),
            const SizedBox(height: 6),
            Text(price,
                style: ts(price == 'Free' ? p.ok : p.amber, 13, FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class PayTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final bool selected, locked;
  final VoidCallback onTap;
  const PayTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.locked,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? hwOrange.withValues(alpha: 0.12) : p.glassFill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? hwOrange : p.line, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: hwOrange.withValues(alpha: 0.14)),
                child: Icon(icon, color: hwOrange, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(p.text, 14, FontWeight.w800)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: hwOrange, borderRadius: BorderRadius.circular(8)),
                          child: Text(badge!, style: ts(Colors.white, 9, FontWeight.w800)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(subtitle, style: ts(p.faint, 12)),
                  ],
                ),
              ),
              Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : (selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
                color: selected ? hwOrange : p.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
