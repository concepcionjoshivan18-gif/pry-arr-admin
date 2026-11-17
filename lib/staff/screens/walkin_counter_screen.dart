import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/order.dart';
import '../../core/models/category.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/item_image_helper.dart';
import '../../core/components/top_notification.dart';
import '../../app/screens/digital_receipt_screen.dart';

const discounts = [('None', 0.0), ('5%', 0.05), ('10%', 0.10), ('Senior/PWD 20%', 0.20)];

Color tintFor(String cat) {
  switch (cat) {
    case 'Electrical':
      return hwYellow;
    case 'Building':
      return hwSteel;
    case 'Plumbing':
      return hwRust;
    default:
      return hwOrange;
  }
}

class WalkInBasket extends ChangeNotifier {
  final Map<String, (InventoryItem, ProductVariant?, int)> items = {};
  int discountIndex = 0;

  int get count => items.values.fold(0, (a, b) => a + b.$3);
  double get subtotal => items.values.fold(0.0, (s, e) => s + (e.$2?.price ?? e.$1.displayPrice) * e.$3);
  double get discount => subtotal * discounts[discountIndex].$2;
  double get total => subtotal - discount;

  int qtyOf(String itemKey) => items[itemKey]?.$3 ?? 0;

  void add(InventoryItem item, ProductVariant? variant) {
    final selVar = variant ?? (item.variants.isNotEmpty ? item.variants.first : null);
    final varName = selVar?.name ?? 'Standard';
    final key = '${item.id}_$varName';
    final maxStock = selVar?.quantity ?? item.totalQuantity;
    final cur = qtyOf(key);

    if (cur < maxStock) {
      items[key] = (item, selVar, cur + 1);
      notifyListeners();
    }
  }

  void remove(String itemKey) {
    if (!items.containsKey(itemKey)) return;
    final cur = items[itemKey]!.$3;
    if (cur <= 1) {
      items.remove(itemKey);
    } else {
      items[itemKey] = (items[itemKey]!.$1, items[itemKey]!.$2, cur - 1);
    }
    notifyListeners();
  }

  void setDiscount(int i) {
    discountIndex = i;
    notifyListeners();
  }

  void clear() {
    items.clear();
    discountIndex = 0;
    notifyListeners();
  }

  List<CartItem> toCartItems() {
    return items.entries.map((e) {
      final item = e.value.$1;
      final v = e.value.$2;
      final q = e.value.$3;
      final varName = v?.name ?? 'Standard';
      final price = v?.price ?? item.displayPrice;
      return CartItem(
        id: e.key,
        productId: item.id,
        name: item.name,
        price: price,
        qty: q,
        variant: varName,
      );
    }).toList();
  }
}

class WalkInCounterScreen extends StatefulWidget {
  const WalkInCounterScreen({super.key});

  @override
  State<WalkInCounterScreen> createState() => _WalkInCounterScreenState();
}

class _WalkInCounterScreenState extends State<WalkInCounterScreen> {
  final basket = WalkInBasket();
  final search = TextEditingController();
  String cat = 'All';

  @override
  void dispose() {
    search.dispose();
    basket.dispose();
    super.dispose();
  }

