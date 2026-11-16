import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/payslip.dart';

class PdfGenerator {
  static Future<Uint8List> generatePayslipPdf(PayslipModel payslip) async {
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
                    pw.Text(payslip.companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                    pw.Text('PAYROLL INVOICE', style: const pw.TextStyle(color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EMPLOYEE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(payslip.staffName),
                        pw.Text('ID: ${payslip.staffId.substring(0, 8).toUpperCase()}'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('INVOICE NO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(payslip.invoiceNumber),
                        pw.Text('Generated: ${DateFormat('MMM dd, yyyy').format(payslip.dateGenerated)}'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 16),
                pw.Text('PAY PERIOD: ${DateFormat('MMM dd').format(payslip.periodStart)} - ${DateFormat('MMM dd, yyyy').format(payslip.periodEnd)}'),
                pw.SizedBox(height: 32),
                
                _pwRow('Hours Worked', payslip.hoursWorked.toStringAsFixed(1)),
                _pwRow('Hourly Rate', '₱${payslip.hourlyRate.toStringAsFixed(2)}'),
                pw.SizedBox(height: 16),
                _pwRow('GROSS PAY', '₱${payslip.grossPay.toStringAsFixed(2)}', isBold: true),
                pw.SizedBox(height: 8),
                _pwRow('Deductions', '-₱${payslip.deductions.toStringAsFixed(2)}', color: PdfColors.red),
                _pwRow('Bonuses/Additions', '+₱${payslip.additions.toStringAsFixed(2)}', color: PdfColors.green),
                pw.SizedBox(height: 32),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  color: PdfColors.grey100,
                  child: _pwRow('NET TAKE-HOME PAY', '₱${payslip.netPay.toStringAsFixed(2)}', isBold: true, fontSize: 18),
                ),
                
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text('This is a computer-generated document. No signature required.', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pwRow(String label, String val, {bool isBold = false, double fontSize = 12, PdfColor? color}) {
    final style = pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: fontSize, color: color);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(val, style: style),
        ],
      ),
    );
  }
}
