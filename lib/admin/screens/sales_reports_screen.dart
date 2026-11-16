import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/sale.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/attendance.dart';
import '../../core/models/app_user.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/skeleton_loader.dart';

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDays = 30; // 7, 30, or 90 days
  String? _selectedFilterDay; // null means All days, or "Sunday", "Monday", etc.
  String _attendanceSearchQuery = '';
  DateTime? _attendanceFilterDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Widget _glass({
    required Widget child,
    double radius = 20,
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

  Widget _buildHardwareBackground() => const SizedBox.shrink();

  void _generateFullAuditReport() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    _showSnack('Compiling data for audit report...');

    try {
      final sales = await firestore.streamSales().first;
      final items = await firestore.streamInventory().first;
      final customers = await firestore.streamAllCustomers().first;

      final filteredSales = sales.where((s) => s.createdAt.isAfter(DateTime.now().subtract(Duration(days: _selectedDays)))).toList();

      final pdf = pw.Document();
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('PRY-ARR HARDWARE SYSTEM AUDIT REPORT (${_selectedDays}D)')),
          pw.Text('Generated on: ${DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now())}'),
          pw.SizedBox(height: 20),

          pw.Header(level: 1, text: 'Sales Summary (Last $_selectedDays Days)'),
          pw.TableHelper.fromTextArray(
            headers: ['Order ID', 'Total', 'Processed By', 'Date'],
            data: filteredSales.map((s) => [s.orderId.substring(0, 8), 'P${s.totalAmount}', s.staffName, DateFormat('MM/dd').format(s.createdAt)]).toList(),
          ),

          pw.Header(level: 1, text: 'Inventory Status'),
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Stock', 'Threshold'],
            data: items.map((i) => [i.name, '${i.totalQuantity}', '${i.lowStockThreshold}']).toList(),
          ),

          pw.Header(level: 1, text: 'Customer Loyalty Ledger'),
          pw.TableHelper.fromTextArray(
            headers: ['Customer Name', 'Points Balance', 'Email'],
            data: customers.map((c) => [c.fullName, '${c.loyaltyPoints}', c.email]).toList(),
          ),
        ],
      ));

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report Error: $e'), backgroundColor: hwRust));
      }
    }
  }

  void _showSnack(String message) {
    final p = Pal.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: p.text)),
        backgroundColor: p.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        _buildHardwareBackground(),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_rounded, color: hwOrange, size: 22),
                    const SizedBox(width: 10),
                    Text('System Audit & Analytics', style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 18)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _generateFullAuditReport,
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: hwOrange, size: 16),
                        label: const Text('EXPORT', style: TextStyle(color: hwOrange, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          backgroundColor: hwOrange.withValues(alpha: 0.12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _glass(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: p.text,
                      unselectedLabelColor: p.faint,
                      indicator: BoxDecoration(
                        color: hwOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(6),
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                      tabs: const [
                        Tab(text: 'SALES', icon: Icon(Icons.payments_outlined, size: 16)),
                        Tab(text: 'INVENTORY', icon: Icon(Icons.inventory_2_outlined, size: 16)),
                        Tab(text: 'ATTENDANCE', icon: Icon(Icons.alarm, size: 16)),
                        Tab(text: 'LOYALTY', icon: Icon(Icons.stars_outlined, size: 16)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _KeepAliveTab(child: _buildSalesTab(context, firestoreService)),
                      _KeepAliveTab(child: _buildInventoryTab(context, firestoreService)),
                      _KeepAliveTab(child: _buildAttendanceTab(context, firestoreService)),
                      _KeepAliveTab(child: _buildLoyaltyTab(context, firestoreService)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab(BuildContext context, FirestoreService service) {
    final p = Pal.of(context);
    return StreamBuilder<List<SaleModel>>(
      stream: service.streamSales(),
      builder: (context, snapshot) {
        if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonCard(),
          );
        }
        final allSales = snapshot.data ?? [];
        final cutoff = DateTime.now().subtract(Duration(days: _selectedDays));
        final filteredSales = allSales.where((s) => s.createdAt.isAfter(cutoff)).toList();

        final totalRevenue = filteredSales.fold<double>(0.0, (sum, s) => sum + s.totalAmount);
        final avgDailyRevenue = _selectedDays > 0 ? totalRevenue / _selectedDays : 0.0;
        final avgDailyOrders = _selectedDays > 0 ? filteredSales.length / _selectedDays : 0.0;

        final displaySales = _selectedFilterDay == null
            ? filteredSales
            : filteredSales.where((s) => DateFormat('EEEE').format(s.createdAt) == _selectedFilterDay).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Time Period Analytics:', style: TextStyle(color: p.text, fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(
                    children: [
                      _buildTimePeriodButton(context, 7, '7d'),
                      const SizedBox(width: 8),
                      _buildTimePeriodButton(context, 30, '30d'),
                      const SizedBox(width: 8),
                      _buildTimePeriodButton(context, 90, '90d'),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _glass(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avg Daily Sales', style: TextStyle(color: p.faint, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('₱${avgDailyRevenue.toStringAsFixed(2)}', style: TextStyle(color: p.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Past $_selectedDays Days', style: TextStyle(color: p.faint, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _glass(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Avg Daily Orders', style: TextStyle(color: p.faint, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${avgDailyOrders.toStringAsFixed(1)} / day', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Total: ${filteredSales.length} Orders', style: TextStyle(color: p.faint, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildSundayToMondayAnalytics(context, filteredSales),
            const SizedBox(height: 4),

            if (_selectedFilterDay != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtered for $_selectedFilterDay (${displaySales.length} orders)',
                      style: TextStyle(color: p.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _selectedFilterDay = null),
                        child: const Text('SHOW ALL DAYS', style: TextStyle(color: hwOrange, fontWeight: FontWeight.bold, fontSize: 11, decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: displaySales.isEmpty
                  ? _buildEmptyState(context, 'No sales recorded for ${_selectedFilterDay ?? "the past $_selectedDays days"}.')
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                itemCount: displaySales.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final s = displaySales[idx];
                  return _glass(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: hwOrange.withValues(alpha: 0.18), shape: BoxShape.circle),
                          child: const Icon(Icons.receipt_long_rounded, color: hwOrange, size: 18),
                        ),
                        title: Text('Order Ref: ${s.orderId.substring(0, 8)}', style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                        subtitle: Text('Processed by ${s.staffName} • ${DateFormat('EEE, MMM dd HH:mm').format(s.createdAt)}', style: TextStyle(color: p.faint, fontSize: 11)),
                        trailing: Text('₱${s.totalAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: p.amber, fontSize: 16)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSundayToMondayAnalytics(BuildContext context, List<SaleModel> sales) {
    final p = Pal.of(context);
    const daysOrder = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    Map<String, double> daySales = {for (var d in daysOrder) d: 0.0};
    Map<String, int> dayOrders = {for (var d in daysOrder) d: 0};

    for (var s in sales) {
      final dayName = DateFormat('EEEE').format(s.createdAt);
      if (daySales.containsKey(dayName)) {
        daySales[dayName] = (daySales[dayName] ?? 0.0) + s.totalAmount;
        dayOrders[dayName] = (dayOrders[dayName] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6),
      child: _glass(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sunday to Monday Breakdown (Tap a day to filter list)', style: TextStyle(color: p.text, fontWeight: FontWeight.bold, fontSize: 12)),
                const Icon(Icons.touch_app, color: hwYellow, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: daysOrder.map((day) {
                  final salesAmt = daySales[day] ?? 0.0;
                  final ordersCnt = dayOrders[day] ?? 0;
                  final isSelected = _selectedFilterDay == day;

                  return Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedFilterDay == day) {
                            _selectedFilterDay = null;
                          } else {
                            _selectedFilterDay = day;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 95,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? hwOrange : p.fill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? hwOrange : p.line,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              day.substring(0, 3).toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : p.sub,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${salesAmt.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isSelected ? Colors.white : p.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$ordersCnt ${ordersCnt == 1 ? 'order' : 'orders'}',
                              style: TextStyle(
                                color: isSelected ? Colors.white70 : p.faint,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePeriodButton(BuildContext context, int days, String label) {
    final p = Pal.of(context);
    final isSelected = _selectedDays == days;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDays = days;
            _selectedFilterDay = null;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? hwOrange : p.fill,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? null : Border.all(color: p.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : p.sub,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryTab(BuildContext context, FirestoreService service) {
    final p = Pal.of(context);
    return StreamBuilder<List<InventoryItem>>(
      stream: service.streamInventory(),
      builder: (context, snapshot) {
        if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonCard(),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildEmptyState(context, 'No inventory items found.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final i = items[idx];
            final low = i.totalQuantity <= i.lowStockThreshold;
            return _glass(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: (low ? hwRust : hwOrange).withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: Icon(Icons.inventory_2_rounded, color: low ? hwRust : hwOrange, size: 18),
                  ),
                  title: Text(i.name, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  subtitle: Text('Stock Level: ${i.totalQuantity} units', style: TextStyle(color: p.faint)),
                  trailing: Chip(
                    label: Text(
                      low ? 'LOW STOCK' : 'OPTIMAL',
                      style: TextStyle(color: low ? Colors.white : hwCharcoal, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                    backgroundColor: low ? hwRust : hwYellow,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceTab(BuildContext context, FirestoreService service) {
    final p = Pal.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Attendance Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.text)),
              ElevatedButton.icon(
                onPressed: () => _showAddAttendanceDialog(context, service),
                icon: const Icon(Icons.add),
                label: const Text('Add Manual Attendance'),
                style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        // Filter & Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: p.text),
                  decoration: InputDecoration(
                    hintText: 'Search staff name...',
                    hintStyle: TextStyle(color: p.faint),
                    prefixIcon: Icon(Icons.search, color: p.faint),
                    filled: true,
                    fillColor: p.fill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
                  ),
                  onChanged: (v) => setState(() => _attendanceSearchQuery = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _attendanceFilterDate ?? DateTime.now(),
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _attendanceFilterDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_attendanceFilterDate != null ? DateFormat('yyyy-MM-dd').format(_attendanceFilterDate!) : 'Filter Date'),
                style: ElevatedButton.styleFrom(backgroundColor: p.fill, foregroundColor: p.text, side: BorderSide(color: p.line)),
              ),
              if (_attendanceFilterDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _attendanceFilterDate = null),
                  tooltip: 'Clear Date Filter',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<AttendanceModel>>(
            stream: service.streamAttendance(),
            builder: (context, snapshot) {
              if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: 4,
                  itemBuilder: (_, __) => const SkeletonCard(),
                );
              }
              final logs = snapshot.data ?? [];

              Map<String, List<AttendanceModel>> grouped = {};
              for (var l in logs) {
                if (l.staffId == null) continue;
                final dateKey = DateFormat('yyyy-MM-dd').format(l.timestamp);

                // Apply date filter
                if (_attendanceFilterDate != null) {
                  final filterKey = DateFormat('yyyy-MM-dd').format(_attendanceFilterDate!);
                  if (dateKey != filterKey) continue;
                }

                final staffName = (l.staffName != null && l.staffName!.trim().isNotEmpty) ? l.staffName! : 'Staff';
                // Apply search query filter
                if (_attendanceSearchQuery.isNotEmpty && !staffName.toLowerCase().contains(_attendanceSearchQuery)) {
                  continue;
                }

                final key = "${l.staffId}_$dateKey";
                grouped.putIfAbsent(key, () => []).add(l);
              }

              // Sort newest date first
              final sortedKeys = grouped.keys.toList()..sort((a, b) {
                final dateA = grouped[a]!.first.timestamp;
                final dateB = grouped[b]!.first.timestamp;
                return dateB.compareTo(dateA);
              });

              if (sortedKeys.isEmpty) return _buildEmptyState(context, 'No matching attendance records found.');

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: sortedKeys.length,
                itemBuilder: (context, idx) {
                  final key = sortedKeys[idx];
                  final staffLogs = grouped[key]!;
                  // Sort chronologically so earliest is Time-In and latest is Time-Out
                  staffLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                  final timeIn = staffLogs.firstOrNull;
                  final timeOut = staffLogs.length > 1 ? staffLogs.last : null;
                  final rawName = staffLogs.first.staffName;
                  final staffName = (rawName != null && rawName.trim().isNotEmpty) ? rawName : 'Staff';
                  final date = DateFormat('MMMM dd, yyyy').format(staffLogs.first.timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _glass(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staffName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: p.text)),
                                const SizedBox(height: 4),
                                Text(date, style: TextStyle(color: p.faint, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: p.fill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: p.line),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      const Text('TIME IN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hwYellow)),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeIn != null ? DateFormat('hh:mm a').format(timeIn.timestamp) : '--:--',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: p.text),
                                      ),
                                    ],
                                  ),
                                  Container(width: 1, height: 30, color: p.line),
                                  Column(
                                    children: [
                                      const Text('TIME OUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: hwOrange)),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeOut != null ? DateFormat('hh:mm a').format(timeOut.timestamp) : '--:--',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: p.text),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: hwRust, size: 22),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: p.surface,
                                  title: const Text('Delete Attendance'),
                                  content: Text('Are you sure you want to delete attendance records for $staffName on $date?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: hwRust, foregroundColor: Colors.white),
                                      onPressed: () async {
                                        for (var l in staffLogs) {
                                          await service.deleteAttendance(l.id);
                                        }
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Attendance records deleted successfully')),
                                          );
                                        }
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            tooltip: 'Delete Attendance',
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
    );
  }

  void _showAddAttendanceDialog(BuildContext context, FirestoreService service) {
    String? selectedStaffId;
    String selectedType = 'Time-In';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text('Manual Attendance Entry'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<List<AppUser>>(
                  stream: service.streamStaffAccounts(),
                  builder: (context, snapshot) {
                    final staffList = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedStaffId,
                      decoration: const InputDecoration(labelText: 'Select Staff', border: OutlineInputBorder()),
                      items: staffList.map((s) => DropdownMenuItem(value: s.uid, child: Text(s.fullName))).toList(),
                      onChanged: (val) => setStateModal(() => selectedStaffId = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Attendance Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Time-In', child: Text('Time-In')),
                    DropdownMenuItem(value: 'Time-Out', child: Text('Time-Out')),
                  ],
                  onChanged: (val) => setStateModal(() => selectedType = val!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (date != null) setStateModal(() => selectedDate = date);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(selectedTime.format(context)),
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            initialEntryMode: TimePickerEntryMode.input,
                          );
                          if (time != null) setStateModal(() => selectedTime = time);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStaffId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select staff')));
                  return;
                }
                final staffUser = await service.getUser(selectedStaffId!);
                final rawName = staffUser?.fullName.trim();
                final staffName = (rawName != null && rawName.isNotEmpty) ? rawName : (staffUser?.email ?? 'Staff');

                final combinedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                // Enforce once-a-day and valid time order validation
                final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                final endOfDay = startOfDay.add(const Duration(days: 1));

                final existingLogsQuery = await FirebaseFirestore.instance
                    .collection('attendance')
                    .where('staffId', isEqualTo: selectedStaffId)
                    .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
                    .get();

                final existingLogs = existingLogsQuery.docs
                    .map((d) => AttendanceModel.fromMap(d.data(), d.id))
                    .toList();

                final existingTimeIn = existingLogs.where((l) => l.type == 'Time-In').firstOrNull;
                final existingTimeOut = existingLogs.where((l) => l.type == 'Time-Out').firstOrNull;

                if (selectedType == 'Time-In') {
                  if (existingTimeIn != null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Staff already has a Time-In recorded for this date.')),
                      );
                    }
                    return;
                  }
                  if (existingTimeOut != null && combinedDateTime.isAfter(existingTimeOut.timestamp)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Time-In cannot be after the existing Time-Out.')),
                      );
                    }
                    return;
                  }
                } else if (selectedType == 'Time-Out') {
                  if (existingTimeOut != null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Staff already has a Time-Out recorded for this date.')),
                      );
                    }
                    return;
                  }
                  if (existingTimeIn != null && combinedDateTime.isBefore(existingTimeIn.timestamp)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: Time-Out cannot be earlier than Time-In.')),
                      );
                    }
                    return;
                  }
                }

                final newRecord = AttendanceModel(
                  id: '',
                  staffId: selectedStaffId,
                  staffName: staffName,
                  timestamp: combinedDateTime,
                  type: selectedType,
                  success: true,
                  reason: 'Manual entry by admin',
                );

                await service.addAttendance(newRecord);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual attendance added successfully')));
                }
              },
              child: const Text('Save Record'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyTab(BuildContext context, FirestoreService service) {
    final p = Pal.of(context);
    return StreamBuilder<List<AppUser>>(
      stream: service.streamAllCustomers(),
      builder: (context, snapshot) {
        if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonCard(),
          );
        }
        final customers = snapshot.data ?? [];
        if (customers.isEmpty) return _buildEmptyState(context, 'No loyalty members registered yet.');

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          itemCount: customers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final c = customers[idx];
            return _glass(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: hwYellow.withValues(alpha: 0.2),
                    child: const Icon(Icons.stars, color: hwYellow),
                  ),
                  title: Text(c.fullName, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                  subtitle: Text(c.email, style: TextStyle(color: p.faint)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${c.loyaltyPoints}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: p.text)),
                      const Text('POINTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38)),
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

  Widget _buildEmptyState(BuildContext context, String message) {
    final p = Pal.of(context);
    return Center(
      child: _glass(
        radius: 24,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: p.faint, size: 36),
            const SizedBox(height: 14),
            Text(message, style: TextStyle(color: p.sub)),
          ],
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
