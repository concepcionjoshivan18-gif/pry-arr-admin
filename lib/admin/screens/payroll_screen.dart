import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/app_user.dart';
import '../../core/models/payslip.dart';
import '../../core/models/attendance.dart';
import '../../core/utils/pdf_generator.dart';
import '../../core/components/top_notification.dart';
import 'package:intl/intl.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/skeleton_loader.dart';

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

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        _hwBackground(),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: hwOrange, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Automated Daily Payroll (Cash Basis)',
                      style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<AttendanceModel>>(
                  stream: firestoreService.streamAttendance(),
                  builder: (context, attSnapshot) {
                    return StreamBuilder<List<AppUser>>(
                      stream: firestoreService.streamStaffAccounts(),
                      builder: (context, staffSnapshot) {
                        return StreamBuilder<List<PayslipModel>>(
                          stream: firestoreService.streamAllPayslips(),
                          builder: (context, payslipSnapshot) {
                            if (attSnapshot.connectionState == ConnectionState.waiting ||
                                staffSnapshot.connectionState == ConnectionState.waiting ||
                                payslipSnapshot.connectionState == ConnectionState.waiting) {
                              return ListView.builder(
                                padding: const EdgeInsets.all(32),
                                itemCount: 4,
                                itemBuilder: (_, __) => const SkeletonCard(),
                              );
                            }

                            final attendanceLogs = attSnapshot.data ?? [];
                            final staffList = staffSnapshot.data ?? [];
                            final existingPayslips = payslipSnapshot.data ?? [];

                            // Group attendance logs by staffId and Date
                            final Map<String, List<AttendanceModel>> groupedLogs = {};
                            for (var l in attendanceLogs) {
                              if (l.staffId == null || l.staffId!.isEmpty) continue;
                              final dateKey = DateFormat('yyyy-MM-dd').format(l.timestamp);
                              final groupKey = "${l.staffId}_$dateKey";
                              groupedLogs.putIfAbsent(groupKey, () => []).add(l);
                            }

                            final sortedKeys = groupedLogs.keys.toList()..sort((a, b) => b.compareTo(a));

                            if (sortedKeys.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 64, color: p.faint),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No staff attendance logs found to compute daily payroll.',
                                      style: TextStyle(color: p.sub),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'When staff time-in & time-out, daily cash payroll is automatically calculated here!',
                                      style: TextStyle(color: p.faint, fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                              itemCount: sortedKeys.length,
                              itemBuilder: (context, index) {
                                final key = sortedKeys[index];
                                final logs = groupedLogs[key]!;
                                final firstLog = logs.first;
                                final staffId = firstLog.staffId!;
                                final dateStr = DateFormat('MMMM dd, yyyy').format(firstLog.timestamp);

                                // Find matching staff user to get hourly rate (basicSalary)
                                final staffUser = staffList.where((s) => s.uid == staffId).firstOrNull;
                                final hourlyRate = staffUser?.basicSalary ?? 100.0; // Fallback hourly rate

                                // Find Time-In and Time-Out
                                final tin = logs.where((l) => l.type == 'Time-In').firstOrNull;
                                final tout = logs.where((l) => l.type == 'Time-Out').firstOrNull;

                                double hoursWorked = 0.0;
                                String timeInStr = '--:--';
                                String timeOutStr = 'Awaiting Time-Out';

                                if (tin != null) {
                                  timeInStr = DateFormat('hh:mm a').format(tin.timestamp);
                                }

                                if (tin != null && tout != null) {
                                  timeOutStr = DateFormat('hh:mm a').format(tout.timestamp);
                                  final diffMinutes = tout.timestamp.difference(tin.timestamp).inMinutes;
                                  hoursWorked = (diffMinutes / 60.0).clamp(0.0, 24.0);
                                } else if (tin != null && tout == null) {
                                  final elapsedMin = DateTime.now().difference(tin.timestamp).inMinutes;
                                  hoursWorked = (elapsedMin / 60.0).clamp(0.0, 24.0);
                                  timeOutStr = 'Shift In Progress';
                                }

                                // Automatic computation
                                final grossPay = hoursWorked * hourlyRate;
                                final netCashPay = grossPay; // Net daily cash pay

                                // Check if recorded/disbursed in payslip database
                                final invoiceRef = 'CASH-${key.replaceAll('-', '')}';
                                final existing = existingPayslips
                                    .where((ps) =>
                                ps.invoiceNumber == invoiceRef ||
                                    (ps.staffId == staffId &&
                                        DateFormat('yyyy-MM-dd').format(ps.periodEnd) ==
                                            DateFormat('yyyy-MM-dd').format(firstLog.timestamp)))
                                    .firstOrNull;

                                final isDisbursed = existing != null &&
                                    (existing.status == 'Disbursed (Cash)' ||
                                        existing.status == 'Sent' ||
                                        existing.status == 'Acknowledged');

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _hwGlass(
                                    radius: 22,
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: isDisbursed
                                                      ? Colors.greenAccent.withValues(alpha: 0.16)
                                                      : hwOrange.withValues(alpha: 0.16),
                                                  child: Icon(
                                                    Icons.payments,
                                                    color: isDisbursed ? Colors.greenAccent : hwOrange,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      firstLog.staffName ?? 'Staff Member',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: p.text,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(dateStr, style: TextStyle(color: p.faint, fontSize: 12)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDisbursed
                                                    ? Colors.greenAccent.withValues(alpha: 0.15)
                                                    : hwYellow.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDisbursed ? Colors.greenAccent : hwYellow,
                                                ),
                                              ),
                                              child: Text(
                                                isDisbursed ? 'DISBURSED (CASH)' : 'AUTO-COMPUTED DAILY PAY',
                                                style: TextStyle(
                                                  color: isDisbursed ? Colors.greenAccent : hwYellow,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        Divider(color: p.line, height: 24),

                                        // Attendance & Calculation Breakdown
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: p.fill,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'SHIFT ATTENDANCE',
                                                      style: TextStyle(
                                                        color: p.faint,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'In: $timeInStr  •  Out: $timeOutStr',
                                                      style: TextStyle(
                                                        color: p.text,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Total: ${hoursWorked.toStringAsFixed(1)} hrs',
                                                      style: TextStyle(color: p.amber, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: p.fill,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'HOURLY RATE & GROSS',
                                                      style: TextStyle(
                                                        color: p.faint,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '₱${hourlyRate.toStringAsFixed(2)} / hr',
                                                      style: TextStyle(
                                                        color: p.text,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${hoursWorked.toStringAsFixed(1)} hrs × ₱${hourlyRate.toStringAsFixed(0)}',
                                                      style: TextStyle(color: p.faint, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: hwOrange.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: hwOrange.withValues(alpha: 0.3)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'DAILY CASH SALARY',
                                                      style: TextStyle(
                                                        color: p.sub,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '₱${netCashPay.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: p.amber,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    Text('Cash Basis', style: TextStyle(color: p.faint, fontSize: 10)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Action buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () async {
                                                final payslipModel = PayslipModel(
                                                  id: existing?.id ?? '',
                                                  invoiceNumber: invoiceRef,
                                                  staffId: staffId,
                                                  staffName: firstLog.staffName ?? 'Staff',
                                                  companyName: 'PRY-ARR Hardware Store',
                                                  periodStart: firstLog.timestamp,
                                                  periodEnd: firstLog.timestamp,
                                                  hoursWorked: hoursWorked,
                                                  hourlyRate: hourlyRate,
                                                  grossPay: grossPay,
                                                  deductions: 0.0,
                                                  additions: 0.0,
                                                  netPay: netCashPay,
                                                  dateGenerated: DateTime.now(),
                                                  status: 'Disbursed (Cash)',
                                                );
                                                final bytes = await PdfGenerator.generatePayslipPdf(payslipModel);
                                                await Printing.sharePdf(
                                                  bytes: bytes,
                                                  filename: 'DailyPayroll_$invoiceRef.pdf',
                                                );
                                              },
                                              icon: Icon(Icons.print_rounded, size: 16, color: p.sub),
                                              label: Text(
                                                'PRINT CASH VOUCHER',
                                                style: TextStyle(color: p.sub, fontSize: 11),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: p.line),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            if (!isDisbursed)
                                              ElevatedButton.icon(
                                                onPressed: () async {
                                                  final payslipModel = PayslipModel(
                                                    id: '',
                                                    invoiceNumber: invoiceRef,
                                                    staffId: staffId,
                                                    staffName: firstLog.staffName ?? 'Staff',
                                                    companyName: 'PRY-ARR Hardware Store',
                                                    periodStart: firstLog.timestamp,
                                                    periodEnd: firstLog.timestamp,
                                                    hoursWorked: hoursWorked,
                                                    hourlyRate: hourlyRate,
                                                    grossPay: grossPay,
                                                    deductions: 0.0,
                                                    additions: 0.0,
                                                    netPay: netCashPay,
                                                    dateGenerated: DateTime.now(),
                                                    status: 'Disbursed (Cash)',
                                                  );
                                                  await firestoreService.createPayslip(payslipModel);
                                                  if (context.mounted) {
                                                    showTopNotification(
                                                      context,
                                                      'Daily Cash Salary marked as DISBURSED!',
                                                      isSuccess: true,
                                                    );
                                                  }
                                                },
                                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                                label: Text(
                                                  'DISBURSE CASH (₱${netCashPay.toStringAsFixed(0)})',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: hwOrange,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              )
                                            else
                                              ElevatedButton.icon(
                                                onPressed: null,
                                                icon: const Icon(Icons.verified, size: 16, color: Colors.green),
                                                label: const Text(
                                                  'DISBURSED IN CASH',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
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
}