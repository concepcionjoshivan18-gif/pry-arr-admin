import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';
import '../models/cart_item.dart';
import 'firestore_service.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/pry_arr_local.db';

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Inventory Cache Table
        await db.execute('''
          CREATE TABLE inventory_cache (
            id TEXT PRIMARY KEY,
            name TEXT,
            categoryId TEXT,
            status TEXT,
            imageUrl TEXT,
            variantsJson TEXT,
            lowStockThreshold INTEGER,
            updatedAt TEXT
          )
        ''');

        // Local Cart Table
        await db.execute('''
          CREATE TABLE local_cart (
            id TEXT PRIMARY KEY,
            productId TEXT,
            name TEXT,
            price REAL,
            qty INTEGER,
            variant TEXT,
            isSelected INTEGER
          )
        ''');

        // Offline Orders Table
        await db.execute('''
          CREATE TABLE offline_orders (
            id TEXT PRIMARY KEY,
            orderDataJson TEXT,
            createdAt TEXT,
            synced INTEGER
          )
        ''');
      },
    );
  }

  // ===========================================================================
  // INVENTORY CACHE
  // ===========================================================================
  Future<void> cacheInventory(List<InventoryItem> items) async {
    final db = await database;
    final batch = db.batch();
    
    batch.delete('inventory_cache');

    for (var item in items) {
      final variantsMapList = item.variants.map((v) => v.toMap()).toList();
      batch.insert(
        'inventory_cache',
        {
          'id': item.id,
          'name': item.name,
          'categoryId': item.categoryId,
          'status': item.status,
          'imageUrl': item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
          'variantsJson': jsonEncode(variantsMapList),
          'lowStockThreshold': item.lowStockThreshold,
          'updatedAt': item.updatedAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<InventoryItem>> getLocalInventory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('inventory_cache');

    return maps.map((map) {
      final varList = jsonDecode(map['variantsJson'] as String? ?? '[]') as List;
      final parsedVariants = varList.map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v))).toList();

      final imgUrl = map['imageUrl'] as String? ?? '';
      return InventoryItem(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        categoryId: map['categoryId'] ?? '',
        status: map['status'] ?? 'Active',
        variants: parsedVariants,
        lowStockThreshold: map['lowStockThreshold'] ?? 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
        imageUrls: imgUrl.isNotEmpty ? [imgUrl] : [],
      );
    }).toList();
  }

  // ===========================================================================
  // LOCAL CART MANAGEMENT
  // ===========================================================================
  Future<void> saveCartItem(CartItem item) async {
    final db = await database;
    await db.insert(
      'local_cart',
      {
        'id': item.id,
        'productId': item.productId,
        'name': item.name,
        'price': item.price,
        'qty': item.qty,
        'variant': item.variant,
        'isSelected': item.isSelected ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CartItem>> getLocalCart() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('local_cart');

    return maps.map((map) {
      return CartItem(
        id: map['id'] ?? '',
        productId: map['productId'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] ?? 0.0).toDouble(),
        qty: map['qty'] ?? 1,
        variant: map['variant'],
        isSelected: map['isSelected'] == 1,
      );
    }).toList();
  }

  Future<void> removeCartItem(String id) async {
    final db = await database;
    await db.delete('local_cart', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearLocalCart() async {
    final db = await database;
    await db.delete('local_cart');
  }

  // ===========================================================================
  // OFFLINE ORDERS
  // ===========================================================================
  Future<void> saveOfflineOrder(String orderId, Map<String, dynamic> orderData) async {
    final db = await database;
    final sanitizedData = Map<String, dynamic>.from(orderData);
    if (sanitizedData['createdAt'] is Timestamp) {
      sanitizedData['createdAt'] = (sanitizedData['createdAt'] as Timestamp).toDate().toIso8601String();
    } else if (sanitizedData['createdAt'] is DateTime) {
      sanitizedData['createdAt'] = (sanitizedData['createdAt'] as DateTime).toIso8601String();
    }

    await db.insert(
      'offline_orders',
      {
        'id': orderId,
        'orderDataJson': jsonEncode(sanitizedData),
        'createdAt': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_orders',
      where: 'synced = ?',
      whereArgs: [0],
    );

    return maps.map((m) {
      final decodedData = Map<String, dynamic>.from(jsonDecode(m['orderDataJson']));
      if (decodedData['createdAt'] is String) {
        decodedData['createdAt'] = Timestamp.fromDate(DateTime.parse(decodedData['createdAt']));
      }
      return {
        'id': m['id'],
        'data': decodedData,
        'createdAt': m['createdAt'],
      };
    }).toList();
  }

  Future<void> markOrderSynced(String orderId) async {
    final db = await database;
    await db.update(
      'offline_orders',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<int> syncOfflineOrdersToCloud(FirestoreService fs) async {
    final unsynced = await getUnsyncedOrders();
    int count = 0;
    for (var u in unsynced) {
      try {
        final id = u['id'] as String;
        final data = u['data'] as Map<String, dynamic>;
        await fs.placeOrderDirectMap(id, data);
        await markOrderSynced(id);
        count++;
      } catch (_) {}
    }
    return count;
  }
}
