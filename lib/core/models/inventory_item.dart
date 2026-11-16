import 'package:cloud_firestore/cloud_firestore.dart';

class ProductVariant {
  final String name;
  final int quantity;
  final double price;

  ProductVariant({
    required this.name,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      name: map['name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String categoryId;
  final List<ProductVariant> variants;
  final int lowStockThreshold;
  final String status; // "Active", "Inactive"
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sku;
  final List<String> imageUrls;

  InventoryItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.variants = const [],
    required this.lowStockThreshold,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sku,
    this.imageUrls = const [],
  });

  // Helper getters for backward compatibility / display
  int get totalQuantity => variants.fold(0, (sum, v) => sum + v.quantity);
  double get displayPrice => variants.isNotEmpty ? variants.first.price : 0.0;
  int get imageBytesEstimate => imageUrls.fold(0, (sum, url) => sum + url.length);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categoryId': categoryId,
      'variants': variants.map((v) => v.toMap()).toList(),
      'lowStockThreshold': lowStockThreshold,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'sku': sku,
      'imageUrls': imageUrls,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map, String docId) {
    var varList = map['variants'] as List? ?? [];
    List<ProductVariant> parsedVariants = [];
    for (var v in varList) {
      try {
        if (v is Map) {
          final vMap = Map<String, dynamic>.from(v);
          parsedVariants.add(ProductVariant(
            name: vMap['name']?.toString() ?? 'Standard',
            quantity: (vMap['quantity'] as num?)?.toInt() ?? 0,
            price: (vMap['price'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      } catch (_) {}
    }

    if (parsedVariants.isEmpty) {
      double p = (map['price'] as num?)?.toDouble() ?? 0.0;
      int q = (map['quantity'] as num?)?.toInt() ?? (map['stockQty'] as num?)?.toInt() ?? 0;
      parsedVariants = [ProductVariant(name: 'Standard', quantity: q, price: p)];
    }

    DateTime parsedDate = DateTime.now();
    try {
      final rawCreated = map['createdAt'];
      if (rawCreated is Timestamp) {
        parsedDate = rawCreated.toDate();
      } else if (rawCreated is String) {
        parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
      }
    } catch (_) {}

    List<String> parsedImageUrls = [];
    if (map['imageUrls'] is List) {
      final rawList = List<String>.from((map['imageUrls'] as List).map((e) => e.toString()));
      for (var rawItem in rawList) {
        final trimmed = rawItem.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.contains('data:image')) {
          final splitItems = trimmed
              .split(RegExp(r'(?=data:image)'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s != ',')
              .toList();

          for (var s in splitItems) {
            final clean = s.endsWith(',') ? s.substring(0, s.length - 1).trim() : s;
            if (clean.isNotEmpty) {
              parsedImageUrls.add(clean);
            }
          }
        } else {
          parsedImageUrls.add(trimmed);
        }
      }
    }

    return InventoryItem(
      id: docId,
      name: map['name']?.toString() ?? 'Product',
      categoryId: map['categoryId']?.toString() ?? 'Tools',
      variants: parsedVariants,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 5,
      status: map['status']?.toString() ?? 'Active',
      createdAt: parsedDate,
      updatedAt: DateTime.now(),
      sku: map['sku']?.toString(),
      imageUrls: parsedImageUrls,
    );
  }
}
