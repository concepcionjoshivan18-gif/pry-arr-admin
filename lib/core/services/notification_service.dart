import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint("Handling a background message: ${message.messageId}");
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  AndroidNotificationChannel? _channel;

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }

    // Initialize local notifications for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // Request Android 13+ notification permission
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // Create Android Notification Channel with sound
    if (!kIsWeb) {
      _channel = const AndroidNotificationChannel(
        'high_importance_channel', // id
        'High Importance Notifications', // title
        description: 'This channel is used for important notifications.', // description
        importance: Importance.max,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel!);
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null && !kIsWeb) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel?.id ?? 'high_importance_channel',
              _channel?.name ?? 'High Importance Notifications',
              channelDescription: _channel?.description,
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['route'],
        );
      }
    });

    // Background messaging handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Get FCM Token for testing / server targeting
    String? token = await _fcm.getToken();
    debugPrint("FCM Token: $token");
  }

  Future<void> showNotification({required String title, required String body}) async {
    if (kIsWeb) return;
    try {
      debugPrint("Attempting to show notification: $title - $body");
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        platformChannelSpecifics,
      );
      debugPrint("Notification shown successfully!");
    } catch (e) {
      debugPrint("Error showing notification: $e");
    }
  }

  StreamSubscription? _orderSubscription;
  final Map<String, String> _knownOrderStatuses = {};
  bool _isInitialOrderLoad = true;

  void startListeningToOrders(dynamic firestoreService, dynamic authService) {
    _orderSubscription?.cancel();
    _isInitialOrderLoad = true;
    _orderSubscription = firestoreService.streamAllOrders().listen((orders) {
      final user = authService.currentUser;
      if (user == null) {
        _isInitialOrderLoad = false;
        return;
      }

      for (final order in orders) {
        final previousStatus = _knownOrderStatuses[order.id];

        if (previousStatus == null) {
          _knownOrderStatuses[order.id] = order.status;
          if (_isInitialOrderLoad) continue;

          // If the current user placed this order
          if (order.customerId == user.uid) {
            showNotification(
              title: '📦 Order Placed Successfully!',
              body: 'Your order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} has been placed.',
            );
          } else if (user.role == 'staff' || user.role == 'admin') {
            // If staff/admin and someone else placed it
            showNotification(
              title: '📦 New Order Received!',
              body: 'Order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} was placed.',
            );
          }

          // If driver
          if (user.isDriver && (order.status == 'processing' || order.status == 'ready')) {
            showNotification(
              title: '🛵 New Delivery Assigned!',
              body: 'Order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} is ready for delivery.',
            );
          }
        } else if (previousStatus != order.status) {
          _knownOrderStatuses[order.id] = order.status;

          // If customer
          if (order.customerId == user.uid) {
            if (order.status == 'processing' || order.status == 'ready') {
              showNotification(
                title: '✅ Order Accepted!',
                body: 'Your order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} has been accepted and is being prepared.',
              );
            } else if (order.status == 'out_for_delivery') {
              showNotification(
                title: '🚀 Out for Delivery!',
                body: 'Your order #${order.id.substring(0, order.id.length > 5 ? 5 : order.id.length)} is out for delivery.',
              );
            }
          }
        }
      }
      _isInitialOrderLoad = false;
    });
  }
}
