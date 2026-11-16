import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // "customer" | "admin" | "staff" | "driver"
  final String recipientId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final String? orderId;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.recipientId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.orderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientId': recipientId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'orderId': orderId,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    DateTime time = DateTime.now();
    if (map['timestamp'] is Timestamp) {
      time = (map['timestamp'] as Timestamp).toDate();
    }
    return ChatMessage(
      id: docId,
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'User',
      senderRole: map['senderRole'] ?? 'customer',
      recipientId: map['recipientId'] ?? '',
      text: map['text'] ?? '',
      timestamp: time,
      isRead: map['isRead'] ?? false,
      orderId: map['orderId'],
    );
  }
}
