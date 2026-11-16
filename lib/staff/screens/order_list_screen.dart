import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/order.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/skeleton_loader.dart';
import '../../admin/screens/admin_chat_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  String _statusSort = 'default';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Incoming Orders', style: ts(p.text, 20, FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: hwOrange),
            tooltip: 'Sort by Status',
            onSelected: (val) => setState(() => _statusSort = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'default', child: Text('All (Newest)')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'completed', child: Text('Completed')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
              const PopupMenuItem(value: 'processing', child: Text('Processing')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: hwOrange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminChatScreen()),
              );
            },
            tooltip: 'Support Messages',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: p.text),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar outside stream builder so typing never loses focus
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Glass(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                style: ts(p.text, 14),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search incoming orders by ID or items...',
                  hintStyle: ts(p.faint, 13),
                  border: InputBorder.none,
                  icon: const Icon(Icons.search_rounded, color: hwOrange, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: p.faint, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: firestoreService.streamAllOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 4,
                    itemBuilder: (_, __) => const SkeletonCard(),
                  );
                }
                final orders = snapshot.data ?? [];
                final query = _searchController.text.trim().toLowerCase();

                final activeOrders = orders.where((o) {
                  final isActive = o.status != 'completed' && o.status != 'cancelled';
                  if (!isActive) return false;
                  if (query.isEmpty) return true;
                  final matchId = o.id.toLowerCase().contains(query);
                  final matchItems = o.items.any((item) => item.name.toLowerCase().contains(query));
                  final matchStatus = o.status.toLowerCase().contains(query);
                  return matchId || matchItems || matchStatus;
                }).toList();

                if (_statusSort != 'default') {
                  activeOrders.sort((a, b) {
                    if (a.status.toLowerCase() == _statusSort && b.status.toLowerCase() != _statusSort) return -1;
                    if (b.status.toLowerCase() == _statusSort && a.status.toLowerCase() != _statusSort) return 1;
                    return 0;
                  });
                }

                if (activeOrders.isEmpty) {
                  return Center(child: Text('No active orders to process.', style: ts(p.faint, 15)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: activeOrders.length,
                  itemBuilder: (context, index) {
                    final o = activeOrders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Glass(
                        radius: 20,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getStatusColor(o.status).withValues(alpha: 0.15),
                              child: Icon(Icons.shopping_basket_rounded, color: _getStatusColor(o.status)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${o.id.substring(0, o.id.length > 5 ? 5 : o.id.length)}',
                                    style: ts(p.text, 16, FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${o.items.length} ${o.items.length == 1 ? 'item' : 'items'} • ₱${o.total.toStringAsFixed(2)}',
                                    style: ts(p.sub, 13, FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${o.status.toUpperCase()}',
                                    style: TextStyle(color: _getStatusColor(o.status), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: p.faint),
                              onPressed: () => context.push('/staff/order/${o.id}', extra: o),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'processing': return Colors.blue;
      case 'ready': return Colors.green;
      case 'out_for_delivery': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
