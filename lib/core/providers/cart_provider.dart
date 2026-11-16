import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/inventory_item.dart';
import '../services/local_database_service.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  CartProvider() {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final localItems = await LocalDatabaseService().getLocalCart();
      _items.clear();
      for (var item in localItems) {
        _items[item.id] = item;
      }
      notifyListeners();
    } catch (_) {}
  }

  List<CartItem> get items => _items.values.toList();

  List<CartItem> get selectedItems => _items.values.where((item) {
    return item.isSelected == true;
  }).toList();

  int get itemCount => _items.length;

  int get totalQuantity => _items.values.fold(0, (sum, item) => sum + item.qty);

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      if (cartItem.isSelected == true) {
        total += cartItem.price * cartItem.qty;
      }
    });
    return total;
  }

  Future<void> addItem(
    InventoryItem item, {
    String? variant,
    double? priceOverride,
    int quantity = 1,
    String? deliveryOption,
    String? deliveryAddress,
  }) async {
    final String key = variant != null ? '${item.id}_$variant' : item.id;
    final double finalPrice = priceOverride ?? item.displayPrice;
    final String? imgUrl = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;

    if (_items.containsKey(key)) {
      _items.update(
        key,
        (existing) => existing.copyWith(
          qty: existing.qty + quantity,
          imageUrl: existing.imageUrl ?? imgUrl,
          deliveryOption: deliveryOption ?? existing.deliveryOption,
          deliveryAddress: deliveryAddress ?? existing.deliveryAddress,
        ),
      );
    } else {
      _items.putIfAbsent(
        key,
        () => CartItem(
          id: key,
          productId: item.id,
          name: item.name,
          price: finalPrice,
          qty: quantity,
          variant: variant,
          imageUrl: imgUrl,
          isSelected: true,
          deliveryOption: deliveryOption,
          deliveryAddress: deliveryAddress,
        ),
      );
    }

    try {
      await LocalDatabaseService().saveCartItem(_items[key]!);
    } catch (_) {}

    notifyListeners();
  }

  Future<void> updateQuantity(String cartId, int qty) async {
    if (qty <= 0) {
      _items.remove(cartId);
      try {
        await LocalDatabaseService().removeCartItem(cartId);
      } catch (_) {}
    } else {
      _items.update(
        cartId,
        (existing) => existing.copyWith(qty: qty),
      );
      try {
        await LocalDatabaseService().saveCartItem(_items[cartId]!);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> toggleSelection(String cartId) async {
    if (_items.containsKey(cartId)) {
      _items.update(
        cartId,
        (existing) => existing.copyWith(isSelected: !existing.isSelected),
      );
      try {
        await LocalDatabaseService().saveCartItem(_items[cartId]!);
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _items.clear();
    try {
      await LocalDatabaseService().clearLocalCart();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeSelected() async {
    final removedIds = _items.values.where((v) => v.isSelected == true).map((v) => v.id).toList();
    _items.removeWhere((key, value) {
      return value.isSelected == true;
    });
    try {
      for (var id in removedIds) {
        await LocalDatabaseService().removeCartItem(id);
      }
    } catch (_) {}
    notifyListeners();
  }
}
