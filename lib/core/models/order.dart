import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';

class OrderModel {
  final String id;
  final String customerId;
  final List<CartItem> items;
  final String status; // pending, processing, out_for_delivery, completed, cancelled
  final double total;
  final DateTime createdAt;
  
  // Loyalty Point Data
  final int pointsEarned;
  final int pointsRedeemed;

  // Fulfillment & Payment details
  final String fulfillmentType; // "pickup" | "delivery"
  final String paymentMethod; // "Cash", "COD", "GCash", "Card"

  // GCash Payment Verification & Review fields
  final String paymentStatus; // "paid", "pending_review", "rejected", "refunded_pending", "refunded"
  final String? gcashReferenceNumber;
  final double? gcashAmount;
  final String? reviewReason; // "wrong_amount", "missing_reference", "unreadable_image", "duplicate_reference"
  final String? receiptImageUrl;
  final String? reviewNote;

  // Pinned Customer Location for Rider Navigation
  final double? deliveryLat;
  final double? deliveryLng;
  final String? deliveryAddress;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.items,
    required this.status,
    required this.total,
    required this.createdAt,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.fulfillmentType = 'delivery',
    this.paymentMethod = 'Cash',
    String? paymentStatus,
    this.gcashReferenceNumber,
    this.gcashAmount,
    this.reviewReason,
    this.receiptImageUrl,
    this.reviewNote,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryAddress,
  }) : paymentStatus = paymentStatus ?? (paymentMethod == 'GCash' ? 'pending_review' : 'paid');

  double get subtotal => items.fold<double>(0.0, (sum, i) => sum + (i.price * i.qty));
  double get shippingFee => total > subtotal ? (total - subtotal) : 0.0;
  String get customerName => 'Customer';

  double? get latitude => deliveryLat;
  double? get longitude => deliveryLng;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status,
      'total': total,
      'createdAt': Timestamp.fromDate(createdAt),
      'pointsEarned': pointsEarned,
      'pointsRedeemed': pointsRedeemed,
      'fulfillmentType': fulfillmentType,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'gcashReferenceNumber': gcashReferenceNumber,
      'gcashAmount': gcashAmount,
      'reviewReason': reviewReason,
      'receiptImageUrl': receiptImageUrl,
      'reviewNote': reviewNote,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'deliveryAddress': deliveryAddress,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    var itemsList = map['items'] as List? ?? [];
    List<CartItem> parsedItems = itemsList.map((i) => CartItem.fromMap(Map<String, dynamic>.from(i))).toList();

    DateTime time;
    if (map['createdAt'] is Timestamp) {
      time = (map['createdAt'] as Timestamp).toDate();
    } else {
      time = DateTime.now();
    }

    final payMethod = map['paymentMethod'] ?? 'Cash';
    final defaultPayStatus = payMethod == 'GCash' ? 'pending_review' : 'paid';

    return OrderModel(
      id: docId,
      customerId: map['customerId'] ?? '',
      items: parsedItems,
      status: map['status'] ?? 'pending',
      total: (map['total'] ?? 0.0).toDouble(),
      createdAt: time,
      pointsEarned: map['pointsEarned'] ?? 0,
      pointsRedeemed: map['pointsRedeemed'] ?? 0,
      fulfillmentType: map['fulfillmentType'] ?? 'delivery',
      paymentMethod: payMethod,
      paymentStatus: map['paymentStatus'] ?? defaultPayStatus,
      gcashReferenceNumber: map['gcashReferenceNumber'],
      gcashAmount: map['gcashAmount'] != null ? (map['gcashAmount'] as num).toDouble() : null,
      reviewReason: map['reviewReason'],
      receiptImageUrl: map['receiptImageUrl'],
      reviewNote: map['reviewNote'],
      deliveryLat: (map['deliveryLat'] ?? map['latitude']) != null ? ((map['deliveryLat'] ?? map['latitude']) as num).toDouble() : null,
      deliveryLng: (map['deliveryLng'] ?? map['longitude']) != null ? ((map['deliveryLng'] ?? map['longitude']) as num).toDouble() : null,
      deliveryAddress: map['deliveryAddress'],
    );
  }
}
