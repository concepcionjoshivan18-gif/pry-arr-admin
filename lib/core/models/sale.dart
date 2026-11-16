import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';

class SaleModel {
  final String id;
  final String orderId;
  final double totalAmount;
  final String staffId;
  final String staffName;
  final DateTime createdAt;
  final List<CartItem> items;

  SaleModel({
    required this.id,
    required this.orderId,
    required this.totalAmount,
    required this.staffId,
    required this.staffName,
    required this.createdAt,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'totalAmount': totalAmount,
      'staffId': staffId,
      'staffName': staffName,
      'createdAt': Timestamp.fromDate(createdAt),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map, String docId) {
    var itemsList = map['items'] as List? ?? [];
    List<CartItem> parsedItems = itemsList.map((i) => CartItem.fromMap(Map<String, dynamic>.from(i))).toList();

    return SaleModel(
      id: docId,
      orderId: map['orderId'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: parsedItems,
    );
  }
}
