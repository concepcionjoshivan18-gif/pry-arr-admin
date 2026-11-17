import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/order.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/review.dart';
import '../../core/components/pagination_controls.dart';
import '../../core/components/top_notification.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/item_image_helper.dart';
import '../../core/components/skeleton_loader.dart';
import 'digital_receipt_screen.dart';
import 'delivery_chat_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  int _currentPage = 1;
  static const int _itemsPerPage = 5;
  final Set<String> _reviewedOrderIds = {};
  final Set<String> _selectedOrderIds = {};
  bool _showArchived = false;
  String _statusSort = 'default';

  late final Stream<List<OrderModel>> _ordersStream;
  late final Stream<List<ReviewModel>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _ordersStream = fs.streamMyOrders(uid);
    _reviewsStream = fs.streamAllReviews();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid ?? '';
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                Padding(
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
                      Text('My Orders', style: ts(p.text, 22, FontWeight.w800)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _showArchived = false;
                            _currentPage = 1;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: !_showArchived ? hwOrange : p.fill,
                              borderRadius: BorderRadius.circular(16),
                              border: !_showArchived ? null : Border.all(color: p.line),
                            ),
                            child: Text('Active Orders', style: ts(!_showArchived ? Colors.white : p.text, 13, FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _showArchived = true;
                            _currentPage = 1;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _showArchived ? hwOrange : p.fill,
                              borderRadius: BorderRadius.circular(16),
                              border: _showArchived ? null : Border.all(color: p.line),
                            ),
                            child: Text('Archived', style: ts(_showArchived ? Colors.white : p.text, 13, FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Glass(
                        radius: 16,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.sort_rounded, color: hwOrange, size: 20),
                          tooltip: 'Sort by Status',
                          onSelected: (val) => setState(() {
                            _statusSort = val;
                            _currentPage = 1;
                          }),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'default', child: Text('All (Newest)')),
                            const PopupMenuItem(value: 'pending', child: Text('Pending')),
                            const PopupMenuItem(value: 'completed', child: Text('Completed')),
                            const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                            const PopupMenuItem(value: 'processing', child: Text('Processing')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ReviewModel>>(
                    stream: _reviewsStream,
                    builder: (context, reviewSnapshot) {
                      if (reviewSnapshot.hasData) {
                        for (var rev in reviewSnapshot.data!) {
                          final String idStr = rev.orderId ?? '';
                          if (rev.userId == userId && idStr.isNotEmpty) {
                            _reviewedOrderIds.add(idStr);
                          }
                        }
                      }

                      return StreamBuilder<List<OrderModel>>(
                        stream: _ordersStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}', style: ts(p.danger, 14)),
                            );
                          }
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: 4,
                              itemBuilder: (context, index) => const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: SkeletonCard(),
                              ),
                            );
                          }
                          final user = authService.currentUser;
                          final firebaseUser = FirebaseAuth.instance.currentUser;
                          final currentUid = user?.uid ?? firebaseUser?.uid ?? userId;
                          final currentEmail = user?.email ?? firebaseUser?.email ?? '';
                          final archivedIds = user?.archivedOrders ?? [];

                          final allUserOrders = snapshot.data?.where((o) {
                            if (currentUid.isNotEmpty && o.customerId.trim() == currentUid.trim()) return true;
                            if (currentEmail.isNotEmpty && o.customerId.trim().toLowerCase() == currentEmail.trim().toLowerCase()) return true;
                            if (firebaseUser?.uid != null && o.customerId.trim() == firebaseUser!.uid.trim()) return true;
                            return false;
                          }).toList() ?? [];

                          allUserOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                          final orders = allUserOrders.where((o) => _showArchived ? archivedIds.contains(o.id) : !archivedIds.contains(o.id)).toList();

                          if (_statusSort != 'default') {
                            orders.sort((a, b) {
                              if (a.status.toLowerCase() == _statusSort && b.status.toLowerCase() != _statusSort) return -1;
                              if (b.status.toLowerCase() == _statusSort && a.status.toLowerCase() != _statusSort) return 1;
                              return b.createdAt.compareTo(a.createdAt);
                            });
                          }

                          if (orders.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: p.faint),
                                  const SizedBox(height: 12),
                                  Text(_showArchived ? 'No archived orders.' : 'You have no orders yet.', style: ts(p.faint, 16)),
                                ],
                              ),
                            );
                          }

                          final totalPages = (orders.length / _itemsPerPage).ceil();
                          final int validPage = _currentPage.clamp(1, math.max(1, totalPages)).toInt();
                          final int startIndex = (validPage - 1) * _itemsPerPage;
                          final pagedOrders = orders.skip(startIndex).take(_itemsPerPage).toList();

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _selectedOrderIds.length == orders.length && orders.isNotEmpty,
                                      activeColor: hwOrange,
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedOrderIds.addAll(orders.map((o) => o.id));
                                          } else {
                                            _selectedOrderIds.clear();
                                          }
                                        });
                                      },
                                    ),
                                    Flexible(
                                      child: Text(
                                        'All (${_selectedOrderIds.length})',
                                        style: ts(p.sub, 12, FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_selectedOrderIds.isNotEmpty)
                                      ElevatedButton.icon(
                                        onPressed: () => _confirmBatchAction(context, firestoreService, authService, orders),
                                        icon: Icon(_showArchived ? Icons.delete_forever_rounded : Icons.archive_rounded, size: 14, color: Colors.white),
                                        label: Text(_showArchived ? 'Delete' : 'Archive', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: p.danger,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 36),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(20),
                                  itemCount: pagedOrders.length,
                                  itemBuilder: (context, index) {
                                    final o = pagedOrders[index];
                                    final isReviewed = _reviewedOrderIds.contains(o.id);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Glass(
                                        radius: 22,
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Checkbox(
                                                  value: _selectedOrderIds.contains(o.id),
                                                  activeColor: hwOrange,
                                                  onChanged: (v) {
                                                    setState(() {
                                                      if (v == true) {
                                                        _selectedOrderIds.add(o.id);
                                                      } else {
                                                        _selectedOrderIds.remove(o.id);
                                                      }
                                                    });
                                                  },
                                                ),
                                                Text('Select Order', style: ts(p.faint, 11)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Order #${o.id.substring(0, 5)}', style: ts(p.text, 16, FontWeight.w800)),
                                                _statusChip(o.status),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(DateFormat('MMM dd, yyyy HH:mm').format(o.createdAt), style: ts(p.faint, 12)),
                                            Divider(height: 20, color: p.line),
                                            Text('${o.items.length} ${o.items.length == 1 ? 'item' : 'items'}', style: ts(p.sub, 13, FontWeight.w700)),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Total Amount:', style: ts(p.text, 13)),
                                                Text('₱${o.total.toStringAsFixed(2)}', style: ts(p.amber, 16, FontWeight.w800)),
                                              ],
                                            ),
                                            if (o.status == 'pending' && o.pointsEarned > 0) ...[
                                              const SizedBox(height: 4),
                                              Text('Points pending: +${o.pointsEarned}', style: ts(Colors.blue, 12, FontWeight.w600)),
                                            ],
                                            if (o.status == 'completed' && o.pointsEarned > 0) ...[
                                              const SizedBox(height: 4),
                                              Text('Points earned: +${o.pointsEarned}', style: ts(p.ok, 12, FontWeight.w600)),
                                            ],
                                            if (o.pointsRedeemed > 0) ...[
                                              const SizedBox(height: 4),
                                              Text('Points redeemed: -${o.pointsRedeemed}', style: ts(p.danger, 12, FontWeight.w600)),
                                            ],

                                            const SizedBox(height: 12),
                                            // ORDER DETAILS BUTTON
                                            OutlinedButton.icon(
                                              onPressed: () => _showOrderDetailsSheet(context, o, p),
                                              icon: const Icon(Icons.info_outline_rounded, size: 16),
                                              label: const Text('ORDER DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: hwOrange,
                                                side: const BorderSide(color: hwOrange),
                                                minimumSize: const Size(double.infinity, 42),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),

                                            if (o.status == 'processing' || o.status == 'out_for_delivery' || o.status == 'in_transit') ...[
                                              const SizedBox(height: 8),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DeliveryChatScreen(order: o),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                                                label: const Text('CONTACT RIDER / DRIVER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue[800],
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(double.infinity, 42),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                            ],

                                            if (o.status == 'pending') ...[
                                              const SizedBox(height: 8),
                                              OutlinedButton(
                                                onPressed: () => _confirmCancel(context, firestoreService, o.id),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: p.danger,
                                                  side: BorderSide(color: p.danger),
                                                  minimumSize: const Size(double.infinity, 42),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                child: const Text('CANCEL ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              ),
                                            ],

                                            if (o.status == 'completed') ...[
                                              const SizedBox(height: 8),
                                              if (isReviewed)
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                                  decoration: BoxDecoration(
                                                    color: p.ok.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: p.ok.withValues(alpha: 0.4)),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.check_circle_rounded, color: p.ok, size: 18),
                                                      const SizedBox(width: 8),
                                                      Text('Feedback Submitted', style: ts(p.ok, 12, FontWeight.w700)),
                                                    ],
                                                  ),
                                                )
                                              else
                                                ElevatedButton.icon(
                                                  onPressed: () => _showOrderRatingDialog(context, o, firestoreService, authService),
                                                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                                                  label: const Text('RATE & LEAVE FEEDBACK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: hwYellow,
                                                    foregroundColor: hwCharcoal,
                                                    minimumSize: const Size(double.infinity, 42),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                            ],
                                            const SizedBox(height: 8),
                                            OutlinedButton.icon(
                                              onPressed: () => _confirmArchiveOrDelete(context, firestoreService, authService, o.id, _showArchived),
                                              icon: Icon(_showArchived ? Icons.delete_forever_rounded : Icons.archive_rounded, size: 16),
                                              label: Text(_showArchived ? 'DELETE PERMANENTLY' : 'ARCHIVE ORDER', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: p.faint,
                                                side: BorderSide(color: p.line),
                                                minimumSize: const Size(double.infinity, 40),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
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
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsSheet(BuildContext context, OrderModel order, Pal p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: p.faint.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${order.id.substring(0, 5)}', style: ts(p.text, 20, FontWeight.w800)),
                _statusChip(order.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Placed on ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}', style: ts(p.faint, 12)),
            const SizedBox(height: 16),
            Divider(color: p.line, height: 1),
            const SizedBox(height: 14),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fulfillment & Delivery', style: ts(p.text, 14, FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
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
                              const Icon(Icons.location_on_rounded, color: hwOrange, size: 20),
                              const SizedBox(width: 8),
                              Text('Delivery Address', style: ts(hwOrange, 13, FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.deliveryAddress ?? order.fulfillmentType,
                            style: ts(p.text, 13, FontWeight.w600),
                          ),
                          if (order.deliveryLat != null && order.deliveryLng != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.pin_drop_rounded, color: hwOrange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'GPS Pin: ${order.deliveryLat!.toStringAsFixed(4)}° N, ${order.deliveryLng!.toStringAsFixed(4)}° E',
                                  style: ts(p.faint, 11, FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text('Payment Method', style: ts(p.text, 14, FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
                      child: Row(
                        children: [
                          const Icon(Icons.payment_rounded, color: hwOrange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(order.paymentMethod, style: ts(p.text, 13, FontWeight.w600))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Order Items (${order.items.length})', style: ts(p.text, 14, FontWeight.w800)),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: buildItemImage(item.imageUrl, itemName: item.name),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: ts(p.text, 13, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (item.variant != null) Text('Variant: ${item.variant}', style: ts(p.faint, 11)),
                                      Text('${item.qty} x ₱${item.price.toStringAsFixed(2)}', style: ts(p.faint, 12)),
                                    ],
                                  ),
                                ),
                                Text('₱${(item.price * item.qty).toStringAsFixed(2)}', style: ts(p.amber, 14, FontWeight.w800)),
                              ],
                            ),
                          ),
                        )),

                    const SizedBox(height: 14),
                    Divider(color: p.line, height: 1),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: ts(p.faint, 13)),
                        Text('₱${order.subtotal.toStringAsFixed(2)}', style: ts(p.text, 13, FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Grand Total', style: ts(p.text, 16, FontWeight.w800)),
                        Text('₱${order.total.toStringAsFixed(2)}', style: ts(p.amber, 20, FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DigitalReceiptScreen(
                        items: order.items,
                        total: order.total,
                        pointsEarned: order.pointsEarned,
                        discount: (order.pointsRedeemed * 0.2),
                        paymentMethod: order.paymentMethod,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('VIEW DIGITAL RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
            if (order.status == 'pending') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmCancel(context, Provider.of<FirestoreService>(context, listen: false), order.id);
                  },
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('CANCEL ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.danger,
                    side: BorderSide(color: p.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOrderRatingDialog(BuildContext context, OrderModel order, FirestoreService fs, AuthService auth) {
    if (order.items.isEmpty) return;
    CartItem selectedItem = order.items.first;
    double rating = 5.0;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Leave Product Feedback',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #${order.id.substring(0, 5)} - Select Item:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<CartItem>(
                        initialValue: selectedItem,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: order.items.map((it) {
                          return DropdownMenuItem<CartItem>(
                            value: it,
                            child: Text(it.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedItem = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Select Your Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Center(
                        child: FittedBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starVal = index + 1.0;
                              return IconButton(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 28,
                                ),
                                onPressed: () {
                                  setDialogState(() => rating = starVal);
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Your Feedback / Review:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: commentCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Describe product quality, delivery, or experience...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final comment = commentCtrl.text.trim();
                    if (comment.isEmpty) {
                      showTopNotification(context, 'Please enter a feedback comment.', isError: true);
                      return;
                    }

                    final user = auth.currentUser;
                    final review = ReviewModel(
                      id: '',
                      productId: selectedItem.productId,
                      productName: selectedItem.name,
                      orderId: order.id,
                      userId: user?.uid ?? '',
                      userName: user?.fullName.isNotEmpty == true ? user!.fullName : 'Verified Customer',
                      userPhoto: user?.profilePhoto,
                      rating: rating,
                      comment: comment,
                      createdAt: DateTime.now(),
                    );

                    await fs.addReview(review);
                    if (mounted) {
                      setState(() {
                        _reviewedOrderIds.add(order.id);
                      });
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      showTopNotification(
                        context,
                        'Feedback submitted successfully! Thank you.',
                        isSuccess: true,
                        icon: Icons.star_rounded,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                  child: const Text('SUBMIT FEEDBACK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmBatchAction(BuildContext context, FirestoreService fs, AuthService auth, List<OrderModel> orders) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_showArchived ? 'Delete Selected Permanently?' : 'Archive Selected Orders?'),
        content: Text('Are you sure you want to ${_showArchived ? 'delete' : 'archive'} ${_selectedOrderIds.length} orders?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hwRust, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final user = auth.currentUser;
              if (user != null) {
                final list = List<String>.from(user.archivedOrders);
                for (var id in _selectedOrderIds) {
                  if (_showArchived) {
                    list.remove(id);
                    await fs.deleteOrder(id);
                  } else {
                    if (!list.contains(id)) list.add(id);
                  }
                }
                await fs.updateUserProfile(user.uid, {'archivedOrders': list});
                setState(() {
                  _selectedOrderIds.clear();
                });
                if (context.mounted) {
                  showTopNotification(context, _showArchived ? 'Selected orders deleted.' : 'Selected orders archived.', isSuccess: true);
                }
              }
            },
            child: Text(_showArchived ? 'Delete' : 'Archive'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, FirestoreService fs, String orderId) {
    bool isCancelling = false;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final p = Pal.of(context);
            return AlertDialog(
              backgroundColor: p.surface,
              title: Text('Cancel Order?', style: TextStyle(color: p.text, fontWeight: FontWeight.bold)),
              content: Text(
                'Are you sure you want to cancel this order? This action cannot be undone.',
                style: TextStyle(color: p.sub),
              ),
              actions: [
                TextButton(
                  onPressed: isCancelling ? null : () => Navigator.pop(ctx),
                  child: Text('KEEP ORDER', style: TextStyle(color: p.faint)),
                ),
                ElevatedButton(
                  onPressed: isCancelling
                      ? null
                      : () async {
                          setDialogState(() => isCancelling = true);
                          try {
                            await fs.cancelOrder(orderId);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              showTopNotification(context, 'Order cancelled successfully.', isSuccess: true);
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() => isCancelling = false);
                            }
                            if (context.mounted) {
                              showTopNotification(
                                context,
                                'Failed to cancel order: ${e.toString().replaceAll('Exception: ', '')}',
                                isError: true,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('CANCEL ORDER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmArchiveOrDelete(BuildContext context, FirestoreService fs, AuthService auth, String orderId, bool isAlreadyArchived) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAlreadyArchived ? 'Delete Order Permanently?' : 'Archive Order?'),
        content: Text(isAlreadyArchived ? 'This will permanently remove this order from your archive.' : 'Are you sure you want to archive this order? You can view it later in the Archived tab.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hwRust, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final user = auth.currentUser;
              if (user != null) {
                final list = List<String>.from(user.archivedOrders);
                if (isAlreadyArchived) {
                  list.remove(orderId);
                  await fs.deleteOrder(orderId);
                } else {
                  if (!list.contains(orderId)) list.add(orderId);
                }
                await fs.updateUserProfile(user.uid, {'archivedOrders': list});
                if (context.mounted) {
                  showTopNotification(context, isAlreadyArchived ? 'Order deleted permanently.' : 'Order archived successfully.', isSuccess: true);
                }
              }
            },
            child: Text(isAlreadyArchived ? 'Delete' : 'Archive'),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.grey;
    if (status == 'pending') color = Colors.orange;
    if (status == 'processing') color = Colors.blue;
    if (status == 'completed') color = Colors.green;
    if (status == 'cancelled') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}
