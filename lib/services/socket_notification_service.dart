import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

class SocketNotificationService {
  // Singleton pattern
  static final SocketNotificationService _instance = SocketNotificationService._internal();
  
  factory SocketNotificationService() {
    return _instance;
  }
  
  SocketNotificationService._internal();
  
  // Socket instance
  io.Socket? _socket;
  
  // Base URL for the socket connection
  final String _socketUrl = 'http://localhost:3000'; // For Android emulator, use 10.0.2.2 to connect to localhost
  // Use your actual server IP if running on a physical device
  // final String _socketUrl = 'http://192.168.1.100:3000'; // Example real IP

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Initialize the socket connection
  void init() {
    _initializeNotifications();
    _tryToReconnect();
  }

  // Initialize local notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request notification permissions on Android 13+ (SDK 33+)
    _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Connect to the socket server
  void _connectSocket() {
    if (_socket != null) {
      // If socket exists but disconnected, reconnect
      if (!_socket!.connected) {
        _socket!.connect();
        return;
      }
      // If already connected, do nothing
      if (_socket!.connected) return;
    }

    _socket = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    // Setup socket event listeners
    _setupSocketListeners();

    // Connect to the socket server
    _socket!.connect();
    debugPrint('Socket connecting to $_socketUrl');
  }

  // Setup socket event listeners
  void _setupSocketListeners() {
    if (_socket == null) return;
    
    // Connection events
    _socket!.onConnect((_) {
      debugPrint('Socket connected');
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('Connection error: $error');
    });

    _socket!.onError((error) {
      debugPrint('Socket error: $error');
    });

    // Listen for notifications
    _socket!.on('notification', (data) {
      debugPrint('Notification received: $data');
      _handleNotification(data);
    });

    // Authentication response
    _socket!.on('authenticated', (data) {
      debugPrint('Socket authentication result: $data');
    });

    _socket!.on('auth_error', (data) {
      debugPrint('Authentication error: $data');
    });

    // Driver location updates (for order tracking)
    _socket!.on('driver_location', (data) {
      debugPrint('Driver location update: $data');
      // Handle driver location update if needed
    });
    
    _socket!.on('location_sharing_ended', (data) {
      debugPrint('Location sharing ended: $data');
      // Handle when driver stops sharing location
    });
  }

  // Authenticate socket connection with user ID and type
  void updateUserAuth(int userId) {
    // Connect socket if not already connected
    _connectSocket();
    
    if (_socket != null) {
      _socket!.emit('authenticate', {
        'userType': 'user', // Use 'user' for customer app
        'id': userId.toString(),
      });
      debugPrint('Socket authentication sent for user $userId');
      
      // Save the user ID to shared preferences
      _saveUserId(userId);
    }
  }
  
  // Save user ID to shared preferences
  Future<void> _saveUserId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('socketUserId', userId);
    } catch (e) {
      debugPrint('Error saving socket user ID: $e');
    }
  }

  // Try to reconnect with stored user ID
  Future<void> _tryToReconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('socketUserId');
      
      if (userId != null && userId > 0) {
        // Reconnect socket with saved user ID
        updateUserAuth(userId);
      }
    } catch (e) {
      debugPrint('Error reconnecting socket: $e');
    }
  }

  // Handle incoming notification
  void _handleNotification(dynamic data) {
    try {
      // Ensure data is properly formatted
      Map<String, dynamic> notification;
      if (data is Map) {
        notification = Map<String, dynamic>.from(data);
      } else if (data is String) {
        notification = jsonDecode(data);
      } else {
        debugPrint('Invalid notification format');
        return;
      }

      // Extract notification details
      final String title = notification['title'] ?? 'Notification';
      final String message = notification['message'] ?? '';
      final String type = notification['type'] ?? '';
      final Map<String, dynamic> additionalData = 
          notification['data'] is Map 
              ? Map<String, dynamic>.from(notification['data']) 
              : {};

      // Show local notification
      _showLocalNotification(title, message, type, additionalData);
    } catch (e) {
      debugPrint('Error handling notification: $e');
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(
    String title,
    String body,
    String type,
    Map<String, dynamic> data,
  ) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'battery_delivery_channel',
      'Battery Delivery Notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // Create payload with notification data
    final String payload = jsonEncode({
      'type': type,
      'data': data,
    });

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Set up notification handling for navigation
  void setupNotificationHandling(BuildContext context) {
    // This method can be used to set up navigation from notifications
    // For now, we just ensure we're connected
    _tryToReconnect();
  }

  // Start tracking driver location for an order
  void startLocationTracking(String orderId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('start_location_tracking', {'orderId': orderId});
      debugPrint('Started location tracking for order $orderId');
    } else {
      debugPrint('Cannot start tracking: Socket not connected');
    }
  }

  // Stop tracking driver location for an order
  void stopLocationTracking(String orderId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('stop_location_tracking', {'orderId': orderId});
      debugPrint('Stopped location tracking for order $orderId');
    }
  }

  // Disconnect socket (call when user logs out)
  void disconnect() {
    if (_socket != null) {
      if (_socket!.connected) {
        _socket!.disconnect();
      }
      _socket = null;
      debugPrint('Socket disconnected');
      
      // Clear stored user ID
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('socketUserId');
      });
    }
  }
  
  // Check if socket is connected
  bool isConnected() {
    return _socket != null && _socket!.connected;
  }
}