  void openSheet(int stage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutSheet(
        basket: basket,
        startStage: stage,
        onPaid: (msg, items, total) async {
          final firestoreService = Provider.of<FirestoreService>(context, listen: false);
          final authService = Provider.of<AuthService>(context, listen: false);
          final staffUser = authService.currentUser;

          if (staffUser != null) {
            try {
              final orderRefId = 'walkin_${DateTime.now().millisecondsSinceEpoch}';
              final order = OrderModel(
                id: orderRefId,
                customerId: 'walkin_customer',
                items: items,
                status: 'pending',
                total: total,
                createdAt: DateTime.now(),
              );
              await firestoreService.finalizeOrder(order, staffUser);
            } catch (e) {
              debugPrint('Finalize walkin order error: $e');
            }
          }

          basket.clear();
          if (mounted) {
            showTopNotification(context, msg, isSuccess: true);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DigitalReceiptScreen(
                  items: items,
                  total: total,
                  pointsEarned: 0,
                  discount: basket.discount,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('POS'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmAndSignOut(context, authService),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // ---- Search bar (outside stream builders so typing never loses focus)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    child: TextField(
                      controller: search,
                      style: ts(p.text, 15),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search walk-in items...',
                        hintStyle: ts(p.faint, 15),
                        prefixIcon: Icon(Icons.search_rounded, color: p.faint),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close_rounded, color: p.faint),
                                onPressed: () => setState(search.clear)),
                        filled: true,
                        fillColor: p.fill,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: p.line)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: p.line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(color: hwOrange, width: 1.5)),
                      ),
                    ),
                  ),
                  // ---- Categories & Inventory Streams below
                  Expanded(
                    child: StreamBuilder<List<CategoryModel>>(
                      stream: firestoreService.streamCategories(),
                      builder: (context, catSnapshot) {
                        final categoryNames = ['All', ...(catSnapshot.data?.map((c) => c.name) ?? [])];

                        return StreamBuilder<List<InventoryItem>>(
                          stream: firestoreService.streamInventory(),
                          builder: (context, invSnapshot) {
                            if (invSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final items = invSnapshot.data ?? [];
                            final activeItems = items.where((i) => i.status == 'Active').toList();

                            final q = search.text.toLowerCase();
                            final list = activeItems.where((x) {
                              final matchCat = cat == 'All' || x.categoryId == cat;
                              final matchSearch = x.name.toLowerCase().contains(q);
                              return matchCat && matchSearch;
                            }).toList();

                            return Column(
                              children: [
                                // ---- category chips
                                SizedBox(
                                  height: 42,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    itemCount: categoryNames.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (_, i) {
                                      final sel = cat == categoryNames[i];
                                      return GestureDetector(
                                        onTap: () => setState(() => cat = categoryNames[i]),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(
                                            color: sel ? hwOrange : p.fill,
                                            borderRadius: BorderRadius.circular(21),
                                            border: sel ? null : Border.all(color: p.line),
                                          ),
                                          child: Row(children: [
                                            Icon(Icons.apps_rounded, size: 17, color: sel ? Colors.white : p.sub),
                                            const SizedBox(width: 6),
                                            Text(categoryNames[i], style: ts(sel ? Colors.white : p.text, 13, FontWeight.w700)),
                                          ]),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // ---- product grid
                                Expanded(
                                  child: list.isEmpty
                                      ? Center(child: Text('No active inventory items found', style: ts(p.faint, 16)))
                                      : AnimatedBuilder(
                                          animation: basket,
                                          builder: (_, __) => GridView.builder(
                                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 200,
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 0.74,
                                            ),
                                            itemCount: list.length,
                                            itemBuilder: (_, i) {
                                              final item = list[i];
                                              final selVar = item.variants.isNotEmpty ? item.variants.first : null;
                                              final varName = selVar?.name ?? 'Standard';
                                              final key = '${item.id}_$varName';
                                              final qty = basket.qtyOf(key);
                                              final stock = selVar?.quantity ?? item.totalQuantity;

                                              return PosTile(
                                                item: item,
                                                variantName: varName,
                                                price: selVar?.price ?? item.displayPrice,
                                                stock: stock,
                                                qty: qty,
                                                onAdd: () => basket.add(item, selVar),
                                                onRemove: () => basket.remove(key),
                                              );
                                            },
                                          ),
                                        ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 4,
            child: basketBar(p),
          ),
        ],
      ),
    );
  }

  Widget basketBar(Pal p) {
    return AnimatedBuilder(
      animation: basket,
      builder: (_, __) {
        final empty = basket.count == 0;
        return Glass(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => openSheet(0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: hwOrange.withValues(alpha: 0.16), shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_basket_rounded, color: hwOrange),
                    ),
                    if (!empty)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hwRust,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: p.surface, width: 1.5),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                            child: Text('${basket.count}',
                                key: ValueKey(basket.count),
                                style: ts(Colors.white, 10, FontWeight.w800)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openSheet(0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(empty ? 'Basket is empty' : 'View basket', style: ts(p.faint, 11)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: basket.total),
                        duration: const Duration(milliseconds: 400),
                        builder: (_, v, __) => Text(peso(v),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ts(p.text, 21, FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: empty ? null : () => openSheet(1),
                  style: FilledButton.styleFrom(
                    backgroundColor: hwOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: p.line,
                    disabledForegroundColor: p.faint,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ product tile

class PosTile extends StatelessWidget {
  final InventoryItem item;
  final String variantName;
  final double price;
  final int stock;
  final int qty;
  final VoidCallback onAdd, onRemove;

  const PosTile({
    super.key,
    required this.item,
    required this.variantName,
    required this.price,
    required this.stock,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final out = stock == 0;
    final maxed = qty >= stock;

    String? badge;
    Color badgeBg = p.danger, badgeFg = Colors.white;
    if (out) {
      badge = 'Sold out';
    } else if (stock <= 5) {
      badge = 'Only $stock left';
      badgeBg = hwYellow;
      badgeFg = hwCharcoal;
    }

    return Glass(
      radius: 20,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: out || maxed ? null : onAdd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: out ? 0.45 : 1,
                            child: buildItemImage(
                              item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
                              itemName: item.name,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 13,
                        left: 13,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: badgeBg, borderRadius: BorderRadius.circular(9)),
                          child: Text(badge, style: ts(badgeFg, 9.5, FontWeight.w800)),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: qty > 0
                            ? Container(
                                key: ValueKey(qty),
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: hwOrange,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: hwOrange.withValues(alpha: 0.5), blurRadius: 8)
                                  ],
                                ),
                                child: Text('$qty', style: ts(Colors.white, 13, FontWeight.w800)),
                              )
                            : const SizedBox.shrink(key: ValueKey(0)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(p.text, 14, FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(peso(price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(out ? p.faint : p.amber, 15, FontWeight.w800)),
                        ),
                        Text(out ? '0 stock' : '$stock left',
                            style: ts(out ? p.danger : p.faint, 10)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: qty > 0
                            ? Container(
                                key: const ValueKey('stepper'),
                                decoration: BoxDecoration(
                                  color: p.fill,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(color: p.line),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    StepBtn(Icons.remove_rounded, onRemove, color: p.danger),
                                    Text('$qty', style: ts(p.text, 15, FontWeight.w800)),
                                    StepBtn(Icons.add_rounded, maxed ? null : onAdd, color: p.ok),
                                  ],
                                ),
                              )
                            : Center(
                                key: const ValueKey('hint'),
                                child: Text(out ? 'Unavailable' : 'Tap to add',
                                    style: ts(out ? p.danger : p.faint, 11, FontWeight.w600)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  const StepBtn(this.icon, this.onTap, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 34,
        child: Icon(icon, size: 20, color: onTap == null ? p.faint.withValues(alpha: 0.4) : color),
      ),
    );
  }
}

// ------------------------------------------------------------ checkout sheet

class CheckoutSheet extends StatefulWidget {
  final WalkInBasket basket;
  final int startStage;
  final void Function(String msg, List<CartItem> items, double total) onPaid;

  const CheckoutSheet({
    super.key,
    required this.basket,
    required this.startStage,
    required this.onPaid,
  });

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  late int stage = widget.startStage;
  int method = 0; // 0 cash, 1 gcash, 2 card
  final tendered = TextEditingController();
  static const methods = [
    ('Cash', Icons.payments_rounded),
    ('GCash', Icons.account_balance_wallet_rounded),
    ('Card', Icons.credit_card_rounded),
  ];

  WalkInBasket get b => widget.basket;

  @override
  void dispose() {
    tendered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: p.surface.withValues(alpha: 0.95),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    child: AnimatedBuilder(
                      animation: b,
                      builder: (_, __) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: stage == 0 ? review(p) : payment(p),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget summaryRow(Pal p, String l, String v, {Color? color, bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: ts(p.sub, big ? 16 : 14, big ? FontWeight.w800 : FontWeight.w500)),
            Text(v, style: ts(color ?? p.text, big ? 22 : 14, big ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      );

  Widget review(Pal p) {
    final lines = b.items.entries.toList();
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Walk-In Basket', style: ts(p.text, 22, FontWeight.w800)),
          const Spacer(),
          if (lines.isNotEmpty)
            TextButton(
              onPressed: b.clear,
              child: Text('Clear all', style: ts(p.danger, 13, FontWeight.w700)),
            ),
        ]),
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Nothing here yet. Tap items to add.', style: ts(p.faint, 14))),
          )
        else ...[
          for (final e in lines) ...[
            Builder(builder: (_) {
              final item = e.value.$1;
              final v = e.value.$2;
              final qty = e.value.$3;
              final price = v?.price ?? item.displayPrice;
              final maxStock = v?.quantity ?? item.totalQuantity;
              final tint = tintFor(item.categoryId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: buildItemImage(
                          item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
                          itemName: item.name,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(p.text, 14, FontWeight.w700)),
                          Text('${peso(price)} each • ${v?.name ?? "Standard"}', style: ts(p.faint, 11)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: p.fill,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: p.line),
                      ),
                      child: Row(children: [
                        StepBtn(Icons.remove_rounded, () => b.remove(e.key), color: p.danger),
                        Text('$qty', style: ts(p.text, 15, FontWeight.w800)),
                        StepBtn(Icons.add_rounded, qty >= maxStock ? null : () => b.add(item, v),
                            color: p.ok),
                      ]),
                    ),
                    SizedBox(
                      width: 74,
                      child: Text(peso(price * qty),
                          textAlign: TextAlign.right, style: ts(p.text, 14, FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }),
            Divider(height: 1, color: p.line),
          ],
          const SizedBox(height: 16),
          Text('Discount', style: ts(p.sub, 13, FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < discounts.length; i++)
                GestureDetector(
                  onTap: () => b.setDiscount(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: b.discountIndex == i ? hwOrange : p.fill,
                      borderRadius: BorderRadius.circular(18),
                      border: b.discountIndex == i ? null : Border.all(color: p.line),
                    ),
                    child: Text(discounts[i].$1,
                        style: ts(b.discountIndex == i ? Colors.white : p.text, 12, FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          summaryRow(p, 'Subtotal', peso(b.subtotal)),
          if (b.discount > 0) summaryRow(p, 'Discount', '-${peso(b.discount)}', color: p.danger),
          Divider(color: p.line),
          summaryRow(p, 'Total', peso(b.total), color: p.amber, big: true),
          const SizedBox(height: 16),
          bigButton(p, 'Continue to payment', () => setState(() => stage = 1)),
        ],
      ],
    );
  }

  Widget payment(Pal p) {
    final due = b.total;
    final tend = double.tryParse(tendered.text) ?? 0;
    final change = tend - due;
    final cash = method == 0;
    final valid = b.count > 0 && (!cash || tend >= due - 0.001);

    void setTend(double v) {
      tendered.text = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
      tendered.selection = TextSelection.collapsed(offset: tendered.text.length);
      setState(() {});
    }

    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() => stage = 0),
            icon: Icon(Icons.arrow_back_rounded, color: p.text),
          ),
          Text('Payment', style: ts(p.text, 22, FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hwOrange.withValues(alpha: p.dark ? 0.16 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hwOrange.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total due', style: ts(p.sub, 15, FontWeight.w600)),
              Text(peso(due), style: ts(p.amber, 28, FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (int i = 0; i < methods.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => method = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: method == i ? hwOrange : p.fill,
                      borderRadius: BorderRadius.circular(16),
                      border: method == i ? null : Border.all(color: p.line),
                    ),
                    child: Column(children: [
                      Icon(methods[i].$2, color: method == i ? Colors.white : p.sub),
                      const SizedBox(height: 4),
                      Text(methods[i].$1,
                          style: ts(method == i ? Colors.white : p.text, 12, FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (cash) ...[
          const SizedBox(height: 16),
          TextField(
            controller: tendered,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: ts(p.text, 20, FontWeight.w800),
            decoration: InputDecoration(
              labelText: 'Amount received',
              labelStyle: ts(p.faint, 14),
              prefixText: '₱ ',
              prefixStyle: ts(p.text, 20, FontWeight.w800),
              filled: true,
              fillColor: p.fill,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: hwOrange, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              quick(p, 'Exact', () => setTend(due)),
              for (final v in [100, 200, 500, 1000]) quick(p, '₱$v', () => setTend(v.toDouble())),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (tend == 0 ? p.track : (change >= 0 ? p.ok : p.danger).withValues(alpha: 0.14)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tend == 0 ? 'Change' : (change >= 0 ? 'Change due' : 'Still needed'),
                    style: ts(p.sub, 14, FontWeight.w600)),
                Text(tend == 0 ? '—' : peso(change.abs()),
                    style: ts(tend == 0 ? p.faint : (change >= 0 ? p.ok : p.danger), 22, FontWeight.w900)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        bigButton(p, 'Confirm payment', valid ? () {
          final msg = cash
              ? 'Sale complete • Change ${peso(change)}'
              : 'Sale complete • Paid via ${methods[method].$1}';
          final cartItems = b.toCartItems();
          final totalAmt = b.total;
          Navigator.pop(context);
          widget.onPaid(msg, cartItems, totalAmt);
        } : null),
      ],
    );
  }

  Widget quick(Pal p, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: p.fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Text(label, style: ts(p.text, 13, FontWeight.w700)),
        ),
      );

  Widget bigButton(Pal p, String label, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: hwOrange,
            foregroundColor: Colors.white,
            disabledBackgroundColor: p.line,
            disabledForegroundColor: p.faint,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      );
}
