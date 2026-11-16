import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/order.dart';
import '../../core/components/pagination_controls.dart';
import '../../core/theme/hardware_theme.dart';
import 'pending_payment_detail_screen.dart';

Widget _hwGlass({
  required Widget child,
  double radius = 24,
  EdgeInsetsGeometry? padding,
}) {
  return Builder(
    builder: (context) {
      final p = Pal.of(context);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.glassFill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: p.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

Widget _hwBackground() => const SizedBox.shrink();

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return hwYellow;
    case 'processing':
      return const Color(0xFF4FA3FF);
    case 'completed':
      return const Color(0xFF3DDC97);
    case 'cancelled':
      return hwRust;
    default:
      return Colors.white54;
  }
}

class OrderManagerScreen extends StatefulWidget {
  const OrderManagerScreen({super.key});

  @override
  State<OrderManagerScreen> createState() => _OrderManagerScreenState();
}

class _OrderManagerScreenState extends State<OrderManagerScreen> {
  int _currentPage = 1;
  static const int _itemsPerPage = 5;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_shipping_rounded, color: hwOrange, size: 20),
            const SizedBox(width: 10),
            Text('Order Fulfillment Manager', style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_rounded, color: hwOrange),
            onPressed: () => context.go('/admin/pending-payments'),
            tooltip: 'Pending GCash Payments',
          ),
        ],
      ),
      body: Stack(
        children: [
          _hwBackground(),
          StreamBuilder<List<OrderModel>>(
            stream: firestoreService.streamAllOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: hwOrange));
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return Center(
                  child: Text('No orders have been submitted yet.', style: TextStyle(color: p.faint)),
                );
              }

              final totalPages = (orders.length / _itemsPerPage).ceil();
              if (_currentPage > totalPages) {
                _currentPage = totalPages > 0 ? totalPages : 1;
              }

              final startIndex = (_currentPage - 1) * _itemsPerPage;
              final pagedOrders = orders.skip(startIndex).take(_itemsPerPage).toList();

              return Column(
                children: [
                  const SizedBox(height: 76),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      itemCount: pagedOrders.length,
                      itemBuilder: (context, index) {
                        final order = pagedOrders[index];
                        final statusColor = _statusColor(order.status);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _hwGlass(
                            radius: 24,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: hwOrange.withValues(alpha: 0.18),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.receipt_long_rounded, color: hwOrange, size: 18),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Order ID: ${order.id}',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: p.text),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: order.status,
                                          dropdownColor: p.surface,
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                          items: const [
                                            DropdownMenuItem(value: 'pending', child: Text('PENDING', style: TextStyle(color: hwYellow, fontWeight: FontWeight.bold))),
                                            DropdownMenuItem(value: 'processing', child: Text('PROCESSING', style: TextStyle(color: Color(0xFF4FA3FF), fontWeight: FontWeight.bold))),
                                            DropdownMenuItem(value: 'completed', child: Text('COMPLETED', style: TextStyle(color: Color(0xFF3DDC97), fontWeight: FontWeight.bold))),
                                            DropdownMenuItem(value: 'cancelled', child: Text('CANCELLED', style: TextStyle(color: hwRust, fontWeight: FontWeight.bold))),
                                          ],
                                          onChanged: (newVal) async {
                                            if (newVal != null) {
                                              try {
                                                await firestoreService.updateOrderStatus(order.id, newVal);
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Customer UID: ${order.customerId}', style: TextStyle(fontSize: 12, color: p.faint)),
                                Text(
                                  'Placed Date: ${order.createdAt.toLocal().toString().split('.')[0]}',
                                  style: TextStyle(fontSize: 12, color: p.faint),
                                ),
                                Divider(height: 28, color: p.line),
                                ...order.items.map((it) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${it.name} x${it.qty}', style: TextStyle(fontSize: 13, color: p.sub)),
                                      Text('₱${(it.price * it.qty).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: p.sub)),
                                    ],
                                  ),
                                )),
                                Divider(height: 28, color: p.line),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Collection:', style: TextStyle(fontWeight: FontWeight.bold, color: p.text)),
                                    Text(
                                      '₱${order.total.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: p.amber, fontSize: 15),
                                    ),
                                  ],
                                ),
                                if (order.paymentMethod == 'GCash' || order.receiptImageUrl != null) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PendingPaymentDetailScreen(order: order),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white),
                                    label: const Text('CHECK PAYMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hwOrange,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 42),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Pagination
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        iconTheme: IconThemeData(color: p.faint),
                        textTheme: Theme.of(context).textTheme.apply(bodyColor: p.faint),
                      ),
                      child: PaginationControls(
                        currentPage: _currentPage,
                        totalPages: totalPages,
                        onPageChanged: (newPage) {
                          setState(() {
                            _currentPage = newPage;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
