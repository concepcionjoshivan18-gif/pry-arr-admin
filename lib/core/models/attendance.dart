import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String? staffId; // Null if RFID not recognized
  final String? staffName; // Null if RFID not recognized
  final DateTime timestamp;
  final String type; // "Time-In" | "Time-Out"
  final bool success;
  final String? reason; // Reason for failure if any
  final String? rfidUid;

  AttendanceModel({
    required this.id,
    this.staffId,
    this.staffName,
    required this.timestamp,
    required this.type,
    this.success = true,
    this.reason,
    this.rfidUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'success': success,
      'reason': reason,
      'rfidUid': rfidUid,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String docId) {
    return AttendanceModel(
      id: docId,
      staffId: map['staffId']?.toString(),
      staffName: map['staffName']?.toString(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type']?.toString() ?? 'Time-In',
      success: map['success'] == true, // Explicit bool check
      reason: map['reason']?.toString(),
      rfidUid: map['rfidUid']?.toString(),
    );
  }
}
