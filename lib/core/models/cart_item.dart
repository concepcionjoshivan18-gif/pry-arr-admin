class CartItem {
  final String id; // Unique key in cart (productId + variant)
  final String productId;
  final String name;
  final double price;
  final int qty;
  final String? variant;
  final String? imageUrl;
  final bool isSelected;
  final String? deliveryOption;
  final String? deliveryAddress;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.variant,
    this.imageUrl,
    bool? isSelected,
    this.deliveryOption,
    this.deliveryAddress,
  }) : isSelected = isSelected ?? true;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'price': price,
      'qty': qty,
      'variant': variant,
      'imageUrl': imageUrl,
      'isSelected': isSelected,
      'deliveryOption': deliveryOption,
      'deliveryAddress': deliveryAddress,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      qty: map['qty'] ?? 0,
      variant: map['variant'],
      imageUrl: map['imageUrl'],
      isSelected: map['isSelected'] == true,
      deliveryOption: map['deliveryOption'],
      deliveryAddress: map['deliveryAddress'],
    );
  }

  CartItem copyWith({
    bool? isSelected,
    int? qty,
    String? imageUrl,
    String? deliveryOption,
    String? deliveryAddress,
  }) {
    return CartItem(
      id: id,
      productId: productId,
      name: name,
      price: price,
      qty: qty ?? this.qty,
      variant: variant,
      imageUrl: imageUrl ?? this.imageUrl,
      isSelected: isSelected ?? this.isSelected,
      deliveryOption: deliveryOption ?? this.deliveryOption,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }
}
