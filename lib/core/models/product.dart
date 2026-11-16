class Product {
  final String id;
  final String name;
  final String sku;
  final double price;
  final int stockQty;
  final String categoryId;
  final List<String> imageUrls;

  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.stockQty,
    required this.categoryId,
    required this.imageUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'price': price,
      'stockQty': stockQty,
      'categoryId': categoryId,
      'imageUrls': imageUrls,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, String docId) {
    return Product(
      id: docId,
      name: map['name'] ?? '',
      sku: map['sku'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      stockQty: map['stockQty'] ?? 0,
      categoryId: map['categoryId'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }
}
