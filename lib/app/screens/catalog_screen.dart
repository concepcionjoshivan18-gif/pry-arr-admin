import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/review.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/item_image_helper.dart';
import '../../core/components/skeleton_loader.dart';

const cats = [
  ('All', Icons.apps_rounded),
  ('Tools', Icons.handyman),
  ('Electrical', Icons.electric_bolt),
  ('Building', Icons.foundation),
  ('Plumbing', Icons.plumbing),
  ('Paint', Icons.format_paint),
];

const sorts = ['Featured', 'Price: low to high', 'Price: high to low', 'Top rated', 'Favorites'];

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

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const perPage = 6;
  final search = TextEditingController();
  String cat = 'All';
  int sort = 0, page = 1;
  final favs = <String>{};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      if (user != null && user.favorites.isNotEmpty) {
        setState(() {
          favs.addAll(user.favorites);
        });
      }
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet(BuildContext context, Pal p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(ctx),
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                        Navigator.pop(ctx);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: p.faint.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filter & Sort', style: ts(p.text, 18, FontWeight.w800)),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                cat = 'All';
                                sort = 0;
                                page = 1;
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text('Reset', style: ts(hwOrange, 13, FontWeight.w600)),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: p.faint),
                            onPressed: () => Navigator.pop(ctx),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Category', style: ts(p.text, 14, FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats.map((c) {
                      final isSelected = cat == c.$1;
                      return ChoiceChip(
                        label: Text(c.$1),
                        avatar: Icon(c.$2, size: 16, color: isSelected ? Colors.white : p.sub),
                        selected: isSelected,
                        selectedColor: hwOrange,
                        backgroundColor: p.fill,
                        labelStyle: ts(isSelected ? Colors.white : p.text, 13, FontWeight.w600),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              cat = c.$1;
                              page = 1;
                            });
                            setSheetState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('Sort By', style: ts(p.text, 14, FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(sorts.length, (i) {
                      final isSelected = sort == i;
                      return ChoiceChip(
                        label: Text(sorts[i]),
                        selected: isSelected,
                        selectedColor: hwOrange,
                        backgroundColor: p.fill,
                        labelStyle: ts(isSelected ? Colors.white : p.text, 13, FontWeight.w600),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              sort = i;
                              page = 1;
                            });
                            setSheetState(() {});
                          }
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hwOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('APPLY FILTERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ---- Header with Greeting, Store Name & Logout
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back, ${authService.currentUser?.firstName ?? 'Customer'}', style: ts(p.faint, 13)),
                        const SizedBox(height: 2),
                        Text(
                          'Storefront',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(p.text, 26, FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout, color: p.faint),
                    onPressed: () => authService.signOut(),
                  ),
                ],
              ),
            ),

            // ---- Search Bar (outside stream builders so typing never loses focus, exactly like staff side)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: TextField(
                key: const Key('catalog_search_field'),
                controller: search,
                style: TextStyle(color: p.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search catalog...',
                  hintStyle: TextStyle(color: p.faint, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: p.faint),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (search.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: p.faint),
                          onPressed: () => setState(() {
                            search.clear();
                            page = 1;
                          }),
                        ),
                      IconButton(
                        icon: Icon(Icons.tune_rounded, color: (cat != 'All' || sort != 0) ? hwOrange : p.faint),
                        onPressed: () => _showFilterBottomSheet(context, p),
                        tooltip: 'Filter & Sort',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  filled: true,
                  fillColor: p.fill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: hwOrange, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() => page = 1),
              ),
            ),

            // ---- StreamBuilders for Inventory & Reviews below search bar
            Expanded(
              child: StreamBuilder<List<InventoryItem>>(
                stream: firestoreService.streamInventory(),
                builder: (context, invSnapshot) {
                  if (!invSnapshot.hasData) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: 4,
                      itemBuilder: (_, __) => const SkeletonCard(),
                    );
                  }
                  List<InventoryItem> items = invSnapshot.data ?? [];
                  final activeItems = items.where((i) {
                    final st = i.status.trim().toLowerCase();
                    return st != 'inactive' && st != 'archived';
                  }).toList();

                  return StreamBuilder<List<ReviewModel>>(
                    stream: firestoreService.streamAllReviews(),
                    builder: (context, reviewSnapshot) {
                      final allReviews = reviewSnapshot.data ?? [];

                      // Filter & Sort
                      final q = search.text.toLowerCase();
                      final list = activeItems.where((i) {
                        final matchCat = cat == 'All' || i.categoryId == cat || i.categoryId.toLowerCase() == cat.toLowerCase();
                        final matchSearch = i.name.toLowerCase().contains(q);
                        final matchFav = sort != 4 || favs.contains(i.id);
                        return matchCat && matchSearch && matchFav;
                      }).toList();

                      if (sort == 1) list.sort((a, b) => a.displayPrice.compareTo(b.displayPrice));
                      if (sort == 2) list.sort((a, b) => b.displayPrice.compareTo(a.displayPrice));
                      if (sort == 3) {
                        list.sort((a, b) {
                          final revA = allReviews.where((r) => r.productId == a.id);
                          final avgA = revA.isEmpty ? 0.0 : revA.fold<double>(0, (s, r) => s + r.rating) / revA.length;
                          final revB = allReviews.where((r) => r.productId == b.id);
                          final avgB = revB.isEmpty ? 0.0 : revB.fold<double>(0, (s, r) => s + r.rating) / revB.length;
                          return avgB.compareTo(avgA);
                        });
                      }

                      final totalPages = (list.length / perPage).ceil();
                      if (page > totalPages) page = totalPages == 0 ? 1 : totalPages;
                      final shown = list.skip((page - 1) * perPage).take(perPage).toList();

                      return CustomScrollView(
                        slivers: [
                          // ---- Category Chips
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final sel = cat == cats[i].$1;
                            return GestureDetector(
                              onTap: () => setState(() {
                                cat = cats[i].$1;
                                page = 1;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: sel ? hwOrange : p.fill,
                                  borderRadius: BorderRadius.circular(22),
                                  border: sel ? null : Border.all(color: p.line),
                                  boxShadow: sel ? [BoxShadow(color: hwOrange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5))] : null,
                                ),
                                child: Row(children: [
                                  Icon(cats[i].$2, size: 18, color: sel ? Colors.white : p.sub),
                                  const SizedBox(width: 6),
                                  Text(cats[i].$1, style: ts(sel ? Colors.white : p.text, 13, FontWeight.w700)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // ---- Result count + Sort
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                        child: Row(
                          children: [
                            Text('${list.length} products', style: ts(p.faint, 13)),
                            const Spacer(),
                            PopupMenuButton<int>(
                              initialValue: sort,
                              color: p.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              onSelected: (v) => setState(() {
                                sort = v;
                                page = 1;
                              }),
                              itemBuilder: (_) => [
                                for (int i = 0; i < sorts.length; i++)
                                  PopupMenuItem(value: i, child: Text(sorts[i], style: ts(p.text, 14))),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: p.fill,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: p.line),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.swap_vert_rounded, size: 16, color: p.sub),
                                  const SizedBox(width: 4),
                                  Text(sorts[sort], style: ts(p.text, 12, FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ---- Product Grid
                    if (shown.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(children: [
                            Icon(Icons.search_off_rounded, size: 56, color: p.faint),
                            const SizedBox(height: 8),
                            Text('No products found', style: ts(p.faint, 16)),
                          ]),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          key: ValueKey('$page|$cat|$sort'),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.66,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final item = shown[i];
                              final itemReviews = allReviews.where((r) => r.productId == item.id).toList();
                              double avgRating = 0.0;
                              if (itemReviews.isNotEmpty) {
                                avgRating = itemReviews.fold<double>(0.0, (s, r) => s + r.rating) / itemReviews.length;
                              }

                              return Entrance(
                                index: i,
                                child: ProductCard(
                                  item: item,
                                  avgRating: avgRating,
                                  reviewCount: itemReviews.length,
                                  fav: favs.contains(item.id),
                                  onFav: () async {
                                    setState(() {
                                      favs.contains(item.id) ? favs.remove(item.id) : favs.add(item.id);
                                    });
                                    final user = Provider.of<AuthService>(context, listen: false).currentUser;
                                    if (user != null) {
                                      await firestoreService.updateUserProfile(user.uid, {'favorites': favs.toList()});
                                    }
                                  },
                                  onTap: () => context.push('/customer/product/${item.id}', extra: item),
                                ),
                              );
                            },
                            childCount: shown.length,
                          ),
                        ),
                      ),

                    // ---- Pagination
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                        child: totalPages <= 1
                            ? const SizedBox.shrink()
                            : Column(children: [
                                Text(
                                  'Showing ${(page - 1) * perPage + 1}-${(page - 1) * perPage + shown.length} of ${list.length}',
                                  style: ts(p.faint, 12),
                                ),
                                const SizedBox(height: 10),
                                Pager(page: page, total: totalPages, onChanged: (v) => setState(() => page = v)),
                              ]),
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
    );
  }
}

// ------------------------------------------------------------ product card

class ProductCard extends StatelessWidget {
  final InventoryItem item;
  final double avgRating;
  final int reviewCount;
  final bool fav;
  final VoidCallback onFav, onTap;

  const ProductCard({
    super.key,
    required this.item,
    required this.avgRating,
    required this.reviewCount,
    required this.fav,
    required this.onFav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final selVar = item.variants.isNotEmpty ? item.variants.first : null;
    final stock = selVar?.quantity ?? item.totalQuantity;
    final out = stock == 0;
    final price = selVar?.price ?? item.displayPrice;

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
          onTap: onTap,
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
                          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(9)),
                          child: Text(badge, style: ts(badgeFg, 9.5, FontWeight.w800)),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: onFav,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: p.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: fav ? Colors.red : p.sub,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(p.text, 13.5, FontWeight.w700)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: hwYellow),
                        const SizedBox(width: 4),
                        Text(avgRating > 0 ? avgRating.toStringAsFixed(1) : 'New',
                            style: ts(p.text, 11, FontWeight.w700)),
                        const SizedBox(width: 4),
                        Text('($reviewCount)', style: ts(p.faint, 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(peso(price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(out ? p.faint : p.amber, 14, FontWeight.w800)),
                        ),
                        Text(out ? '0 stock' : '$stock left',
                            style: ts(out ? p.danger : p.faint, 9.5)),
                      ],
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

// ------------------------------------------------------------ pagination helpers

class Pager extends StatelessWidget {
  final int page, total;
  final ValueChanged<int> onChanged;

  const Pager({super.key, required this.page, required this.total, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: p.text,
          disabledColor: p.faint.withValues(alpha: 0.3),
        ),
        for (int i = 1; i <= total; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: page == i ? 28 : 24,
              height: page == i ? 28 : 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: page == i ? hwOrange : p.fill,
                shape: BoxShape.circle,
                border: page == i ? null : Border.all(color: p.line),
              ),
              child: Text('$i', style: ts(page == i ? Colors.white : p.text, 12, FontWeight.w700)),
            ),
          ),
        IconButton(
          onPressed: page < total ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: p.text,
          disabledColor: p.faint.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

class Entrance extends StatefulWidget {
  final Widget child;
  final int index;
  const Entrance({super.key, required this.child, required this.index});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 * (widget.index % 6)), () {
      if (mounted) ctrl.forward();
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - anim.value)),
        child: Opacity(opacity: anim.value, child: child),
      ),
      child: widget.child,
    );
  }
}
