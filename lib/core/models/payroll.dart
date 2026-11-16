import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollModel {
  final String id;
  final String staffId;
  final String employeeName;
  final double basicSalary;
  final double overtime;
  final double deductions;
  final double allowances;
  final double grossPay;
  final double netPay;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status; // "Paid" | "Pending"
  final DateTime createdAt;

  PayrollModel({
    required this.id,
    required this.staffId,
    required this.employeeName,
    required this.basicSalary,
    required this.overtime,
    required this.deductions,
    required this.allowances,
    required this.grossPay,
    required this.netPay,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'employeeName': employeeName,
      'basicSalary': basicSalary,
      'overtime': overtime,
      'deductions': deductions,
      'allowances': allowances,
      'grossPay': grossPay,
      'netPay': netPay,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PayrollModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayrollModel(
      id: docId,
      staffId: map['staffId'] ?? '',
      employeeName: map['employeeName'] ?? '',
      basicSalary: (map['basicSalary'] ?? 0.0).toDouble(),
      overtime: (map['overtime'] ?? 0.0).toDouble(),
      deductions: (map['deductions'] ?? 0.0).toDouble(),
      allowances: (map['allowances'] ?? 0.0).toDouble(),
      grossPay: (map['grossPay'] ?? 0.0).toDouble(),
      netPay: (map['netPay'] ?? 0.0).toDouble(),
      periodStart: (map['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (map['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'Pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
