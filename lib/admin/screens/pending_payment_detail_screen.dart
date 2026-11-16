import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/order.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';

class PendingPaymentDetailScreen extends StatefulWidget {
  final OrderModel order;
  const PendingPaymentDetailScreen({super.key, required this.order});

  @override
  State<PendingPaymentDetailScreen> createState() => _PendingPaymentDetailScreenState();
}

class _PendingPaymentDetailScreenState extends State<PendingPaymentDetailScreen> {
  final _reviewNoteController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _reviewNoteController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    showTopNotification(context, msg, isError: error, isSuccess: !error);
  }

  Future<void> _confirmPayment(FirestoreService firestoreService) async {
    final refNo = widget.order.gcashReferenceNumber;
    if (refNo != null && refNo.isNotEmpty) {
      final alreadyUsed = await firestoreService.checkGcashReferenceExists(refNo);
      if (alreadyUsed) {
        _snack('Cannot confirm: This GCash reference number is already used by another order.', error: true);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      await firestoreService.updateOrderPaymentStatus(widget.order.id, 'paid');
      _snack('Payment confirmed successfully!', error: false);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error confirming payment: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rejectPayment(FirestoreService firestoreService) async {
    final note = _reviewNoteController.text.trim();
    if (note.isEmpty) {
      _snack('Please provide a review note / rejection reason', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await firestoreService.updateOrderPaymentStatus(
        widget.order.id,
        'rejected',
        reviewNote: note,
        reviewReason: widget.order.reviewReason ?? 'manual_rejection',
      );
      _snack('Payment rejected.', error: false);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Error rejecting payment: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final p = Pal.of(context);
    final o = widget.order;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Review Payment #${o.id.substring(0, math.min(6, o.id.length))}', style: ts(p.text, 18, FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order Total', style: ts(p.faint, 14)),
                          Text('₱${o.total.toStringAsFixed(2)}', style: ts(p.amber, 20, FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('GCash Amount: ₱${o.gcashAmount?.toStringAsFixed(2) ?? 'N/A'}', style: ts(p.text, 14, FontWeight.w600)),
                      Text('Reference Number: ${o.gcashReferenceNumber ?? 'N/A'}', style: ts(p.text, 14, FontWeight.w600)),
                      Text('Review Reason: ${o.reviewReason ?? 'None'}', style: ts(hwOrange, 14, FontWeight.w700)),
                      Text('Placed At: ${DateFormat('MMM dd, yyyy HH:mm').format(o.createdAt)}', style: ts(p.faint, 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Receipt Image', style: ts(p.text, 16, FontWeight.w800)),
                const SizedBox(height: 10),
                Container(
                  height: 450,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: o.receiptImageUrl != null && o.receiptImageUrl!.isNotEmpty
                        ? InteractiveViewer(
                            panEnabled: true,
                            scaleEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              o.receiptImageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.grey))),
                            ),
                          )
                        : const Center(child: Text('No receipt image available', style: TextStyle(color: Colors.grey))),
                  ),
                ),
                const SizedBox(height: 20),
                Text('OCR Raw Text', style: ts(p.text, 16, FontWeight.w800)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line),
                  ),
                  child: Text(
                    'GCash Receipt\nRef No: ${o.gcashReferenceNumber ?? 'N/A'}\nAmount: ₱${o.gcashAmount?.toStringAsFixed(2) ?? 'N/A'}\nStatus: ${o.paymentStatus}',
                    style: ts(p.text, 13),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Review Note / Rejection Reason', style: ts(p.text, 16, FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  controller: _reviewNoteController,
                  maxLines: 3,
                  style: ts(p.text, 14),
                  decoration: InputDecoration(
                    hintText: 'Enter note for confirmation or rejection reason...',
                    hintStyle: ts(p.faint, 14),
                    filled: true,
                    fillColor: p.fill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : () => _confirmPayment(firestoreService),
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                        label: const Text('Confirm payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : () => _rejectPayment(firestoreService),
                        icon: const Icon(Icons.cancel_rounded, color: Colors.white),
                        label: const Text('Reject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.danger,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// Helper for math import
class math {
  static int min(int a, int b) => a < b ? a : b;
}
