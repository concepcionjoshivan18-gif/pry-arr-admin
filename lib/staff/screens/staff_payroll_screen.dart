import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/payslip.dart';
import '../../core/utils/pdf_generator.dart';
import 'package:intl/intl.dart';

class StaffPayrollScreen extends StatelessWidget {
  const StaffPayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final fs = Provider.of<FirestoreService>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('My Payroll History')),
      body: StreamBuilder<List<PayslipModel>>(
        stream: fs.streamStaffPayslips(user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Only show released payslips
          final payslips = snapshot.data?.where((p) => p.status != 'Generated').toList() ?? [];

          if (payslips.isEmpty) {
            return const Center(child: Text('No released payslips found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payslips.length,
            itemBuilder: (context, index) {
              final p = payslips[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text('Invoice ${p.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Period: ${DateFormat('MMM dd').format(p.periodStart)} - ${DateFormat('MMM dd').format(p.periodEnd)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₱${p.netPay.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                      _badge(p.status),
                    ],
                  ),
                  onTap: () => _showDetail(context, p),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _badge(String status) {
    Color color = Colors.grey;
    if (status == 'Acknowledged') color = Colors.green;
    if (status == 'Sent') color = Colors.blue;
    if (status == 'Viewed') color = Colors.orange;

    return Text(
      status.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }

  void _showDetail(BuildContext context, PayslipModel p) async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    
    // Update status to Viewed if it was Sent
    if (p.status == 'Sent') {
      await fs.updatePayslipStatus(p.id, 'Viewed');
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Icon(Icons.receipt_long, size: 64, color: Colors.blueGrey)),
              const SizedBox(height: 24),
              Center(child: Text('PAYROLL INVOICE', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
              Center(child: Text(p.invoiceNumber, style: const TextStyle(color: Colors.grey))),
              const Divider(height: 64),
              _row('Company', p.companyName),
              _row('Pay Period', '${DateFormat('MMM dd').format(p.periodStart)} - ${DateFormat('MMM dd').format(p.periodEnd)}'),
              _row('Hours Worked', p.hoursWorked.toStringAsFixed(1)),
              _row('Hourly Rate', '₱${p.hourlyRate.toStringAsFixed(2)}'),
              const Divider(),
              _row('Gross Pay', '₱${p.grossPay.toStringAsFixed(2)}'),
              _row('Deductions', '-₱${p.deductions.toStringAsFixed(2)}', color: Colors.red),
              _row('Bonuses', '+₱${p.additions.toStringAsFixed(2)}', color: Colors.green),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16)),
                child: _row('NET TAKE-HOME PAY', '₱${p.netPay.toStringAsFixed(2)}', isBold: true),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await PdfGenerator.generatePayslipPdf(p);
                        await Printing.sharePdf(bytes: bytes, filename: 'Payslip_${p.invoiceNumber}.pdf');
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT / DOWNLOAD'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (p.status != 'Acknowledged')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await fs.updatePayslipStatus(p.id, 'Acknowledged');
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('ACKNOWLEDGE'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
