import 'package:cloud_firestore/cloud_firestore.dart';

class PayslipModel {
  final String id;
  final String invoiceNumber;
  final String staffId;
  final String staffName;
  final String companyName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double hoursWorked;
  final double hourlyRate;
  final double grossPay;
  final double deductions;
  final double additions;
  final double netPay;
  final DateTime dateGenerated;
  final String status; // "Generated" | "Sent" | "Viewed" | "Acknowledged"

  PayslipModel({
    required this.id,
    required this.invoiceNumber,
    required this.staffId,
    required this.staffName,
    required this.companyName,
    required this.periodStart,
    required this.periodEnd,
    required this.hoursWorked,
    required this.hourlyRate,
    required this.grossPay,
    required this.deductions,
    required this.additions,
    required this.netPay,
    required this.dateGenerated,
    this.status = 'Generated',
  });

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,
      'staffId': staffId,
      'staffName': staffName,
      'companyName': companyName,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'hoursWorked': hoursWorked,
      'hourlyRate': hourlyRate,
      'grossPay': grossPay,
      'deductions': deductions,
      'additions': additions,
      'netPay': netPay,
      'dateGenerated': Timestamp.fromDate(dateGenerated),
      'status': status,
    };
  }

  factory PayslipModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayslipModel(
      id: docId,
      invoiceNumber: map['invoiceNumber'] ?? '',
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      companyName: map['companyName'] ?? 'PRY-ARR Hardware',
      periodStart: (map['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (map['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hoursWorked: (map['hoursWorked'] ?? 0.0).toDouble(),
      hourlyRate: (map['hourlyRate'] ?? 0.0).toDouble(),
      grossPay: (map['grossPay'] ?? 0.0).toDouble(),
      deductions: (map['deductions'] ?? 0.0).toDouble(),
      additions: (map['additions'] ?? 0.0).toDouble(),
      netPay: (map['netPay'] ?? 0.0).toDouble(),
      dateGenerated: (map['dateGenerated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'Generated',
    );
  }
}
