import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/order.dart';
import '../../core/components/top_notification.dart';
import '../../core/theme/hardware_theme.dart';
import '../../admin/screens/pending_payment_detail_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.order.id.substring(0, 5)}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hwOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hwOrange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: hwOrange, size: 22),
                      const SizedBox(width: 8),
                      const Text('Delivery Destination & Address', style: TextStyle(color: hwOrange, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.order.deliveryAddress ?? widget.order.fulfillmentType,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (widget.order.deliveryLat != null && widget.order.deliveryLng != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop_rounded, color: hwOrange, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'GPS Coordinates: ${widget.order.deliveryLat!.toStringAsFixed(4)}° N, ${widget.order.deliveryLng!.toStringAsFixed(4)}° E',
                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...widget.order.items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Qty: ${item.qty}'),
                trailing: Text('₱${(item.price * item.qty).toStringAsFixed(2)}'),
              ),
            )),
            const Divider(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('₱${widget.order.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            if (widget.order.pointsRedeemed > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points Redeemed:', style: TextStyle(fontSize: 14, color: Colors.red)),
                  Text('-${widget.order.pointsRedeemed} pts', style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            if (widget.order.pointsEarned > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points to Earn:', style: TextStyle(fontSize: 14, color: Colors.blue)),
                  Text('+${widget.order.pointsEarned} pts', style: const TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const SizedBox(height: 32),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (widget.order.paymentMethod == 'GCash' || widget.order.receiptImageUrl != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PendingPaymentDetailScreen(order: widget.order),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                  label: const Text('CHECK PAYMENT', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    backgroundColor: hwOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.order.status == 'pending')
                ElevatedButton(
                  onPressed: () => _updateStatus(firestoreService, 'processing'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text('ACCEPT ORDER'),
                ),
              if (widget.order.status == 'processing')
                ElevatedButton(
                  onPressed: () => _updateStatus(firestoreService, 'out_for_delivery'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54), backgroundColor: Colors.purple, foregroundColor: Colors.white),
                  child: const Text('FORWARD TO DELIVERY'),
                ),
              if (widget.order.status != 'completed' && widget.order.status != 'cancelled') ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _cancelOrder(firestoreService),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 54), foregroundColor: Colors.red),
                  child: const Text('CANCEL ORDER'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _updateStatus(FirestoreService service, String status) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      await service.updateOrderStatus(widget.order.id, status);
      if (mounted) {
        showTopNotification(context, 'Order status updated to ${status.replaceAll("_", " ").toUpperCase()}', isSuccess: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Error: $e', isError: true);
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _cancelOrder(FirestoreService service) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      await service.cancelOrder(widget.order.id);
      if (mounted) {
        showTopNotification(context, 'Order cancelled and points returned to customer.', isSuccess: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Error: $e', isError: true);
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
