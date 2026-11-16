import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String productId;
  final String productName;
  final String? orderId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final double rating; // 1.0 to 5.0
  final String comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.orderId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'orderId': orderId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReviewModel(
      id: docId,
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? 'Hardware Item',
      orderId: map['orderId'],
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      userPhoto: map['userPhoto'],
      rating: (map['rating'] ?? 5.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
