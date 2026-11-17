import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import '../../core/theme/hardware_theme.dart';

class DigitalReceiptScreen extends StatelessWidget {
  final List<dynamic> items;
  final double total;
  final int pointsEarned;
  final double discount;
  final String paymentMethod;

  const DigitalReceiptScreen({
    super.key,
    required this.items,
    required this.total,
    required this.pointsEarned,
    required this.discount,
    this.paymentMethod = 'Cash',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.75),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Successful',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: hwCharcoal),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.now()),
                  style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                const SizedBox(height: 20),

                ...items.map((it) {
                  final String name = (it is Map) ? (it['name'] ?? 'Item') : (it.name ?? 'Item');
                  final int qty = (it is Map) ? (it['qty'] ?? 1) : (it.qty ?? 1);
                  final double price = (it is Map) ? ((it['price'] ?? 0.0) as num).toDouble() : (it.price ?? 0.0);
                  final String? varName = (it is Map) ? it['variant'] : (it.variant);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name${varName != null && varName.toString().isNotEmpty ? " ($varName)" : ""} x$qty',
                            style: const TextStyle(fontSize: 14, color: hwCharcoal, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '₱${(price * qty).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14, color: hwCharcoal, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 20),
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                const SizedBox(height: 16),

                if (discount > 0) ...[
                  _row('Discount', '-₱${discount.toStringAsFixed(2)}', color: Colors.redAccent),
                  const SizedBox(height: 4),
                ],
                _row('Total Amount', '₱${total.toStringAsFixed(2)}', isBold: true, fontSize: 16),
                const SizedBox(height: 4),
                _row('Mode of Payment', paymentMethod, isBold: true, fontSize: 14),
                
                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1, color: Colors.black12),
                const SizedBox(height: 24),

                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final pdfData = await _generatePdf();
                    await Printing.sharePdf(bytes: pdfData, filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: hwOrange),
                  label: const Text('Download PDF Receipt', style: TextStyle(color: hwCharcoal, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thank you for shopping at PRY-ARR Hardware!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PRY-ARR HARDWARE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 22)),
                    pw.Text('DIGITAL RECEIPT', style: const pw.TextStyle(color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text('Date: ${DateFormat('MMM dd, yyyy • HH:mm').format(DateTime.now())}'),
                pw.Text('Payment Method: $paymentMethod'),
                pw.SizedBox(height: 24),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),
                ...items.map((it) {
                  final String name = (it is Map) ? (it['name'] ?? 'Item') : (it.name ?? 'Item');
                  final int qty = (it is Map) ? (it['qty'] ?? 1) : (it.qty ?? 1);
                  final double price = (it is Map) ? ((it['price'] ?? 0.0) as num).toDouble() : (it.price ?? 0.0);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$name x$qty'),
                        pw.Text('₱${(price * qty).toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),
                if (discount > 0)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount'), pw.Text('-₱${discount.toStringAsFixed(2)}')]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('₱${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                pw.Spacer(),
                pw.Center(child: pw.Text('Thank you for shopping at PRY-ARR Hardware!', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
              ],
            ),
          );
        },
      ),
    );
    return pdf.save();
  }

  Widget _row(String label, String val, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: hwCharcoal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              val,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: color ?? hwCharcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
