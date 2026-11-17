import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../core/services/firestore_service.dart';
import '../../core/models/order.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/components/responsive_page_header.dart';
import '../../core/components/skeleton_loader.dart';
import '../../core/components/top_notification.dart';
import 'pending_payment_detail_screen.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  bool _isLoading = true;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  void _toggleSelectAll(List<OrderModel> pendingOrders) {
    setState(() {
      if (_selectedOrderIds.length == pendingOrders.length) {
        _selectedOrderIds.clear();
      } else {
        _selectedOrderIds.clear();
        for (var o in pendingOrders) {
          _selectedOrderIds.add(o.id);
        }
      }
    });
  }

  void _toggleSelectOrder(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  void _confirmDeleteOrder(BuildContext context, FirestoreService fs, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order Record'),
        content: Text('Are you sure you want to delete Order #${order.id.substring(0, math.min(6, order.id.length))}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await fs.deleteOrder(order.id);
                if (mounted) {
                  showTopSuccess(context, 'Order record deleted.');
                }
              } catch (e) {
                if (mounted) {
                  showTopError(context, 'Error deleting order: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmBatchDelete(BuildContext context, FirestoreService fs) {
    if (_selectedOrderIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedOrderIds.length} Order Records'),
        content: Text('Are you sure you want to delete ${_selectedOrderIds.length} selected orders? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                for (var id in _selectedOrderIds) {
                  await fs.deleteOrder(id);
                }
                setState(() {
                  _selectedOrderIds.clear();
                });
                if (mounted) {
                  showTopSuccess(context, 'Selected order records deleted.');
                }
              } catch (e) {
                if (mounted) {
                  showTopError(context, 'Error deleting orders: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _confirmBatchApprove(BuildContext context, FirestoreService fs) {
    if (_selectedOrderIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve ${_selectedOrderIds.length} Payments'),
        content: Text('Are you sure you want to approve and mark ${_selectedOrderIds.length} selected payments as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                for (var id in _selectedOrderIds) {
                  await fs.updateOrderPaymentStatus(id, 'paid');
                }
                setState(() {
                  _selectedOrderIds.clear();
                });
                if (mounted) {
                  showTopSuccess(context, 'Selected payments approved successfully.');
                }
              } catch (e) {
                if (mounted) {
                  showTopError(context, 'Error approving payments: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hwOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
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
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsivePageHeader(
                        icon: Icons.payments_rounded,
                        title: 'Pending Payments Review',
                        breadcrumb: 'Admin / Pending GCash Receipts & Manual Review',
                      ),
                      if (pendingOrders.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _selectedOrderIds.length == pendingOrders.length && pendingOrders.isNotEmpty,
                              activeColor: hwOrange,
                              onChanged: (_) => _toggleSelectAll(pendingOrders),
                            ),
                            Text('Select All (${pendingOrders.length})', style: ts(p.text, 13, FontWeight.w700)),
                            const Spacer(),
                            if (_selectedOrderIds.isNotEmpty) ...[
                              ElevatedButton.icon(
                                onPressed: () => _confirmBatchApprove(context, firestoreService),
                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                label: Text('Approve (${_selectedOrderIds.length})'),
                                style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _confirmBatchDelete(context, firestoreService),
                                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                                label: Text('Delete (${_selectedOrderIds.length})'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                              ),
                            ],
                          ],
                        ),
                      ],
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
                        final isMobile = Breakpoints.isMobile(context);
                        final isSelected = _selectedOrderIds.contains(order.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(isMobile ? 14 : 20),
                          decoration: BoxDecoration(
                            color: isSelected ? hwOrange.withValues(alpha: 0.08) : p.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? hwOrange : p.line, width: isSelected ? 1.5 : 1),
                            boxShadow: [
                              BoxShadow(color: p.shadow, blurRadius: 16, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: hwOrange,
                                    onChanged: (_) => _toggleSelectOrder(order.id),
                                  ),
                                  const SizedBox(width: 4),
                                  // Receipt Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: isMobile ? 50 : 60,
                                      height: isMobile ? 70 : 80,
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
                                        Text('Order #${order.id.substring(0, math.min(6, order.id.length))}', style: ts(p.text, isMobile ? 14 : 15, FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text('Customer: ${order.customerName}', style: ts(p.sub, isMobile ? 12 : 13, FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text('Ref: ${order.gcashReferenceNumber ?? 'N/A'} • GCash Amt: ₱${order.gcashAmount?.toStringAsFixed(2) ?? 'N/A'}', style: ts(p.faint, 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text('Reason: ${order.reviewReason ?? 'pending_review'}', style: ts(hwOrange, 11, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  if (!isMobile) ...[
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₱${order.total.toStringAsFixed(2)}', style: ts(p.amber, 18, FontWeight.w900)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: hwRust, size: 20),
                                              tooltip: 'Delete Order',
                                              onPressed: () => _confirmDeleteOrder(context, firestoreService, order),
                                            ),
                                            const SizedBox(width: 4),
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
                                  ],
                                ],
                              ),
                              if (isMobile) ...[
                                const SizedBox(height: 12),
                                Divider(color: p.line, height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total: ₱${order.total.toStringAsFixed(2)}', style: ts(p.amber, 15, FontWeight.w900)),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: hwRust, size: 20),
                                          tooltip: 'Delete Order',
                                          onPressed: () => _confirmDeleteOrder(context, firestoreService, order),
                                        ),
                                        const SizedBox(width: 4),
                                        SizedBox(
                                          height: 36,
                                          child: ElevatedButton(
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
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                            ),
                                            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
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
