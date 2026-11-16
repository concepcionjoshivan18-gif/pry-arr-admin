import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/models/category.dart';
import 'package:go_router/go_router.dart';
import '../components/app_back_button.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/components/top_notification.dart';
import '../../core/components/pagination_controls.dart';
import '../../core/components/skeleton_loader.dart';
import '../../core/components/profile_picture_picker.dart';
import '../components/admin_scaffold.dart';
import 'package:flutter/services.dart';

Widget _hwGlass({
  required Widget child,
  double radius = 24,
  EdgeInsetsGeometry? padding,
}) {
  return Builder(
    builder: (context) {
      final p = Pal.of(context);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: p.glassFill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: p.glassBorder, width: 1.2),
              boxShadow: [
                BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

Widget _hwBackground() => const SizedBox.shrink();

InputDecoration _hwInputDecoration(BuildContext context, String label, {String? hint}) {
  final p = Pal.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: p.faint, fontSize: 13),
    hintStyle: TextStyle(color: p.faint.withValues(alpha: 0.5), fontSize: 13),
    filled: true,
    fillColor: p.fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: hwOrange, width: 1.6),
    ),
  );
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  bool _isLoading = true;
  int _currentPage = 1;
  static const int _itemsPerPage = 8;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final theme = Theme.of(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        _hwBackground(),
        Column(
          children: [
            // Header title and action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: hwOrange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Inventory Catalog',
                      style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 20),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/admin/categories'),
                    icon: const Icon(Icons.category_rounded, size: 18, color: hwYellow),
                    label: const Text('CATEGORIES', style: TextStyle(color: hwYellow, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showItemDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('ADD NEW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hwOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _hwGlass(
                        radius: 16,
                        child: Material(
                          color: Colors.transparent,
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(color: p.text),
                          decoration: InputDecoration(
                            hintText: 'Search hardware database...',
                            hintStyle: TextStyle(color: p.faint),
                            prefixIcon: Icon(Icons.search_rounded, color: p.faint),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear, color: p.faint),
                              onPressed: () => setState(() => _searchCtrl.clear()),
                            )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (val) {
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                    const SizedBox(width: 24),
                    StreamBuilder<List<CategoryModel>>(
                      stream: firestoreService.streamCategories(),
                      builder: (context, snapshot) {
                        final categories = ['All', ...(snapshot.data?.map((c) => c.name) ?? [])];
                        return _hwGlass(
                          radius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            underline: const SizedBox(),
                            value: _selectedCategory,
                            dropdownColor: p.surface,
                            iconEnabledColor: p.faint,
                            style: TextStyle(fontWeight: FontWeight.w600, color: p.text),
                            items: categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val ?? 'All';
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<InventoryItem>>(
                  stream: firestoreService.streamInventory(),
                  builder: (context, snapshot) {
                    if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: 4,
                        itemBuilder: (_, __) => const SkeletonCard(),
                      );
                    }
                    final items = snapshot.data ?? [];
                    final filteredItems = items.where((item) {
                      final matchesSearch = _searchCtrl.text.trim().isEmpty || item.name.toLowerCase().contains(_searchCtrl.text.trim().toLowerCase());
                      final matchesCategory = _selectedCategory == 'All' || item.categoryId.trim().toLowerCase() == _selectedCategory.trim().toLowerCase();
                      return matchesSearch && matchesCategory;
                    }).toList();

                    final totalPages = (filteredItems.length / _itemsPerPage).ceil();
                    if (_currentPage > totalPages) {
                      _currentPage = totalPages > 0 ? totalPages : 1;
                    }
                    final startIndex = (_currentPage - 1) * _itemsPerPage;
                    final paginatedItems = filteredItems.skip(startIndex).take(_itemsPerPage).toList();

                    debugPrint('Inventory items count: ${items.length}, filtered: ${filteredItems.length}');

                    return Container(
                      margin: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: _hwGlass(
                        radius: 28,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  child: Theme(
                                    data: theme.copyWith(
                                      dividerColor: p.line,
                                      dataTableTheme: DataTableThemeData(
                                        dataTextStyle: TextStyle(color: p.text),
                                      ),
                                    ),
                                    child: DataTable(
                                      horizontalMargin: 32,
                                      headingRowColor: WidgetStateProperty.all(p.fill),
                                      headingTextStyle: TextStyle(fontWeight: FontWeight.w800, color: p.faint, fontSize: 12),
                                      columns: const [
                                        DataColumn(label: Text('PRODUCT NAME')),
                                        DataColumn(label: Text('CATEGORY')),
                                        DataColumn(label: Text('TOTAL STOCK')),
                                        DataColumn(label: Text('VARIANTS')),
                                        DataColumn(label: Text('PRICE RANGE')),
                                        DataColumn(label: Text('STATUS')),
                                        DataColumn(label: Text('ACTIONS')),
                                      ],
                                      rows: paginatedItems.map((item) {
                                        final isLowStock = item.totalQuantity <= item.lowStockThreshold;

                                        final prices = item.variants.map((v) => v.price).toList();
                                        String priceRange = "-";
                                        if (prices.isNotEmpty) {
                                          final min = prices.reduce((a, b) => a < b ? a : b);
                                          final max = prices.reduce((a, b) => a > b ? a : b);
                                          priceRange = min == max ? "₱${min.toStringAsFixed(0)}" : "₱${min.toStringAsFixed(0)} - ₱${max.toStringAsFixed(0)}";
                                        }

                                        return DataRow(cells: [
                                          DataCell(Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.text))),
                                          DataCell(Text(item.categoryId, style: TextStyle(color: p.sub))),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isLowStock ? Colors.redAccent.withValues(alpha: 0.18) : Colors.greenAccent.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${item.totalQuantity}',
                                                style: TextStyle(
                                                  color: isLowStock ? Colors.redAccent : Colors.greenAccent,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(Text('${item.variants.length} types', style: TextStyle(color: p.sub))),
                                          DataCell(Text(priceRange, style: TextStyle(fontWeight: FontWeight.bold, color: p.amber))),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: item.status == 'Active' ? hwOrange.withValues(alpha: 0.18) : p.fill,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: item.status == 'Active' ? hwOrange : p.faint,
                                              ),
                                            ),
                                          )),
                                          DataCell(Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_rounded, size: 20),
                                                color: p.amber,
                                                onPressed: () => _showItemDialog(context, item: item),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                                color: p.danger,
                                                onPressed: () => _confirmDeleteInventoryItem(context, firestoreService, item),
                                              ),
                                            ],
                                          )),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              if (totalPages > 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: PaginationControls(
                                    currentPage: _currentPage,
                                    totalPages: totalPages,
                                    onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteInventoryItem(BuildContext context, FirestoreService service, InventoryItem item) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final p = Pal.of(context);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(width: 8),
              Text('Confirm Delete', style: TextStyle(color: p.text, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${item.name}" from inventory? This action cannot be undone.',
            style: TextStyle(color: p.sub, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: TextStyle(color: p.faint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                try {
                  await service.deleteInventoryItem(item.id);
                  if (context.mounted) {
                    showTopNotification(
                      context,
                      'Item "${item.name}" deleted successfully.',
                      isSuccess: true,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTopNotification(
                      context,
                      'Delete failed: $e',
                      isError: true,
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showItemDialog(BuildContext context, {InventoryItem? item}) {
    showDialog(
      context: context,
      builder: (ctx) => _ItemEditDialog(item: item),
    );
  }
}

class _ItemEditDialog extends StatefulWidget {
  final InventoryItem? item;
  const _ItemEditDialog({this.item});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _VariantEntry {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _VariantEntry({String? name, int? qty, double? price})
      : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty?.toString() ?? '0'),
        priceCtrl = TextEditingController(text: price?.toString() ?? '0.0');

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _lowStockCtrl;
  List<String> _imageUrls = [];
  final List<_VariantEntry> _variants = [];
  String? _selectedCategory;
  String _status = 'Active';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name);
    _lowStockCtrl = TextEditingController(text: widget.item?.lowStockThreshold.toString() ?? '5');
    _imageUrls = List<String>.from(widget.item?.imageUrls ?? []);
    _selectedCategory = widget.item?.categoryId;
    _status = widget.item?.status ?? 'Active';

    if (widget.item?.variants.isNotEmpty ?? false) {
      for (var v in widget.item!.variants) {
        _variants.add(_VariantEntry(name: v.name, qty: v.quantity, price: v.price));
      }
    } else {
      _variants.add(_VariantEntry());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lowStockCtrl.dispose();
    for (var v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      _variants.add(_VariantEntry());
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _variants[index].dispose();
      _variants.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final p = Pal.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: (Breakpoints.width(context) * 0.92).clamp(280.0, 640.0),
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: p.glassBorder, width: 1.2),
            boxShadow: [BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.item == null ? Icons.add_box_rounded : Icons.edit_rounded, color: hwOrange, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    widget.item == null ? 'Add Inventory Item' : 'Edit Item',
                    style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          style: TextStyle(color: p.text),
                          decoration: _hwInputDecoration(context, 'Item Name'),
                          inputFormatters: [LengthLimitingTextInputFormatter(50)],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (v.trim().length < 3) return 'Min 3 characters';
                            if (v.trim().length > 50) return 'Max 50 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<CategoryModel>>(
                          stream: firestoreService.streamCategories(),
                          builder: (context, snapshot) {
                            final rawCats = snapshot.data ?? [];
                            final uniqueCats = <String, CategoryModel>{};
                            for (var c in rawCats) {
                              uniqueCats[c.name.trim().toLowerCase()] = c;
                            }
                            final cats = uniqueCats.values.toList();

                            if (_selectedCategory != null && !cats.any((c) => c.name.trim().toLowerCase() == _selectedCategory!.trim().toLowerCase())) {
                              if (cats.isNotEmpty) {
                                _selectedCategory = cats.first.name;
                              }
                            }

                            return DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              dropdownColor: p.surface,
                              style: TextStyle(color: p.text),
                              hint: Text('Select Category', style: TextStyle(color: p.faint)),
                              decoration: _hwInputDecoration(context, 'Category'),
                              items: cats.map((c) => DropdownMenuItem<String>(value: c.name, child: Text(c.name))).toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v),
                              validator: (v) => v == null ? 'Required' : null,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _ProductMultiImagePicker(
                          initialUrls: _imageUrls,
                          onImagesChanged: (urls) {
                            setState(() {
                              _imageUrls = urls;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 24),
                        Text('Types, Stock & Pricing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: p.text)),
                        Divider(color: p.line),
                        const SizedBox(height: 8),
                        ...List.generate(_variants.length, (index) {
                          final v = _variants[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: v.nameCtrl,
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'Type Name', hint: 'e.g. 1/4 inch'),
                                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      if (val.trim().length < 3) return 'Min 3 chars';
                                      if (val.trim().length > 50) return 'Max 50 chars';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: v.qtyCtrl,
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'Qty'),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(7),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      if (val.trim().length < 2) return 'Min 2 digits';
                                      if (val.trim().length > 7) return 'Max 7 digits';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: v.priceCtrl,
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'Price'),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(7),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      if (val.trim().length < 2) return 'Min 2 digits';
                                      if (val.trim().length > 7) return 'Max 7 digits';
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline, color: p.danger),
                                  onPressed: _variants.length > 1 ? () => _removeVariant(index) : null,
                                ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: _addVariant,
                          icon: const Icon(Icons.add_circle_outline, color: hwYellow),
                          label: const Text('ADD ANOTHER TYPE', style: TextStyle(color: hwYellow, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _lowStockCtrl,
                                style: TextStyle(color: p.text),
                                decoration: _hwInputDecoration(context, 'Low Stock Alert Level'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                dropdownColor: p.surface,
                                style: TextStyle(color: p.text),
                                decoration: _hwInputDecoration(context, 'System Status'),
                                items: ['Active', 'Inactive'].map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _status = v;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: p.faint)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        if (_selectedCategory == null) {
                          showTopError(context, 'Please select a category');
                          return;
                        }
                        try {
                          final List<ProductVariant> finalVariants = _variants.map((v) => ProductVariant(
                            name: v.nameCtrl.text.isEmpty ? "Standard" : v.nameCtrl.text,
                            quantity: int.tryParse(v.qtyCtrl.text) ?? 0,
                            price: double.tryParse(v.priceCtrl.text) ?? 0.0,
                          )).toList();

                          final newItem = InventoryItem(
                            id: widget.item?.id ?? '',
                            name: _nameCtrl.text.trim(),
                            categoryId: _selectedCategory!,
                            variants: finalVariants,
                            lowStockThreshold: int.tryParse(_lowStockCtrl.text) ?? 5,
                            status: _status,
                            createdAt: widget.item?.createdAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                            imageUrls: List<String>.from(_imageUrls),
                          );

                          if (newItem.imageBytesEstimate > 900 * 1024) {
                            showTopError(context, 'Product is too large to save. Remove an image.');
                            return;
                          }
                          if (widget.item == null) {
                            await firestoreService.addInventoryItem(newItem);
                          } else {
                            await firestoreService.updateInventoryItem(newItem);
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            showTopError(context, 'Save error: $e');
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hwOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Product', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductMultiImagePicker extends StatefulWidget {
  final List<String> initialUrls;
  final Function(List<String> urls) onImagesChanged;

  const _ProductMultiImagePicker({
    required this.initialUrls,
    required this.onImagesChanged,
  });

  @override
  State<_ProductMultiImagePicker> createState() => _ProductMultiImagePickerState();
}

class _ProductMultiImagePickerState extends State<_ProductMultiImagePicker> {
  late List<String> _urls;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _urls = List<String>.from(widget.initialUrls);
  }

  Future<void> _addImage() async {
    if (_urls.length >= 3) {
      if (mounted) {
        showTopError(context, 'Maximum 3 images allowed per product.');
      }
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 60,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();

      setState(() {
        _isUploading = true;
      });
      try {
        final storage = StorageService();
        final url = await storage.uploadProductImage(
          'prod_${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes,
        );
        setState(() {
          _urls.add(url);
          _isUploading = false;
        });
        widget.onImagesChanged(_urls);
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        if (mounted) {
          showTopError(context, '$e');
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _urls.removeAt(index);
    });
    widget.onImagesChanged(_urls);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Product Images (${_urls.length}/3)', style: TextStyle(color: p.text, fontWeight: FontWeight.bold, fontSize: 13)),
            if (_urls.length >= 3)
              Text('Maximum 3 images', style: TextStyle(color: p.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _urls.length >= 3 ? _urls.length : _urls.length + 1,
            itemBuilder: (context, index) {
              if (index == _urls.length) {
                // Add Image Card
                return GestureDetector(
                  onTap: _isUploading ? null : _addImage,
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: p.fill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.line, width: 1.5),
                    ),
                    child: Center(
                      child: _isUploading
                          ? const CircularProgressIndicator(color: hwOrange)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_photo_alternate_rounded, color: hwOrange, size: 28),
                                SizedBox(height: 6),
                                Text('Add Image', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                );
              }

              final url = _urls[index];
              return Container(
                width: 110,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImageWidget(url),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String urlStr) {
    if (urlStr.startsWith('data:image')) {
      try {
        final parts = urlStr.trim().split(',');
        if (parts.length > 1 && parts.last.trim().isNotEmpty) {
          final cleanBase64 = parts.last.replaceAll(RegExp(r'\s+'), '');
          final bytes = base64Decode(cleanBase64);
          return Image.memory(bytes, fit: BoxFit.cover);
        }
      } catch (e) {
        debugPrint('_buildImageWidget base64 decode error: $e');
      }
    } else {
      return Image.network(
        urlStr,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white54)),
      );
    }
    return const Center(child: Icon(Icons.broken_image, color: Colors.white54));
  }
}
