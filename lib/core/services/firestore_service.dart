import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../models/category.dart';
import '../models/app_user.dart';
import '../models/sale.dart';
import '../models/payroll.dart';
import '../models/attendance.dart';
import '../models/payslip.dart';
import '../models/review.dart';
import '../models/product.dart';
import '../models/chat_message.dart';
import '../models/conversation_model.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- INVENTORY STREAMS ---
  Stream<List<InventoryItem>> streamInventory() {
    return _db.collection('inventory').snapshots(includeMetadataChanges: true).map((snapshot) {
      final List<InventoryItem> items = [];
      for (var doc in snapshot.docs) {
        try {
          items.add(InventoryItem.fromMap(doc.data(), doc.id));
        } catch (e) {
          debugPrint('Error parsing inventory doc ${doc.id}: $e');
        }
      }

      // Deduplicate items by name (case-insensitive) to prevent duplicate or old demo docs from conflicting
      final Map<String, InventoryItem> uniqueItemsMap = {};
      for (var item in items) {
        final nameKey = item.name.trim().toLowerCase();
        uniqueItemsMap[nameKey] = item;
      }
      return uniqueItemsMap.values.toList();
    });
  }

  // --- CATEGORY STREAMS ---
  Stream<List<CategoryModel>> streamCategories() {
    return _db.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CategoryModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // --- ORDER STREAMS ---
  Stream<List<OrderModel>> streamAllOrders() {
    return _db.collection('orders').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // --- STAFF/ACCOUNTS STREAMS ---
  Stream<List<AppUser>> streamStaffAccounts() {
    return _db.collection('users').where('role', isEqualTo: 'staff').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<AppUser>> streamAllCustomers() {
    return _db.collection('users').where('role', isEqualTo: 'customer').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<AppUser>> streamAllAccounts() {
    return _db.collection('users').where('role', whereIn: ['staff', 'customer']).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // --- SALES STREAMS ---
  Stream<List<SaleModel>> streamSales() {
    return _db.collection('sales').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SaleModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // --- ATTENDANCE STREAMS ---
  Stream<List<AttendanceModel>> streamAttendance() {
    return _db.collection('attendance').orderBy('timestamp', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AttendanceModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addAttendance(AttendanceModel attendance) async {
    await _db.collection('attendance').add(attendance.toMap());
  }

  Future<void> updateAttendance(String id, Map<String, dynamic> data) async {
    await _db.collection('attendance').doc(id).update(data);
  }

  Future<void> deleteAttendance(String id) async {
    await _db.collection('attendance').doc(id).delete();
  }

  // --- PAYROLL STREAMS ---
  Stream<List<PayrollModel>> streamPayroll() {
    return _db.collection('payroll').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PayrollModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // --- PAYSLIP STREAMS ---
  Stream<List<PayslipModel>> streamStaffPayslips(String staffId) {
    return _db.collection('payslips')
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs.map((doc) => PayslipModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.dateGenerated.compareTo(a.dateGenerated));
      return list;
    });
  }

  Stream<List<PayslipModel>> streamAllPayslips() {
    return _db.collection('payslips').orderBy('dateGenerated', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PayslipModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  // --- LOYALTY OPERATIONS ---
  Future<void> updateUserLoyalty({required String uid, required int pointsChange}) async {
    await _db.collection('users').doc(uid).update({
      'loyaltyPoints': FieldValue.increment(pointsChange),
    });
  }

  Future<bool> checkGcashReferenceExists(String referenceNumber) async {
    // Note: Duplicate-reference check must also be enforced on the backend.
    if (referenceNumber.isEmpty) return false;
    try {
      final query = await _db.collection('orders')
          .where('gcashReferenceNumber', isEqualTo: referenceNumber)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateOrderPaymentStatus(String orderId, String paymentStatus, {String? reviewNote, String? reviewReason}) async {
    final updateData = <String, dynamic>{
      'paymentStatus': paymentStatus,
      'updatedAt': Timestamp.now(),
    };
    if (reviewNote != null) updateData['reviewNote'] = reviewNote;
    if (reviewReason != null) updateData['reviewReason'] = reviewReason;
    await _db.collection('orders').doc(orderId).update(updateData);
  }

  // --- CUSTOMER ORDER PLACEMENT ---
  Future<void> placeOrderDirectMap(String orderId, Map<String, dynamic> data) async {
    await _db.collection('orders').doc(orderId).set(data, SetOptions(merge: true));
  }

  Future<void> placeOrder({
    required String customerId, 
    required List<CartItem> items, 
    required double total,
    int? pointsEarned,
    int? pointsRedeemed,
    double? discountAmount,
    String fulfillmentType = 'delivery',
    String paymentMethod = 'Cash',
    String? paymentStatus,
    String? gcashReferenceNumber,
    double? gcashAmount,
    String? reviewReason,
    String? receiptImageUrl,
    String? reviewNote,
    double? deliveryLat,
    double? deliveryLng,
    String? deliveryAddress,
  }) async {
    final orderRef = _db.collection('orders').doc();
    final newOrder = OrderModel(
      id: orderRef.id,
      customerId: customerId,
      items: items,
      status: 'pending',
      total: total - (discountAmount ?? 0.0),
      createdAt: DateTime.now(),
      pointsEarned: pointsEarned ?? 0,
      pointsRedeemed: pointsRedeemed ?? 0,
      fulfillmentType: fulfillmentType,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      gcashReferenceNumber: gcashReferenceNumber,
      gcashAmount: gcashAmount,
      reviewReason: reviewReason,
      receiptImageUrl: receiptImageUrl,
      reviewNote: reviewNote,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      deliveryAddress: deliveryAddress,
    );

    // 1. Save locally to SQLite offline queue instantly (guaranteed fast)
    try {
      await LocalDatabaseService().saveOfflineOrder(orderRef.id, newOrder.toMap());
    } catch (_) {}

    // 2. Save to Firestore reliably
    try {
      await _db.collection('orders').doc(orderRef.id).set(newOrder.toMap());
    } catch (e) {
      debugPrint('Firestore order write error: $e');
    }

    // 3. Non-blocking points update
    if (pointsRedeemed != null && pointsRedeemed > 0) {
      _db.collection('users').doc(customerId).update({
        'loyaltyPoints': FieldValue.increment(-pointsRedeemed),
      }).timeout(const Duration(milliseconds: 300)).catchError((_) {});
    }

    // 4. Trigger notification for staff (New Order Received)
    NotificationService.instance.showNotification(
      title: '📦 New Order Received!',
      body: 'Order #${orderRef.id.substring(0, orderRef.id.length > 5 ? 5 : orderRef.id.length)} was placed.',
    );
  }

  // --- ATOMIC ORDER COMPLETION (Staff) ---
  Future<void> finalizeOrder(OrderModel order, AppUser staffUser) async {
    await _db.runTransaction((transaction) async {
      // 1. ALL READS FIRST (Required by Cloud Firestore Transactions)
      Map<String, DocumentSnapshot> itemSnapshots = {};
      
      for (var item in order.items) {
        if (item.productId.isEmpty) continue;
        
        DocumentReference invRef = _db.collection('inventory').doc(item.productId);
        DocumentSnapshot invSnap = await transaction.get(invRef);
        
        if (invSnap.exists) {
          itemSnapshots[item.productId] = invSnap;
        } else {
          // Check products collection as fallback
          DocumentReference prodRef = _db.collection('products').doc(item.productId);
          DocumentSnapshot prodSnap = await transaction.get(prodRef);
          if (prodSnap.exists) {
            itemSnapshots[item.productId] = prodSnap;
          }
        }
      }

      DocumentReference orderRef = _db.collection('orders').doc(order.id);
      DocumentSnapshot orderSnap = await transaction.get(orderRef);

      DocumentReference userRef = _db.collection('users').doc(order.customerId);
      DocumentSnapshot userSnap = await transaction.get(userRef);

      // 2. ALL WRITES SECOND
      // Check stock and update quantities for found items
      for (var item in order.items) {
        var snap = itemSnapshots[item.productId];
        if (snap == null || !snap.exists || snap.data() == null) continue;

        var data = snap.data() as Map<String, dynamic>;

        if (data.containsKey('variants') && data['variants'] is List) {
          var inventoryItem = InventoryItem.fromMap(data, snap.id);
          
          int variantIndex = inventoryItem.variants.indexWhere((v) => v.name == (item.variant ?? 'Standard'));
          if (variantIndex == -1) variantIndex = 0; // Fallback to first variant if name changed
          
          if (inventoryItem.variants.isNotEmpty && variantIndex < inventoryItem.variants.length) {
            var variant = inventoryItem.variants[variantIndex];
            int newQty = (variant.quantity - item.qty).clamp(0, 999999);

            List<Map<String, dynamic>> updatedVariants = inventoryItem.variants.map((v) {
              if (v.name == variant.name) {
                return {
                  'name': v.name,
                  'quantity': newQty,
                  'price': v.price,
                };
              }
              return v.toMap();
            }).toList();

            transaction.update(snap.reference, {
              'variants': updatedVariants,
              'updatedAt': Timestamp.now(),
            });
          }
        } else if (data.containsKey('stockQty')) {
          int currentStock = (data['stockQty'] ?? 0) as int;
          int newStock = (currentStock - item.qty).clamp(0, 999999);
          transaction.update(snap.reference, {
            'stockQty': newStock,
          });
        }
      }

      // 3. Mark order as completed
      if (orderSnap.exists) {
        transaction.update(orderRef, {
          'status': 'completed',
          'updatedAt': Timestamp.now(),
        });
      } else {
        transaction.set(orderRef, {
          'status': 'completed',
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      }

      // 4. Record the sale
      DocumentReference saleRef = _db.collection('sales').doc();
      SaleModel sale = SaleModel(
        id: saleRef.id,
        orderId: order.id,
        totalAmount: order.total,
        staffId: staffUser.uid,
        staffName: staffUser.fullName,
        createdAt: DateTime.now(),
        items: order.items,
      );
      transaction.set(saleRef, sale.toMap());

      // 5. Add loyalty points earned to customer
      if (order.pointsEarned > 0 && order.customerId.isNotEmpty) {
        if (userSnap.exists) {
          transaction.update(userRef, {
            'loyaltyPoints': FieldValue.increment(order.pointsEarned),
          });
        } else {
          transaction.set(userRef, {
            'loyaltyPoints': FieldValue.increment(order.pointsEarned),
          }, SetOptions(merge: true));
        }
      }
    });
  }

  // --- CRUD OPERATIONS ---

  // --- PRODUCTS ---
  Stream<List<Product>> streamProducts() {
    return _db.collection('products').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList();
    });
  }
  Future<void> addProduct(Product product) async {
    await _db.collection('products').add(product.toMap());
  }
  Future<void> updateProduct(Product product) async {
    await _db.collection('products').doc(product.id).update(product.toMap());
  }
  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  // Inventory
  Future<void> addInventoryItem(InventoryItem item) async {
    await _db.collection('inventory').add(item.toMap());
  }
  Future<void> updateInventoryItem(InventoryItem item) async {
    await _db.collection('inventory').doc(item.id).update(item.toMap());
  }
  Future<void> deleteInventoryItem(String id) async {
    await _db.collection('inventory').doc(id).delete();
  }



  // Categories
  Future<void> addCategory(String name) async {
    await _db.collection('categories').add({'name': name});
  }
  Future<void> renameCategory(String id, String newName) async {
    await _db.collection('categories').doc(id).update({'name': newName});
  }
  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  // Staff Accounts (Firestore side)
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }
  Future<void> updateUserStatus(String uid, String status) async {
    await _db.collection('users').doc(uid).update({'status': status});
  }

  Future<void> assignCard(String rfidUid, String staffId) async {
    if (rfidUid.trim().isNotEmpty) {
      await _db.collection('cards').doc(rfidUid.trim().toUpperCase()).set({'staffId': staffId});
    }
  }

  Future<void> deleteCard(String rfidUid) async {
    if (rfidUid.trim().isNotEmpty) {
      await _db.collection('cards').doc(rfidUid.trim().toUpperCase()).delete();
    }
  }
  Future<void> deleteUserAccount(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    final cleanedData = Map<String, dynamic>.from(data);
    cleanedData.remove('role');
    cleanedData.remove('status');
    cleanedData.remove('onShift');
    cleanedData.remove('createdAt');
    cleanedData.remove('attendance');
    await _db.collection('users').doc(uid).update(cleanedData);
  }

  // Payroll
  Future<void> addPayrollRecord(PayrollModel payroll) async {
    await _db.collection('payroll').add(payroll.toMap());
  }
  Future<void> updatePayrollStatus(String id, String status) async {
    await _db.collection('payroll').doc(id).update({'status': status});
  }

  // Payslips
  Future<void> createPayslip(PayslipModel payslip) async {
    await _db.collection('payslips').add(payslip.toMap());
  }
  Future<void> updatePayslipStatus(String id, String status) async {
    await _db.collection('payslips').doc(id).update({'status': status});
  }

  // Basic Order status update (for non-finalizing steps)
  Future<void> updateOrderStatus(String id, String status) async {
    if (status == 'cancelled') {
      await cancelOrder(id);
      return;
    }
    if (status == 'processing') {
      await _db.runTransaction((transaction) async {
        // 1. ALL READS FIRST
        DocumentReference orderRef = _db.collection('orders').doc(id);
        DocumentSnapshot orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) throw Exception('Order not found.');

        OrderModel order = OrderModel.fromMap(orderSnap.data() as Map<String, dynamic>, orderSnap.id);
        
        Map<String, DocumentSnapshot> invSnapshots = {};
        if (order.status == 'pending') {
          for (var item in order.items) {
            if (item.productId.isEmpty) continue;
            DocumentReference invRef = _db.collection('inventory').doc(item.productId);
            DocumentSnapshot invSnap = await transaction.get(invRef);
            if (!invSnap.exists) {
              throw Exception('Product ${item.name} not found in inventory.');
            }
            invSnapshots[item.productId] = invSnap;
          }
        }

        // 2. ALL WRITES SECOND
        if (order.status == 'pending') {
          for (var item in order.items) {
            if (item.productId.isEmpty) continue;
            DocumentSnapshot? invSnap = invSnapshots[item.productId];
            if (invSnap == null || !invSnap.exists || invSnap.data() == null) continue;

            InventoryItem invItem = InventoryItem.fromMap(invSnap.data() as Map<String, dynamic>, invSnap.id);
            
            if (item.variant != null && item.variant!.isNotEmpty) {
              int vIndex = invItem.variants.indexWhere((v) => v.name == item.variant);
              if (vIndex == -1) {
                throw Exception('Variant ${item.variant} for ${item.name} not found.');
              }
              if (invItem.variants[vIndex].quantity < item.qty) {
                throw Exception('Cannot accept order: Insufficient stock for ${item.name} (${item.variant}). Available: ${invItem.variants[vIndex].quantity}, Requested: ${item.qty}');
              }
              invItem.variants[vIndex] = ProductVariant(
                name: invItem.variants[vIndex].name,
                quantity: invItem.variants[vIndex].quantity - item.qty,
                price: invItem.variants[vIndex].price,
              );
            } else {
              if (invItem.variants.isNotEmpty) {
                if (invItem.variants.first.quantity < item.qty) {
                  throw Exception('Cannot accept order: Insufficient stock for ${item.name}. Available: ${invItem.variants.first.quantity}, Requested: ${item.qty}');
                }
                invItem.variants[0] = ProductVariant(
                  name: invItem.variants[0].name,
                  quantity: invItem.variants[0].quantity - item.qty,
                  price: invItem.variants[0].price,
                );
              }
            }

            transaction.update(invSnap.reference, {
              'variants': invItem.variants.map((v) => v.toMap()).toList(),
              'updatedAt': Timestamp.now(),
            });
          }
        }

        transaction.update(orderRef, {
          'status': status,
          'updatedAt': Timestamp.now(),
        });
      });
    } else {
      await _db.collection('orders').doc(id).update({'status': status, 'updatedAt': Timestamp.now()});
    }

    // Trigger notifications based on status update
    if (status == 'processing' || status == 'ready') {
      NotificationService.instance.showNotification(
        title: '✅ Order Accepted!',
        body: 'Your order #${id.substring(0, id.length > 5 ? 5 : id.length)} has been accepted and is being prepared.',
      );
      NotificationService.instance.showNotification(
        title: '🛵 New Delivery Assigned!',
        body: 'Order #${id.substring(0, id.length > 5 ? 5 : id.length)} is ready for delivery assignment.',
      );
    } else if (status == 'out_for_delivery') {
      NotificationService.instance.showNotification(
        title: '🚀 Out for Delivery!',
        body: 'Your order #${id.substring(0, id.length > 5 ? 5 : id.length)} is out for delivery.',
      );
    }
  }

  Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).delete();
  }

  Future<void> cancelOrder(String orderId) async {
    await _db.runTransaction((transaction) async {
      // 1. ALL READS FIRST
      DocumentReference orderRef = _db.collection('orders').doc(orderId);
      DocumentSnapshot orderSnap = await transaction.get(orderRef);
      
      if (!orderSnap.exists) throw Exception('Order not found.');
      
      OrderModel order = OrderModel.fromMap(orderSnap.data() as Map<String, dynamic>, orderSnap.id);
      
      if (order.status == 'cancelled' || order.status == 'completed') {
        throw Exception('Order cannot be cancelled in its current state.');
      }

      DocumentReference userRef = _db.collection('users').doc(order.customerId);
      DocumentSnapshot userSnap = await transaction.get(userRef);

      Map<String, DocumentSnapshot> invSnapshots = {};
      if (order.status == 'processing') {
        for (var item in order.items) {
          if (item.productId.isEmpty) continue;
          DocumentReference invRef = _db.collection('inventory').doc(item.productId);
          DocumentSnapshot invSnap = await transaction.get(invRef);
          if (invSnap.exists) {
            invSnapshots[item.productId] = invSnap;
          }
        }
      }

      // 2. ALL WRITES SECOND
      // Mark order as cancelled
      transaction.update(orderRef, {
        'status': 'cancelled',
        'updatedAt': Timestamp.now(),
      });

      // Return redeemed points to customer if any
      if (order.pointsRedeemed > 0) {
        if (userSnap.exists) {
          transaction.update(userRef, {
            'loyaltyPoints': FieldValue.increment(order.pointsRedeemed),
          });
        } else {
          transaction.set(userRef, {
            'loyaltyPoints': FieldValue.increment(order.pointsRedeemed),
          }, SetOptions(merge: true));
        }
      }

      // Restore inventory if order was previously processing
      if (order.status == 'processing') {
        for (var item in order.items) {
          if (item.productId.isEmpty) continue;
          DocumentSnapshot? invSnap = invSnapshots[item.productId];
          if (invSnap == null || !invSnap.exists || invSnap.data() == null) continue;

          InventoryItem invItem = InventoryItem.fromMap(invSnap.data() as Map<String, dynamic>, invSnap.id);
          if (item.variant != null && item.variant!.isNotEmpty) {
            int vIndex = invItem.variants.indexWhere((v) => v.name == item.variant);
            if (vIndex != -1) {
              invItem.variants[vIndex] = ProductVariant(
                name: invItem.variants[vIndex].name,
                quantity: invItem.variants[vIndex].quantity + item.qty,
                price: invItem.variants[vIndex].price,
              );
            }
          } else if (invItem.variants.isNotEmpty) {
            invItem.variants[0] = ProductVariant(
              name: invItem.variants[0].name,
              quantity: invItem.variants[0].quantity + item.qty,
              price: invItem.variants[0].price,
            );
          }

          transaction.update(invSnap.reference, {
            'variants': invItem.variants.map((v) => v.toMap()).toList(),
            'updatedAt': Timestamp.now(),
          });
        }
      }
    });
  }

  Future<void> deletePayslip(String id) async {
    await _db.collection('payslips').doc(id).delete();
  }



  // --- REVIEWS & RATINGS ---
  Stream<List<ReviewModel>> streamProductReviews(String productId) {
    return _db
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<ReviewModel>> streamAllReviews() {
    return _db.collection('reviews').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addReview(ReviewModel review) async {
    await _db.collection('reviews').add(review.toMap());
  }

  // --- INDEPENDENT CHAT & CONVERSATIONS ---
  
  final Map<String, DateTime> _lastMessageTime = {};

  Stream<List<ConversationModel>> streamConversations({String? type, String? customerId}) {
    Query query = _db.collection('conversations');
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (customerId != null) {
      query = query.where('customerId', isEqualTo: customerId);
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((doc) => ConversationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> streamActiveConversationsAdmin({String type = 'support'}) {
    return _db.collection('conversations')
        .snapshots()
        .map((snap) {
      final list = snap.docs.where((doc) {
        final data = doc.data();
        final t = data['type'] ?? 'support';
        return t == type;
      }).map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['chatId'] = doc.id;
        return data;
      }).toList();

      list.sort((a, b) {
        Timestamp? tA = a['updatedAt'] as Timestamp?;
        Timestamp? tB = b['updatedAt'] as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });

      return list;
    });
  }

  Future<String> getOrCreateConversation({
    required String type,
    required String customerId,
    String? driverId,
    String? orderId,
  }) async {
    if (type == 'delivery' && orderId != null) {
      final existing = await _db.collection('conversations')
          .where('orderId', isEqualTo: orderId)
          .where('type', isEqualTo: 'delivery')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }
    } else if (type == 'support' && customerId.isNotEmpty) {
      final existing = await _db.collection('conversations')
          .where('customerId', isEqualTo: customerId)
          .where('type', isEqualTo: 'support')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }
    }

    final docRef = _db.collection('conversations').doc();
    final conv = ConversationModel(
      id: docRef.id,
      type: type,
      customerId: customerId,
      driverId: driverId,
      orderId: orderId,
      status: 'open',
      createdAt: DateTime.now(),
      lastMessage: '',
      lastSender: '',
      lastRole: '',
      updatedAt: DateTime.now(),
      unreadCount: 0,
    );
    await docRef.set(conv.toMap());
    return docRef.id;
  }

  Stream<List<ChatMessage>> streamChatMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatMessage.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> sendChatMessage(String conversationId, ChatMessage msg) async {
    // 1. Rate limiting check (1 second interval)
    final lastTime = _lastMessageTime[msg.senderId];
    if (lastTime != null && DateTime.now().difference(lastTime) < const Duration(seconds: 1)) {
      throw Exception('Please wait a moment before sending another message.');
    }
    _lastMessageTime[msg.senderId] = DateTime.now();

    // 2. Input sanitization (trim text)
    final sanitizedText = msg.text.trim();
    if (sanitizedText.isEmpty) return;

    // 3. Authorization check: verify conversation exists
    final convDoc = await _db.collection('conversations').doc(conversationId).get();
    if (!convDoc.exists) throw Exception('Conversation not found.');
    final convData = convDoc.data()!;
    final status = convData['status'] ?? 'open';
    if (convData['type'] == 'delivery' && status == 'closed') {
      throw Exception('This delivery conversation is closed (order completed or cancelled).');
    }

    final sanitizedMsg = ChatMessage(
      id: msg.id,
      conversationId: conversationId,
      senderId: msg.senderId,
      senderName: msg.senderName,
      senderRole: msg.senderRole,
      recipientId: msg.recipientId,
      text: sanitizedText,
      timestamp: msg.timestamp,
      isRead: msg.isRead,
      orderId: msg.orderId,
    );

    // 4. Add message and update conversation metadata
    await _db.collection('conversations').doc(conversationId).collection('messages').add(sanitizedMsg.toMap());
    await _db.collection('conversations').doc(conversationId).set({
      'lastMessage': sanitizedText,
      'lastSender': msg.senderName,
      'lastRole': msg.senderRole,
      'updatedAt': Timestamp.fromDate(msg.timestamp),
      'unreadCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // 5. Trigger notification
    if (msg.senderRole == 'customer') {
      NotificationService.instance.showNotification(
        title: '💬 New Customer Message (${msg.senderName})',
        body: sanitizedText,
      );
    } else {
      NotificationService.instance.showNotification(
        title: '💬 New Support/Driver Message',
        body: sanitizedText,
      );
    }
  }

  Future<void> updateConversationStatus(String conversationId, String status) async {
    await _db.collection('conversations').doc(conversationId).update({'status': status});
  }

  // Seeding initial categories
  Future<void> seedInitialData() async {
    var cats = await _db.collection('categories').get();
    if (cats.docs.isEmpty) {
      for (var name in ['Tools', 'Electrical', 'Building', 'Plumbing', 'Paint']) {
        await addCategory(name);
      }
    }
  }
}
