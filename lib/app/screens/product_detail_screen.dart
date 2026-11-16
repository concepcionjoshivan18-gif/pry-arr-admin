import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/cart_item.dart';
import '../../core/models/review.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../routing/storefront_router.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/storefront_animations.dart';
import '../../core/components/swipable_image_slider.dart';
import '../../core/components/top_notification.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final InventoryItem? inventoryItem;

  const ProductDetailScreen({super.key, required this.productId, this.inventoryItem});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductVariant? _selectedVariant;
  int _selectedQty = 1;
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final GlobalKey _addToCartBtnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.inventoryItem?.variants.isNotEmpty ?? false) {
      _selectedVariant = widget.inventoryItem!.variants.first;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _updateQty(int delta) {
    final maxStock = _selectedVariant?.quantity ?? itemStock();
    final newQty = _selectedQty + delta;
    if (newQty >= 1 && newQty <= maxStock) {
      setState(() {
        _selectedQty = newQty;
        _qtyController.text = '$newQty';
        _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: _qtyController.text.length));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    // Use passed item or fallback
    final item = widget.inventoryItem ?? InventoryItem(
      id: widget.productId,
      name: 'Hardware Item',
      categoryId: 'General',
      variants: [],
      lowStockThreshold: 5,
      status: 'Active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final List<ProductVariant> variants = item.variants;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Glass(
                        radius: 22,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: Icon(Icons.arrow_back_rounded, color: p.text, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          style: ts(p.text, 22, FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'product_${item.id}',
                          createRectTween: arcTween,
                          child: SwipableImageSlider(
                            imageUrls: item.imageUrls,
                            itemName: item.name,
                            height: 250,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Reveal(
                          from: 0.3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(item.name, style: ts(p.text, 24, FontWeight.w800))),
                              Text(
                                _selectedVariant != null 
                                  ? '₱${_selectedVariant!.price.toStringAsFixed(2)}' 
                                  : '₱${item.displayPrice.toStringAsFixed(2)}', 
                                style: ts(p.amber, 22, FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Reveal(
                          from: 0.35,
                          child: Text('Category: ${item.categoryId}', style: ts(p.faint, 13)),
                        ),
                        const SizedBox(height: 16),
                        
                        if (variants.length > 1) ...[
                          Reveal(
                            from: 0.4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Select Type / Variant:', style: ts(p.text, 15, FontWeight.w700)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: p.fill,
                                    border: Border.all(color: p.line),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<ProductVariant>(
                                      isExpanded: true,
                                      value: _selectedVariant,
                                      dropdownColor: p.surface,
                                      items: variants.map((v) => DropdownMenuItem<ProductVariant>(
                                        value: v, 
                                        child: Text("${v.name} - ₱${v.price.toStringAsFixed(0)}", style: ts(p.text, 14)),
                                      )).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedVariant = val;
                                          _selectedQty = 1;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else if (variants.length == 1) ...[
                           Reveal(
                             from: 0.4,
                             child: Text('Type: ${variants.first.name}', style: ts(p.sub, 15, FontWeight.w600)),
                           ),
                           const SizedBox(height: 16),
                        ],

                        Divider(color: p.line),
                        const SizedBox(height: 12),
                        
                        Reveal(
                          from: 0.45,
                          child: _buildStockDisplay(p),
                        ),
                        const SizedBox(height: 16),

                        if ((_selectedVariant?.quantity ?? 0) > 0) ...[
                          Reveal(
                            from: 0.5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Select Quantity:', style: ts(p.text, 14, FontWeight.w700)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _qtyBtn(Icons.remove, () => _updateQty(-1), p),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        controller: _qtyController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: ts(p.text, 18, FontWeight.w800),
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          filled: true,
                                          fillColor: p.fill,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.line)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: hwOrange, width: 1.5)),
                                        ),
                                        onChanged: (val) {
                                          final parsed = int.tryParse(val.trim());
                                          final maxStock = _selectedVariant?.quantity ?? itemStock();
                                          if (parsed != null && parsed >= 1) {
                                            if (parsed <= maxStock) {
                                              setState(() => _selectedQty = parsed);
                                            } else {
                                              setState(() {
                                                _selectedQty = maxStock;
                                                _qtyController.text = '$maxStock';
                                                _qtyController.selection = TextSelection.fromPosition(TextPosition(offset: _qtyController.text.length));
                                              });
                                              showTopNotification(context, 'Maximum available stock is $maxStock units', isError: true);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _qtyBtn(Icons.add, () => _updateQty(1), p),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),
                        Reveal(
                          from: 0.6,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  key: _addToCartBtnKey,
                                  onPressed: (_selectedVariant?.quantity ?? 0) > 0 ? () {
                                    cartProvider.addItem(
                                      item, 
                                      variant: _selectedVariant?.name, 
                                      priceOverride: _selectedVariant?.price, 
                                      quantity: _selectedQty,
                                    );
                                    CustomerScaffold.of(context)?.triggerFlyToCart(_addToCartBtnKey, Icons.handyman);
                                    showTopNotification(
                                      context,
                                      '$_selectedQty x ${item.name} added to cart!',
                                      isSuccess: true,
                                      icon: Icons.shopping_bag_outlined,
                                    );
                                  } : null,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 54), 
                                    backgroundColor: hwOrange, 
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('ADD TO CART', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (_selectedVariant?.quantity ?? 0) > 0 ? () {
                                    final buyNowItem = CartItem(
                                      id: '${item.id}_${_selectedVariant?.name ?? "default"}',
                                      productId: item.id,
                                      name: item.name,
                                      price: _selectedVariant?.price ?? item.displayPrice,
                                      qty: _selectedQty,
                                      variant: _selectedVariant?.name,
                                      imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
                                      isSelected: true,
                                    );
                                    context.push('/customer/checkout', extra: [buyNowItem]);
                                  } : null,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(0, 54), 
                                    backgroundColor: const Color(0xFF2E7D32), 
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('BUY NOW', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                        Divider(thickness: 1.5, color: p.line),
                        const SizedBox(height: 16),

                        // --- REVIEWS & FEEDBACK DISPLAY AREA ---
                        _buildReviewsSection(firestoreService, item.id, p),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockDisplay(Pal p) {
    final stock = _selectedVariant?.quantity ?? itemStock();
    final isLow = stock <= 5 && stock > 0;
    final out = stock == 0;

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: out ? p.danger : (isLow ? hwOrange : p.ok),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          out ? 'Out of stock' : '$stock units currently in stock',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: out ? p.danger : (isLow ? hwOrange : p.ok),
          ),
        ),
      ],
    );
  }

  int itemStock() {
    if (widget.inventoryItem == null) return 10;
    return widget.inventoryItem!.totalQuantity;
  }

  Widget _qtyBtn(IconData icon, VoidCallback onPressed, Pal p) {
    return Container(
      decoration: BoxDecoration(
        color: p.fill,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: p.text),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildReviewsSection(FirestoreService firestoreService, String productId, Pal p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Ratings & Verified Feedback',
                style: ts(p.text, 18, FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.rate_review_outlined, color: hwOrange),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<ReviewModel>>(
          stream: firestoreService.streamAllReviews(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allReviews = snapshot.data ?? [];
            final reviews = allReviews.where((r) => r.productId == productId).toList();
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.fill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: Text('No reviews yet. Be the first to review!', style: ts(p.faint, 13)),
              );
            }

            double avgRating = reviews.fold<double>(0.0, (sum, r) => sum + r.rating) / reviews.length;

            return Column(
              children: [
                Row(
                  children: [
                    Text(avgRating.toStringAsFixed(1), style: ts(p.text, 36, FontWeight.bold)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (index) => Icon(
                            index < avgRating.round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          )),
                        ),
                        const SizedBox(height: 2),
                        Text('Based on ${reviews.length} verified reviews', style: ts(p.faint, 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...reviews.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r.userName, style: ts(p.text, 14, FontWeight.bold)),
                          Text(DateFormat('MMM dd, yyyy').format(r.createdAt), style: ts(p.faint, 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (index) => Icon(
                          index < r.rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        )),
                      ),
                      const SizedBox(height: 6),
                      Text(r.comment, style: ts(p.text, 13)),
                    ],
                  ),
                )),
              ],
            );
          },
        ),
      ],
    );
  }
}
