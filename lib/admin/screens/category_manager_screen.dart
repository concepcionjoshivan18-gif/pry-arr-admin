import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/firestore_service.dart';
import '../../core/models/category.dart';
import '../../core/theme/hardware_theme.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({super.key});

  Widget _glass({
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

  Widget _buildHardwareBackground() => const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        _buildHardwareBackground(),
        StreamBuilder<List<CategoryModel>>(
          stream: firestoreService.streamCategories(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: hwOrange));
            }
            final categories = snapshot.data ?? [];
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Glass(
                        radius: 16,
                        child: SizedBox(
                          width: 38,
                          height: 38,
                          child: IconButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                context.go('/admin/inventory');
                              }
                            },
                            icon: Icon(Icons.arrow_back_rounded, color: p.text, size: 18),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.category_rounded, color: hwOrange, size: 20),
                      const SizedBox(width: 10),
                      Text('Categories', style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 20)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showAddCategoryDialog(context, firestoreService),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('NEW CATEGORY'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hwOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: categories.isEmpty
                        ? _glass(
                            radius: 28,
                            padding: const EdgeInsets.all(48),
                            child: Center(
                              child: Text(
                                'No categories yet — add your first one.',
                                style: TextStyle(color: p.faint),
                              ),
                            ),
                          )
                        : _glass(
                            radius: 28,
                            padding: const EdgeInsets.all(16),
                            child: ListView.separated(
                              itemCount: categories.length,
                              separatorBuilder: (_, __) => Divider(color: p.line, height: 1),
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: hwOrange.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.sell_outlined, color: hwOrange, size: 18),
                                  ),
                                  title: Text(
                                    cat.name,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.text),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, size: 20),
                                        color: hwYellow,
                                        onPressed: () => _showEditCategoryDialog(context, firestoreService, cat),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                        color: hwRust,
                                        onPressed: () => firestoreService.deleteCategory(cat.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

  InputDecoration _hwDialogInputDecoration(BuildContext context, String hint) {
    final p = Pal.of(context);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: p.faint),
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

  Widget _hwDialogShell(BuildContext context, {required String title, IconData? icon, required Widget content, required List<Widget> actions}) {
    final p = Pal.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
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
                      if (icon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hwOrange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: hwOrange, size: 20),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(title, style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  content,
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, FirestoreService service) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _hwDialogShell(
        context,
        title: 'Add Category',
        icon: Icons.add_rounded,
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: Pal.of(context).text),
          decoration: _hwDialogInputDecoration(context, 'Category Name (e.g. Paints)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Pal.of(context).faint)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await service.addCategory(nameCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hwOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Category', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, FirestoreService service, CategoryModel cat) {
    final nameCtrl = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (ctx) => _hwDialogShell(
        context,
        title: 'Edit Category',
        icon: Icons.edit_rounded,
        content: TextField(
          controller: nameCtrl,
          style: TextStyle(color: Pal.of(context).text),
          decoration: _hwDialogInputDecoration(context, 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Pal.of(context).faint)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await service.renameCategory(cat.id, nameCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hwOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
