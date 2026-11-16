import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/order.dart';
import '../../core/models/app_user.dart';
import '../../core/models/chat_message.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';
import '../../core/services/google_maps_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'attendance_screen.dart';
import 'staff_profile_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  int _currentIndex = 0;
  OrderModel? _selectedMapOrder;
  String _deliverySort = 'default';
  final TextEditingController _searchController = TextEditingController();
  LatLng? _driverLocation;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _fetchDriverLocation();
  }

  void _fetchDriverLocation() async {
    final loc = await GoogleMapsService.getCurrentGpsLocation();
    if (loc != null && mounted) {
      setState(() {
        _driverLocation = LatLng(loc['lat']!, loc['lng']!);
      });
    }
    _updateRoadRoute();
  }

  void _updateRoadRoute() async {
    final order = _selectedMapOrder;
    final targetLat = order?.deliveryLat ?? 14.2650;
    final targetLng = order?.deliveryLng ?? 121.4261;
    final origin = _driverLocation ?? const LatLng(14.2818, 121.4167);

    final points = await GoogleMapsService.fetchRoadRoutePoints(
      origin.latitude,
      origin.longitude,
      targetLat,
      targetLng,
    );

    if (mounted) {
      setState(() {
        _routePoints = points;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const tabs = [
    (Icons.local_shipping_rounded, 'Deliveries'),
    (Icons.location_on_rounded, 'Map Pin'),
    (Icons.alarm_rounded, 'Shift/Time'),
    (Icons.person_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final themeController = Provider.of<ThemeController>(context);
    final driverUser = authService.currentUser;
    final p = Pal.of(context);

    return Pal(
      dark: themeController.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: Background()),
            SafeArea(
              child: Column(
                children: [
                  // ---- Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome back, ${driverUser?.firstName ?? "Driver"}', style: ts(p.faint, 13)),
                              const SizedBox(height: 2),
                              Text('Driver Portal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ts(p.text, 22, FontWeight.w800)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GlassIconButton(
                          onTap: () => authService.signOut(),
                          icon: Icon(Icons.logout_rounded, color: p.sub),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ---- Body
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        _buildDeliveriesTab(firestoreService, driverUser, p),
                        _buildMapPinTab(p),
                        const AttendanceScreen(showAppBar: false),
                        const StaffProfileScreen(),
                      ],
                    ),
                  ),
                  // ---- Bottom Glass Pill Nav Bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Glass(
                          radius: 32.5,
                          child: SizedBox(
                            height: 65,
                            child: Stack(
                              children: [
                                AnimatedAlign(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment(-1.0 + (_currentIndex * (2.0 / (tabs.length - 1))), 0),
                                  child: FractionallySizedBox(
                                    widthFactor: 1 / tabs.length,
                                    child: Container(
                                      margin: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: hwOrange.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (int i = 0; i < tabs.length; i++)
                                      Expanded(
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(32.5),
                                          onTap: () {
                                            setState(() => _currentIndex = i);
                                            if (i == 1) {
                                              _fetchDriverLocation();
                                            }
                                          },
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(tabs[i].$1, size: 22, color: i == _currentIndex ? hwOrange : p.sub),
                                              const SizedBox(height: 2),
                                              Text(
                                                tabs[i].$2,
                                                style: ts(i == _currentIndex ? hwOrange : p.sub, 11, i == _currentIndex ? FontWeight.w800 : FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: DELIVERIES LIST
  // --------------------------------------------------------------------------
  Widget _buildDeliveriesTab(FirestoreService fs, AppUser? driver, Pal p) {
    return Column(
      children: [
        // Search Bar outside stream builder so typing never loses focus
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Glass(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: ts(p.text, 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search deliveries by ID or items...',
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
            stream: fs.streamAllOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allOrders = snapshot.data ?? [];
              final query = _searchController.text.trim().toLowerCase();

              final deliveryOrders = allOrders.where((o) {
                final isPendingDelivery = o.status == 'processing' || o.status == 'out_for_delivery';
                if (!isPendingDelivery) return false;
                if (query.isEmpty) return true;
                final matchId = o.id.toLowerCase().contains(query);
                final matchItems = o.items.any((item) => item.name.toLowerCase().contains(query));
                final matchStatus = o.status.toLowerCase().contains(query);
                return matchId || matchItems || matchStatus;
              }).toList();

              if (_deliverySort != 'default') {
                deliveryOrders.sort((a, b) => (a.status.toLowerCase() == _deliverySort ? 0 : 1).compareTo(b.status.toLowerCase() == _deliverySort ? 0 : 1));
              }

              if (deliveryOrders.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.ok.withValues(alpha: 0.15),
                              border: Border.all(color: p.ok, width: 3),
                            ),
                            child: Icon(Icons.check_rounded, size: 56, color: p.ok),
                          ),
                          const SizedBox(height: 20),
                          Text('All deliveries completed!', style: ts(p.text, 20, FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(
                            "Great work today. New orders will appear here\nas soon as they're assigned.",
                            textAlign: TextAlign.center,
                            style: ts(p.faint, 13).copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${deliveryOrders.length} Pending Deliveries Ready', style: ts(p.text, 16, FontWeight.w700)),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.sort_rounded, color: hwOrange, size: 20),
                          tooltip: 'Sort by Status',
                          onSelected: (val) => setState(() => _deliverySort = val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'default', child: Text('All (Newest)')),
                            const PopupMenuItem(value: 'processing', child: Text('Processing')),
                            const PopupMenuItem(value: 'out_for_delivery', child: Text('Out for Delivery')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  for (final order in deliveryOrders)
                    _buildDeliveryOrderCard(order, fs, driver, p),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOrderCard(OrderModel order, FirestoreService fs, AppUser? driver, Pal p) {
    final auth = Provider.of<AuthService>(context, listen: false);
    Color statusColor = Colors.orange;
    if (order.status == 'processing') statusColor = Colors.blue;
    if (order.status == 'out_for_delivery') statusColor = Colors.purple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
        radius: 20,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)}', style: ts(p.text, 16, FontWeight.w800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(order.status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Placed: ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}', style: ts(p.faint, 12)),
            Divider(height: 20, color: p.line),

            // Items summary
            Text('Delivery Package (${order.items.length} items):', style: ts(p.sub, 13, FontWeight.w700)),
            const SizedBox(height: 6),
            ...order.items.map((it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('• ${it.name} x${it.qty}', style: ts(p.text, 13)),
                  Text('₱${(it.price * it.qty).toStringAsFixed(2)}', style: ts(p.faint, 13)),
                ],
              ),
            )),
            const SizedBox(height: 10),
            // Delivery Destination Pinned Location Card
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hwOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: hwOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pin_drop_rounded, color: hwOrange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Pinned Location:', style: ts(hwOrange, 11, FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          order.deliveryAddress ?? order.fulfillmentType,
                          style: ts(p.text, 12, FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'GPS Coordinates: ${(order.deliveryLat ?? 14.5995).toStringAsFixed(4)}° N, ${(order.deliveryLng ?? 120.9842).toStringAsFixed(4)}° E',
                          style: ts(p.faint, 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount Due:', style: ts(p.text, 14, FontWeight.w700)),
                Text('₱${order.total.toStringAsFixed(2)}', style: ts(p.amber, 16, FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showDriverChatModal(context, order, fs, auth);
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.blue),
                    label: const Text('CHAT', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedMapOrder = order;
                        _currentIndex = 1; // Switch to Map Pin tab
                      });
                    },
                    icon: const Icon(Icons.pin_drop_rounded, size: 16, color: hwOrange),
                    label: const Text('MAP PIN', style: TextStyle(color: hwOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: hwOrange),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (order.status != 'out_for_delivery')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await fs.updateOrderStatus(order.id, 'out_for_delivery');
                        if (mounted) {
                          showTopNotification(context, 'Order #${order.id.substring(0, 5)} is Out for Delivery!', isSuccess: true);
                        }
                      },
                      icon: const Icon(Icons.local_shipping, size: 16),
                      label: const Text('DISPATCH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: driver == null ? null : () async {
                        await fs.finalizeOrder(order, driver);
                        if (mounted) {
                          showTopNotification(context, 'Order #${order.id.substring(0, 5)} marked as DELIVERED!', isSuccess: true);
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('DELIVERED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverChatModal(BuildContext context, OrderModel order, FirestoreService fs, AuthService auth) async {
    final driverUser = auth.currentUser;
    final chatId = await fs.getOrCreateConversation(
      type: 'delivery',
      customerId: order.customerId,
      driverId: driverUser?.uid,
      orderId: order.id,
    );
    final isClosed = order.status == 'completed' || order.status == 'cancelled';
    final chatCtrl = TextEditingController();
    final scrollCtrl = ScrollController();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: const BoxDecoration(
          color: Color(0xFF1F2429),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, color: hwOrange),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Delivery Chat - Order #${order.id.substring(0, 5)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(color: Colors.white12),
            if (isClosed)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('This delivery conversation is closed (order completed or cancelled).', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: fs.streamChatMessages(chatId),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet. Send a message to the customer.', style: TextStyle(color: Colors.white54)));
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: messages.length,
                    itemBuilder: (context, idx) {
                      final m = messages[idx];
                      final isMe = m.senderId == (driverUser?.uid ?? 'driver');
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? hwOrange : Colors.white12,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('${m.senderName}: ${m.text}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (!isClosed)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: chatCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message customer...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: hwOrange),
                    onPressed: () async {
                      final t = chatCtrl.text.trim();
                      if (t.isEmpty) return;
                      chatCtrl.clear();
                      await fs.sendChatMessage(
                        chatId,
                        ChatMessage(
                          id: '',
                          conversationId: chatId,
                          senderId: driverUser?.uid ?? 'driver',
                          senderName: driverUser?.fullName ?? 'Delivery Driver',
                          senderRole: 'driver',
                          recipientId: order.customerId,
                          text: t,
                          timestamp: DateTime.now(),
                          orderId: order.id,
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _openGoogleMapsApp(double lat, double lng, String address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pal.of(context).surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.map_rounded, color: hwOrange, size: 24),
            const SizedBox(width: 8),
            Text('Google Maps Navigation', style: ts(Pal.of(context).text, 16, FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delivery Destination:', style: ts(Pal.of(context).faint, 12)),
            const SizedBox(height: 4),
            Text(address, style: ts(Pal.of(context).text, 13, FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hwOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed_rounded, color: hwOrange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pinned GPS: $lat° N, $lng° E',
                      style: ts(hwOrange, 12, FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: Pal.of(context).faint)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await GoogleMapsService.launchNativeGoogleMapsNavigation(lat, lng);
            },
            icon: const Icon(Icons.navigation_rounded, size: 18),
            label: const Text('START NAVIGATION', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: INTERACTIVE MAP & PINNED LOCATION VIEW
  // --------------------------------------------------------------------------
  Widget _buildMapPinTab(Pal p) {
    final order = _selectedMapOrder;
    final targetLat = order?.deliveryLat ?? 14.2650;
    final targetLng = order?.deliveryLng ?? 121.4261;
    final targetAddress = order?.deliveryAddress ?? order?.fulfillmentType ?? 'PRY-ARR Delivery Destination';
    final driverOrigin = _driverLocation ?? const LatLng(14.2818, 121.4167);
    final targetLatLng = LatLng(targetLat, targetLng);
    final centerLat = (driverOrigin.latitude + targetLat) / 2;
    final centerLng = (driverOrigin.longitude + targetLng) / 2;

    return Column(
      children: [
        // Map Top Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Glass(
            radius: 16,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order != null
                        ? 'Google Maps Delivery Route: Order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)}'
                        : 'Select a delivery order to view pinned Google Maps location & route',
                    style: ts(p.text, 13, FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, color: hwOrange, size: 20),
                  tooltip: 'Update Phone GPS Location',
                  onPressed: () {
                    _fetchDriverLocation();
                    showTopNotification(context, 'Updating rider phone GPS location...', isSuccess: true);
                  },
                ),
              ],
            ),
          ),
        ),

        // REAL INTERACTIVE GOOGLE MAPS CANVAS WITH ROUTE POLYLINE
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Glass(
              radius: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: p.dark ? const Color(0xFF14171A) : const Color(0xFFE5E3DF),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: kIsWeb
                            ? Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      GoogleMapsService.getStaticMapUrl(targetLat, targetLng),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF14171A),
                                        child: Center(
                                          child: Icon(Icons.map_rounded, size: 64, color: hwOrange.withValues(alpha: 0.4)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : GoogleMap(
                                key: ValueKey('driver_map_${driverOrigin.latitude}_${driverOrigin.longitude}_${targetLat}_$targetLng'),
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(centerLat, centerLng),
                                  zoom: 12,
                                ),
                                mapType: MapType.normal,
                                zoomControlsEnabled: true,
                                myLocationEnabled: true,
                                polylines: {
                                  Polyline(
                                    polylineId: const PolylineId('driver_to_customer_route'),
                                    points: _routePoints.isNotEmpty ? _routePoints : [driverOrigin, targetLatLng],
                                    color: hwOrange,
                                    width: 5,
                                  ),
                                },
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('driver_origin'),
                                    position: driverOrigin,
                                    infoWindow: const InfoWindow(title: 'Rider / Store Current Location'),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                  ),
                                  Marker(
                                    markerId: const MarkerId('customer_destination'),
                                    position: targetLatLng,
                                    infoWindow: InfoWindow(
                                      title: order != null
                                          ? 'Order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} Customer House'
                                          : 'Customer Delivery Destination Pin',
                                      snippet: targetAddress,
                                    ),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                  ),
                                },
                              ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Glass(
                          radius: 18,
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: hwOrange.withValues(alpha: 0.2),
                                    child: const Icon(Icons.navigation_rounded, color: hwOrange),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order != null
                                              ? 'Order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} Destination'
                                              : 'PRY-ARR Delivery Location',
                                          style: ts(p.text, 14, FontWeight.w800),
                                        ),
                                        Text(
                                          targetAddress,
                                          style: ts(p.faint, 11),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Divider(color: p.line),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'GPS Pinned Coordinates:',
                                      style: ts(p.faint, 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${targetLat.toStringAsFixed(4)}° N, ${targetLng.toStringAsFixed(4)}° E', style: ts(hwOrange, 11, FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    GoogleMapsService.launchNativeGoogleMapsNavigation(targetLat, targetLng);
                                  },
                                  icon: const Icon(Icons.navigation_rounded, size: 18),
                                  label: const Text('START TURN-BY-TURN NAVIGATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hwOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  const GlassIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 22,
        child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool dark;
  _MapGridPainter(this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 2;

    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += 50) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = hwOrange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(60, 80);
    path.lineTo(140, 180);
    path.lineTo(size.width - 80, size.height - 180);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
