import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/inventory_item.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/item_image_helper.dart';

const freeDeliveryAt = 500.0;
const deliveryFee = 50.0;

Color tintFor(String cat) {
  switch (cat) {
    case 'Electrical':
      return hwYellow;
    case 'Building':
      return hwSteel;
    case 'Plumbing':
      return hwRust;
    case 'Paint':
      return hwOrange;
    default:
      return hwOrange;
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final p = Pal.of(context);
    final items = cartProvider.items;
    final chosen = cartProvider.selectedItems;
    final subtotal = cartProvider.totalAmount;
    final chosenCount = chosen.fold(0, (s, e) => s + e.qty);
    final delivery = chosen.isEmpty || subtotal >= freeDeliveryAt ? 0.0 : deliveryFee;
    final total = subtotal + delivery;
    final allSelected = items.isNotEmpty && items.every((e) => e.isSelected);

    void removeItem(CartItem item) {
      cartProvider.updateQuantity(item.id, 0);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${item.name} removed'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => cartProvider.addItem(
              InventoryItem(
                id: item.productId,
                name: item.name,
                categoryId: 'General',
                variants: [],
                lowStockThreshold: 5,
                status: 'Active',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              variant: item.variant,
              priceOverride: item.price,
              quantity: item.qty,
              deliveryOption: item.deliveryOption,
              deliveryAddress: item.deliveryAddress,
            ),
          ),
        ));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(p, items),
            Expanded(
              child: items.isEmpty
                  ? _empty(p, context)
                  : _list(p, cartProvider, items, allSelected, removeItem),
            ),
            if (items.isNotEmpty) _summary(p, subtotal, chosenCount, delivery, total, chosen.isNotEmpty, context),
          ],
        ),
      ),
    );
  }

  Widget _header(Pal p, List<CartItem> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${items.length} ${items.length == 1 ? 'item' : 'items'}',
                    style: ts(p.faint, 13)),
                const SizedBox(height: 2),
                Text('Shopping Cart', style: ts(p.text, 26, FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(Pal p, CartProvider cp, List<CartItem> items, bool allSelected, Function(CartItem) removeItem) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      children: [
        Row(
          children: [
            Checkbox(
              value: allSelected,
              activeColor: hwOrange,
              side: BorderSide(color: p.faint, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onChanged: (v) {
                for (final item in items) {
                  if (item.isSelected != (v ?? false)) {
                    cp.toggleSelection(item.id);
                  }
                }
              },
            ),
            Text('Select all', style: ts(p.text, 14, FontWeight.w600)),
            const Spacer(),
            Text('Swipe left to remove', style: ts(p.faint, 11)),
          ],
        ),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => removeItem(item),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: p.danger,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
              ),
              child: CartCard(
                item: item,
                cp: cp,
                onDelete: () => removeItem(item),
              ),
            ),
          ),
      ],
    );
  }

  Widget _empty(Pal p, BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: hwOrange.withValues(alpha: 0.14)),
            child: const Icon(Icons.shopping_cart_outlined, size: 54, color: hwOrange),
          ),
          const SizedBox(height: 20),
          Text('Your cart is empty', style: ts(p.text, 20, FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Add some tools and supplies to get started.', style: ts(p.faint, 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.go('/customer/catalog'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
              decoration: BoxDecoration(
                color: hwOrange,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: hwOrange.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Text('Browse products', style: ts(Colors.white, 14, FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(Pal p, double subtotal, int chosenCount, double delivery, double total, bool enabled, BuildContext context) {
    Widget row(String l, String v, {bool big = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l, style: ts(big ? p.text : p.faint, big ? 16 : 13, big ? FontWeight.w800 : FontWeight.w500)),
              Text(v, style: ts(color ?? (big ? p.amber : p.text), big ? 22 : 13, big ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Glass(
        radius: 26,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          children: [

            row('Subtotal ($chosenCount ${chosenCount == 1 ? 'item' : 'items'})', peso(subtotal)),
            row('Delivery', delivery == 0 ? (enabled ? 'Free' : '—') : peso(delivery),
                color: delivery == 0 && enabled ? p.ok : null),
            Divider(color: p.line, height: 18),
            row('Total', peso(total), big: true),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: enabled ? () => context.push('/customer/checkout') : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled ? hwOrange : p.track,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                              color: hwOrange.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 5))
                        ]
                      : null,
                ),
                child: Text(
                  enabled ? 'Checkout' : 'Select items to checkout',
                  style: ts(enabled ? Colors.white : p.faint, 15, FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartCard extends StatelessWidget {
  final CartItem item;
  final CartProvider cp;
  final VoidCallback onDelete;
  const CartCard({super.key, required this.item, required this.cp, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final tint = tintFor('General');

    return Glass(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: item.isSelected,
            activeColor: hwOrange,
            side: BorderSide(color: p.faint, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (v) => cp.toggleSelection(item.id),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: p.dark ? 0.20 : 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: buildItemImage(item.imageUrl, itemName: item.name),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.name}${item.variant != null ? " (${item.variant})" : ""}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(p.text, 15, FontWeight.w700),
                      ),
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6, top: 1),
                        child: Icon(Icons.delete_outline_rounded, size: 20, color: p.faint),
                      ),
                    ),
                  ],
                ),
                Text('${peso(item.price)} each', style: ts(p.faint, 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: p.fill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StepBtn(
                            icon: Icons.remove_rounded,
                            enabled: item.qty > 1,
                            onTap: () => cp.updateQuantity(item.id, item.qty - 1),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text('${item.qty}',
                                textAlign: TextAlign.center,
                                style: ts(p.text, 14, FontWeight.w800)),
                          ),
                          _StepBtn(
                            icon: Icons.add_rounded,
                            enabled: true,
                            onTap: () => cp.updateQuantity(item.id, item.qty + 1),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(peso(item.price * item.qty),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(p.amber, 16, FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 18, color: enabled ? hwOrange : p.faint.withValues(alpha: 0.4)),
      ),
    );
  }
}
