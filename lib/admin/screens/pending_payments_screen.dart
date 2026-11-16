import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../core/services/firestore_service.dart';
import '../../core/models/order.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/config/payment_policy.dart';
import '../../core/components/skeleton_loader.dart';
import 'pending_payment_detail_screen.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<OrderModel>>(
        stream: firestoreService.streamAllOrders(),
        builder: (context, snapshot) {
          if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 4,
              itemBuilder: (_, __) => const SkeletonCard(),
            );
          }

          final allOrders = snapshot.data ?? [];
          final pendingOrders = allOrders
              .where((o) => o.paymentStatus == 'pending_review')
              .toList();

          // Sort newest first
          pendingOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(36, 32, 36, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.payments_rounded, color: hwOrange, size: 26),
                          const SizedBox(width: 10),
                          Text('Pending Payments Review', style: ts(p.text, 26, FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Admin / Pending GCash Receipts & Manual Review', style: ts(p.faint, 12)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: hwYellow.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: hwYellow.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: hwYellow, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'High-Value Hold Threshold: ₱${highValueHoldThreshold.toStringAsFixed(2)}. Orders at or above this amount require manual confirmation before fulfillment.',
                                style: ts(p.text, 12, FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (pendingOrders.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 64, color: p.faint),
                        const SizedBox(height: 12),
                        Text('No pending payments to review.', style: ts(p.faint, 16)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = pendingOrders[index];
                        final bool isHighValue = order.total >= highValueHoldThreshold;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: p.line),
                            boxShadow: [
                              BoxShadow(color: p.shadow, blurRadius: 16, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Receipt Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 60,
                                  height: 80,
                                  color: p.fill,
                                  child: order.receiptImageUrl != null && order.receiptImageUrl!.isNotEmpty
                                      ? Image.network(
                                          order.receiptImageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.receipt_rounded, color: hwOrange),
                                        )
                                      : const Icon(Icons.receipt_rounded, color: hwOrange),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Order #${order.id.substring(0, math.min(6, order.id.length))}', style: ts(p.text, 15, FontWeight.w800)),
                                        if (isHighValue)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: hwYellow.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: hwYellow),
                                            ),
                                            child: Text('Hold: High Value', style: ts(hwYellow, 10, FontWeight.w800)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Customer: ${order.customerName}', style: ts(p.sub, 13, FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('Ref: ${order.gcashReferenceNumber ?? 'N/A'} • GCash Amt: ₱${order.gcashAmount?.toStringAsFixed(2) ?? 'N/A'}', style: ts(p.faint, 12)),
                                    const SizedBox(height: 4),
                                    Text('Reason: ${order.reviewReason ?? 'pending_review'}', style: ts(hwOrange, 12, FontWeight.w700)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₱${order.total.toStringAsFixed(2)}', style: ts(p.amber, 18, FontWeight.w900)),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PendingPaymentDetailScreen(order: order),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hwOrange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: pendingOrders.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
