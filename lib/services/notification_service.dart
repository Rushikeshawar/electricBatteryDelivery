import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SocketNotificationService {
  // Singleton pattern
  static final SocketNotificationService _instance = SocketNotificationService._internal();
  factory SocketNotificationService() => _instance;
  SocketNotificationService._internal();

  // Socket instance
  IO.Socket? socket;
  
  // Notification plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Notification state management
  final ValueNotifier<List<Map<String, dynamic>>> notifications = 
      ValueNotifier<List<Map<String, dynamic>>>([]);
  
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  
  // Initialize the service
  Future<void> init() async {
    // Initialize local notifications
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
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }
  
  // Connect to the WebSocket server
  void connectToSocket(String serverUrl, String id, String userType) {
    // Initialize socket
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    
    // Connect to socket
    socket!.connect();
    
    // Socket event listeners
    socket!.onConnect((_) {
      debugPrint('Socket connected');
      connected.value = true;
      
      // Authenticate as a specified user type
      socket!.emit('authenticate', {
        'userType': userType,
        'id': id,
      });
    });
    
    socket!.on('authenticated', (data) {
      debugPrint('Socket authenticated: $data');
    });
    
    // Listen for notifications
    socket!.on('notification', (data) {
      debugPrint('Notification received: $data');
      
      if (data is Map<String, dynamic>) {
        // Add to notifications list
        List<Map<String, dynamic>> currentNotifications = [...notifications.value];
        currentNotifications.insert(0, data);
        notifications.value = currentNotifications;
        
        // Show local notification
        _showNotification(data);
      }
    });
    
    socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      connected.value = false;
    });
    
    socket!.onError((error) {
      debugPrint('Socket error: $error');
      connected.value = false;
    });
  }
  
  // Show a local notification
  Future<void> _showNotification(Map<String, dynamic> notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'app_channel',
      'App Notifications',
      channelDescription: 'Channel for app notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      notification['id'] ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification['title'] ?? 'New Notification',
      notification['message'] ?? '',
      platformChannelSpecifics,
      payload: notification['data'] != null ? notification['data'].toString() : null,
    );
  }
  
  // Mark notification as read
  void markNotificationAsRead(int notificationId) {
    try {
      // Update local state
      List<Map<String, dynamic>> updatedNotifications = [...notifications.value];
      int index = updatedNotifications.indexWhere((n) => n['id'] == notificationId);
      
      if (index != -1) {
        updatedNotifications[index]['isRead'] = true;
        notifications.value = updatedNotifications;
      }
      
      // Send update to server
      socket?.emit('mark_notification_read', {'id': notificationId});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
  
  // Mark all notifications as read
  void markAllAsRead() {
    try {
      // Update local state
      List<Map<String, dynamic>> updatedNotifications = [...notifications.value];
      for (var i = 0; i < updatedNotifications.length; i++) {
        updatedNotifications[i]['isRead'] = true;
      }
      notifications.value = updatedNotifications;
      
      // Send update to server
      socket?.emit('mark_all_notifications_read');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
  
  // Get unread notifications count
  int getUnreadCount() {
    return notifications.value.where((n) => n['isRead'] == false).length;
  }
  
  // Disconnect socket
  void disconnect() {
    socket?.disconnect();
    connected.value = false;
  }
  
  // Setup notification handling for navigation
  void setupNotificationHandling(BuildContext context) {
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        final payload = response.payload;
        if (payload != null) {
          debugPrint('Notification tapped with payload: $payload');
          
          // Navigate based on notification type
          // Example:
          try {
            if (payload.contains('orderId')) {
              // Extract order ID (implement based on your payload structure)
              final orderId = 'example-id'; // Replace with actual extraction
              
              // Navigate to order details
              Navigator.pushNamed(
                context, 
                '/order-details',
                arguments: {'orderId': orderId}
              );
            }
          } catch (e) {
            debugPrint('Error handling notification tap: $e');
          }
        }
      },
    );
  }
}