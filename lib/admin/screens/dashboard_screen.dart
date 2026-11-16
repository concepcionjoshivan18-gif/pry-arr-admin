import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/order.dart';
import '../../core/models/sale.dart';
import '../../core/models/app_user.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/skeleton_loader.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedDays = 30; // 7, 30, or 90 days

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final themeController = Provider.of<ThemeController>(context);
    final p = Pal.of(context);

    return StreamBuilder<List<InventoryItem>>(
      stream: firestoreService.streamInventory(),
      builder: (context, invSnapshot) {
        if (invSnapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonCard(),
          );
        }
        return StreamBuilder<List<OrderModel>>(
          stream: firestoreService.streamAllOrders(),
          builder: (context, orderSnapshot) {
            if (orderSnapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: 4,
                itemBuilder: (_, __) => const SkeletonCard(),
              );
            }
            return StreamBuilder<List<SaleModel>>(
              stream: firestoreService.streamSales(),
              builder: (context, saleSnapshot) {
                if (saleSnapshot.connectionState == ConnectionState.waiting) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: 4,
                    itemBuilder: (_, __) => const SkeletonCard(),
                  );
                }
                return StreamBuilder<List<AppUser>>(
                  stream: firestoreService.streamAllAccounts(),
                  builder: (context, accountsSnapshot) {
                    if (accountsSnapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: 4,
                        itemBuilder: (_, __) => const SkeletonCard(),
                      );
                    }
                    final items = invSnapshot.data ?? [];
                    final orders = orderSnapshot.data ?? [];
                    final sales = saleSnapshot.data ?? [];
                    final allUsers = accountsSnapshot.data ?? [];

                    final totalRevenue = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
                    final pendingOrdersCount = orders.where((o) => o.status == 'pending').length;
                    final lowStockCount = items.where((i) => i.totalQuantity <= i.lowStockThreshold).length;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(36, 24, 48, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.hardware_rounded, color: hwOrange, size: 26),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            'Hardware Store Dashboard',
                                            style: ts(p.text, 28, FontWeight.w800),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Home / Dashboard / Overview',
                                      style: ts(p.faint, 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildTopBar(themeController, items),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // TOP ROW METRIC CARDS
                          Row(
                            children: [
                              _buildMetricCard('Total Revenue', '₱${NumberFormat('#,###').format(totalRevenue)}', '+12.5%', hwOrange, true, Icons.payments_rounded),
                              const SizedBox(width: 24),
                              _buildMetricCard('Active Accounts', '${allUsers.length}', '+${allUsers.where((u) => u.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length} new', hwSteel, true, Icons.engineering_rounded),
                              const SizedBox(width: 24),
                              _buildMetricCard('Pending Orders', '$pendingOrdersCount', 'Action Required', hwYellow, false, Icons.local_shipping_rounded),
                              const SizedBox(width: 24),
                              _buildMetricCard('Stock Health', '${items.length - lowStockCount}/${items.length}', '${items.isNotEmpty ? ((items.length - lowStockCount) / items.length * 100).toInt() : 0}%', hwRust, true, Icons.inventory_2_rounded),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // PENDING PAYMENTS BANNER
                          GestureDetector(
                            onTap: () => context.go('/admin/pending-payments'),
                            child: Glass(
                              radius: 20,
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: hwOrange.withValues(alpha: 0.2)),
                                    child: const Icon(Icons.payments_rounded, color: hwOrange, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Pending GCash Payments Review', style: ts(p.text, 16, FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text('Tap here to review pending receipts, verify amounts, and confirm or reject payments.', style: ts(p.faint, 13)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: hwOrange, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // MIDDLE ROW: REVENUE TRENDS & INVENTORY DISTRIBUTION
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildRevenueTrendsCard(orders)),
                              const SizedBox(width: 24),
                              Expanded(flex: 1, child: _buildInventoryDistributionCard(items)),
                            ],
                          ),

                          const SizedBox(height: 32),
                          // BOTTOM ROW: RECENT ACTIVITY
                          _buildOrderFulfillmentSection(orders.take(5).toList()),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, String trend, Color color, bool isPositive, IconData icon) {
    final p = Pal.of(context);
    final trendColor = isPositive ? (p.dark ? Colors.greenAccent : const Color(0xFF1B8A4B)) : hwRust;
    return Expanded(
      child: Glass(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: ts(p.faint, 13, FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: ts(p.text, 24, FontWeight.w900)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(isPositive ? Icons.arrow_upward_rounded : Icons.info_outline_rounded, color: trendColor, size: 14),
                const SizedBox(width: 4),
                Text(trend, style: ts(trendColor, 12, FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Computes daily sales totals for the given number of days, oldest to newest.
  /// Fills days with no completed sales with 0.0.
  /// Only counts orders with status 'completed', ignoring 'cancelled'.
  List<double> dailySales(List<OrderModel> orders, int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysList = List.generate(days, (i) => today.subtract(Duration(days: days - 1 - i)));

    final dailyTotals = <String, double>{};
    for (final d in daysList) {
      dailyTotals[DateFormat('yyyy-MM-dd').format(d)] = 0.0;
    }

    for (final order in orders) {
      if (order.status.toLowerCase() == 'completed') {
        final key = DateFormat('yyyy-MM-dd').format(order.createdAt);
        if (dailyTotals.containsKey(key)) {
          dailyTotals[key] = dailyTotals[key]! + order.total;
        }
      }
    }

    return dailyTotals.values.toList();
  }

  Widget _buildRevenueTrendsCard(List<OrderModel> orders) {
    final data = dailySales(orders, _selectedDays);
    return SizedBox(
      height: 420,
      child: RevenueCard(
        data: data,
        range: _selectedDays,
        onRangeChanged: (v) => setState(() => _selectedDays = v),
      ),
    );
  }

  Widget _buildInventoryDistributionCard(List<InventoryItem> items) {
    final p = Pal.of(context);
    final categoryCounts = <String, int>{};
    for (final i in items) {
      categoryCounts[i.categoryId] = (categoryCounts[i.categoryId] ?? 0) + 1;
    }

    final sortedCats = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sortedCats.take(3).toList();
    final totalItems = items.length;

    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventory Split', style: ts(p.text, 18, FontWeight.bold)),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              height: 180,
              width: 180,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  segments: [
                    _DonutSegment(top3.isNotEmpty ? top3[0].value.toDouble() : 1, hwOrange),
                    _DonutSegment(top3.length > 1 ? top3[1].value.toDouble() : 0, hwYellow),
                    _DonutSegment(top3.length > 2 ? top3[2].value.toDouble() : 0, hwRust),
                    _DonutSegment(math.max(0, totalItems - top3.fold(0, (s, e) => s + e.value)).toDouble(), p.dark ? Colors.white12 : Colors.black12),
                  ],
                  centerLabel: '',
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          ...top3.map((cat) => _buildDistributionRow(cat.key, (cat.value / totalItems * 100).toStringAsFixed(1), _getCatColor(top3.indexOf(cat)))),
          if (totalItems - top3.fold(0, (s, e) => s + e.value) > 0)
            _buildDistributionRow('Others', ((totalItems - top3.fold(0, (s, e) => s + e.value)) / totalItems * 100).toStringAsFixed(1), p.faint),
        ],
      ),
    );
  }

  Color _getCatColor(int index) {
    if (index == 0) return hwOrange;
    if (index == 1) return hwYellow;
    return hwRust;
  }

  Widget _buildDistributionRow(String label, String percent, Color color) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: ts(p.sub, 14)),
              Text('$percent%', style: ts(p.text, 14, FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: double.parse(percent) / 100,
              backgroundColor: p.track,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeController tc, List<InventoryItem> items) {
    final lowStockItems = items.where((i) => i.totalQuantity <= i.lowStockThreshold).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Low Stock Notification Bell Button & Badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: hwOrange),
              onPressed: () => _showLowStockDialog(lowStockItems),
              tooltip: 'Low Stock Alerts',
            ),
            if (lowStockItems.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('${lowStockItems.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        ThemeSwitchWidget(
          dark: tc.dark,
          onToggle: () => tc.toggleTheme(),
        ),
      ],
    );
  }

  void _showLowStockDialog(List<InventoryItem> lowStockItems) {
    final p = Pal.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Low Stock Alerts (${lowStockItems.length})', style: ts(p.text, 18, FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: lowStockItems.isEmpty
              ? Center(child: Text('All items have healthy stock levels!', style: ts(p.faint, 14)))
              : ListView.builder(
                  itemCount: lowStockItems.length,
                  itemBuilder: (context, index) {
                    final item = lowStockItems[index];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
                      title: Text(item.name, style: ts(p.text, 14, FontWeight.bold)),
                      subtitle: Text('Current Stock: ${item.totalQuantity} (Threshold: ${item.lowStockThreshold})', style: ts(p.faint, 12)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: hwOrange)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderFulfillmentSection(List<OrderModel> orders) {
    final p = Pal.of(context);
    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Storefront Orders', style: ts(p.text, 18, FontWeight.bold)),
              TextButton(
                onPressed: () => context.go('/admin/sales'),
                child: const Text('View All Sales', style: TextStyle(color: hwOrange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(child: Text('No recent orders', style: ts(p.faint, 14))),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, i) {
                final o = orders[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: hwOrange.withValues(alpha: 0.15),
                    child: const Icon(Icons.shopping_bag_rounded, color: hwOrange, size: 18),
                  ),
                  title: Text('Order #${o.id.substring(0, math.min(5, o.id.length))}', style: ts(p.text, 14, FontWeight.bold)),
                  subtitle: Text('${o.items.length} items • ₱${o.total.toStringAsFixed(2)}', style: ts(p.faint, 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (o.status == 'completed' ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(o.status.toUpperCase(), style: TextStyle(color: o.status == 'completed' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DonutSegment {
  final double value;
  final Color color;
  _DonutSegment(this.value, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final String centerLabel;
  _DonutChartPainter({required this.segments, required this.centerLabel});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0.0, (s, e) => s + e.value);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 26.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweepAngle = (seg.value / total) * 2 * math.pi;
      paint.color = seg.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ───────────── Smooth Line Chart Components ─────────────
String _fmt(double v) {
  final s = v.toStringAsFixed(v >= 1000 ? 0 : 2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

class RevenueCard extends StatelessWidget {
  final List<double> data;
  final int range;
  final ValueChanged<int> onRangeChanged;
  const RevenueCard({
    super.key,
    required this.data,
    required this.range,
    required this.onRangeChanged,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final hasData = data.length >= 2 && data.any((v) => v > 0);

    final total = data.isEmpty ? 0.0 : data.reduce((a, b) => a + b);
    final avg = data.isEmpty ? 0.0 : total / data.length;
    final best = data.isEmpty ? 0.0 : data.reduce(math.max);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = [
      for (var i = 0; i < data.length; i++)
        () {
          final t = today.subtract(Duration(days: data.length - 1 - i));
          return '${_months[t.month - 1]} ${t.day}';
        }()
    ];
    final ticks = hasData
        ? [
            for (var i = 0; i < 5; i++)
              dates[((data.length - 1) * i / 4).round()]
          ]
        : <String>[];

    return Glass(
      radius: 24,
      padding: const EdgeInsets.all(26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Revenue trends & daily sales',
                      style: ts(p.text, 20, FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Avg daily sales: ₱${_fmt(avg)}',
                      style: ts(p.faint, 13)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: range,
                dropdownColor: p.surface,
                borderRadius: BorderRadius.circular(16),
                style: ts(p.text, 14, FontWeight.bold),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                  DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                  DropdownMenuItem(value: 90, child: Text('Last 90 days')),
                ],
                onChanged: (v) => onRangeChanged(v ?? 30),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 36, runSpacing: 8, children: [
          _stat('Total', '₱${_fmt(total)}', p),
          _stat('Best day', '₱${_fmt(best)}', p),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: hasData
              ? SalesChart(data: data, dates: dates)
              : Center(
                  child: Text('No sales in this period yet',
                      style: ts(p.faint, 14))),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final t in ticks)
            Text(t, style: ts(p.faint, 12)),
        ]),
      ]),
    );
  }

  Widget _stat(String l, String v, Pal p) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: ts(p.faint, 12)),
        const SizedBox(height: 2),
        Text(v,
            style: ts(p.text, 20, FontWeight.w700)),
      ]);
}

class SalesChart extends StatefulWidget {
  final List<double> data;
  final List<String> dates;
  const SalesChart({super.key, required this.data, required this.dates});
  @override
  State<SalesChart> createState() => _SalesChartState();
}

class _SalesChartState extends State<SalesChart> {
  int? hover;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final n = d.length;
    var mx = d.reduce(math.max) * 1.15;
    if (mx == 0) mx = 1;

    return LayoutBuilder(builder: (context, c) {
      void set(double dx) {
        final i = (dx / c.maxWidth * (n - 1)).round().clamp(0, n - 1);
        if (i != hover) setState(() => hover = i);
      }

      final h = hover != null && hover! < n ? hover : null;
      Widget? tip;
      if (h != null) {
        final x = c.maxWidth * h / (n - 1);
        final y = c.maxHeight * (1 - d[h] / mx);
        tip = Positioned(
          left: (x - 62).clamp(0.0, math.max(0.0, c.maxWidth - 124)),
          top: (y - 62).clamp(0.0, math.max(0.0, c.maxHeight - 50)),
          child: IgnorePointer(
            child: Container(
              width: 124,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFF1B2232), borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.dates[h],
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 2),
                Text('₱${_fmt(d[h])}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      }

      return MouseRegion(
        onHover: (e) => set(e.localPosition.dx),
        onExit: (_) => setState(() => hover = null),
        child: GestureDetector(
          onPanDown: (e) => set(e.localPosition.dx),
          onPanUpdate: (e) => set(e.localPosition.dx),
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: LinePainter(d, hwOrange, hover: h)),
            if (tip != null) tip,
          ]),
        ),
      );
    });
  }
}

class LinePainter extends CustomPainter {
  final List<double> d;
  final Color c;
  final int? hover;
  LinePainter(this.d, this.c, {this.hover});

  @override
  void paint(Canvas canvas, Size s) {
    var mx = d.reduce(math.max) * 1.15;
    if (mx == 0) mx = 1;

    final gp = Paint()
      ..color = Colors.black.withOpacity(.06)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = s.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(s.width, y), gp);
    }

    final pts = [
      for (var i = 0; i < d.length; i++)
        Offset(s.width * i / (d.length - 1), s.height * (1 - d[i] / mx))
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p = pts[i - 1], q = pts[i];
      final mid = (p.dx + q.dx) / 2;
      line.cubicTo(mid, p.dy, mid, q.dy, q.dx, q.dy);
    }

    final area = Path.from(line)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withOpacity(.3), c.withOpacity(0)],
          ).createShader(Offset.zero & s));

    canvas.drawPath(
        line,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);

    final idx = hover ?? pts.length - 1;
    final p = pts[idx];
    if (hover != null) {
      canvas.drawLine(
          Offset(p.dx, 0),
          Offset(p.dx, s.height),
          Paint()
            ..color = c.withOpacity(.35)
            ..strokeWidth = 1);
    }
    canvas.drawCircle(p, 8, Paint()..color = Colors.white);
    canvas.drawCircle(p, 5.5, Paint()..color = c);
  }

  @override
  bool shouldRepaint(covariant LinePainter old) => true;
}
