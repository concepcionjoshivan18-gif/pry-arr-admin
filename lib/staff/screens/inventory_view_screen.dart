import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/inventory_item.dart';
import '../../core/utils/item_image_helper.dart';
import '../../core/components/top_notification.dart';

class InventoryViewScreen extends StatelessWidget {
  const InventoryViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Inventory Availability'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => confirmAndSignOut(context, authService),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: firestoreService.streamInventory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isLow = item.totalQuantity <= item.lowStockThreshold;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: buildItemImage(
                        item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
                        itemName: item.name,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Category: ${item.categoryId} • ${item.variants.length} variants'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.totalQuantity}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLow ? Colors.red : Colors.green[800]),
                      ),
                      const Text('Stock', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
