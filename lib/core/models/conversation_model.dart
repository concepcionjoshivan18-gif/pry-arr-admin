import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final String type; // 'support' | 'delivery'
  final String customerId;
  final String? driverId;
  final String? orderId;
  final String status; // 'open' | 'resolved' | 'closed'
  final DateTime createdAt;
  final String lastMessage;
  final String lastSender;
  final String lastRole;
  final DateTime updatedAt;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.type,
    required this.customerId,
    this.driverId,
    this.orderId,
    required this.status,
    required this.createdAt,
    required this.lastMessage,
    required this.lastSender,
    required this.lastRole,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'customerId': customerId,
      'driverId': driverId,
      'orderId': orderId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'lastSender': lastSender,
      'lastRole': lastRole,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'unreadCount': unreadCount,
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      return DateTime.now();
    }

    return ConversationModel(
      id: docId,
      type: map['type'] ?? 'support',
      customerId: map['customerId'] ?? '',
      driverId: map['driverId'],
      orderId: map['orderId'],
      status: map['status'] ?? 'open',
      createdAt: parseDate(map['createdAt']),
      lastMessage: map['lastMessage'] ?? '',
      lastSender: map['lastSender'] ?? '',
      lastRole: map['lastRole'] ?? '',
      updatedAt: parseDate(map['updatedAt']),
      unreadCount: map['unreadCount'] ?? 0,
    );
  }
}
