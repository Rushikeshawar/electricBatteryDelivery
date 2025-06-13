// providers/enhanced_notification_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/models/notification_model.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_notification_service.dart';

// Enhanced Notification State class
class EnhancedNotificationState {
  final bool isLoading;
  final List<NotificationModel> notifications;
  final int unreadCount;
  final String? errorMessage;
  final bool isWebSocketConnected;
  final String webSocketStatus;
  final List<NotificationData> realtimeNotifications;
  
  EnhancedNotificationState({
    required this.isLoading,
    required this.notifications,
    required this.unreadCount,
    this.errorMessage,
    required this.isWebSocketConnected,
    required this.webSocketStatus,
    required this.realtimeNotifications,
  });
  
  EnhancedNotificationState copyWith({
    bool? isLoading,
    List<NotificationModel>? notifications,
    int? unreadCount,
    String? errorMessage,
    bool? isWebSocketConnected,
    String? webSocketStatus,
    List<NotificationData>? realtimeNotifications,
    bool clearError = false,
  }) {
    return EnhancedNotificationState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isWebSocketConnected: isWebSocketConnected ?? this.isWebSocketConnected,
      webSocketStatus: webSocketStatus ?? this.webSocketStatus,
      realtimeNotifications: realtimeNotifications ?? this.realtimeNotifications,
    );
  }
}

// Enhanced Notification Notifier
class EnhancedNotificationNotifier extends StateNotifier<EnhancedNotificationState> {
  final Ref _ref;
  WebSocketNotificationService? _webSocketService;
  
  EnhancedNotificationNotifier(this._ref)
      : super(EnhancedNotificationState(
          isLoading: false,
          notifications: [],
          unreadCount: 0,
          isWebSocketConnected: false,
          webSocketStatus: 'Disconnected',
          realtimeNotifications: [],
        )) {
    _initializeWebSocket();
  }
  
  // Initialize WebSocket connection
  Future<void> _initializeWebSocket() async {
    try {
      _webSocketService = WebSocketNotificationService();
      
      // Set up callbacks
      _webSocketService!.onNotificationReceived = _handleRealtimeNotification;
      _webSocketService!.onConnectionStatusChange = _handleConnectionStatusChange;
      _webSocketService!.onError = _handleWebSocketError;
      
      // Get auth data
      final loginState = _ref.read(loginProvider);
      final token = loginState.user.token;
      final userId = int.tryParse(loginState.user.id.toString());
      
      if (token != null && token.isNotEmpty && userId != null) {
        await _webSocketService!.initialize(
          serverUrl: 'ws://localhost:3000', // Replace with your server URL
          authToken: token,
          userType: 'user',
          userId: userId,
        );
        
        debugPrint('✅ NOTIFICATION PROVIDER: WebSocket initialized');
      } else {
        debugPrint('❌ NOTIFICATION PROVIDER: Invalid auth data');
      }
    } catch (e) {
      debugPrint('❌ NOTIFICATION PROVIDER: WebSocket initialization failed: $e');
      state = state.copyWith(
        webSocketStatus: 'Connection Failed: $e',
        errorMessage: 'Failed to initialize real-time notifications: $e'
      );
    }
  }
  
  // Handle real-time notification
  void _handleRealtimeNotification(NotificationData notification) {
    debugPrint('📢 NOTIFICATION PROVIDER: Received real-time notification: ${notification.title}');
    
    // Add to realtime notifications list
    final updatedRealtimeNotifications = [notification, ...state.realtimeNotifications];
    
    // Update unread count
    final newUnreadCount = notification.isRead ? state.unreadCount : state.unreadCount + 1;
    
    state = state.copyWith(
      realtimeNotifications: updatedRealtimeNotifications,
      unreadCount: newUnreadCount,
    );
    
    // Also refresh the main notifications list
    fetchNotifications();
  }
  
  // Handle connection status change
  void _handleConnectionStatusChange(String status) {
    debugPrint('🔌 NOTIFICATION PROVIDER: Connection status: $status');
    
    state = state.copyWith(
      isWebSocketConnected: _webSocketService?.isConnected ?? false,
      webSocketStatus: status,
    );
  }
  
  // Handle WebSocket errors
  void _handleWebSocketError(String error) {
    debugPrint('❌ NOTIFICATION PROVIDER: WebSocket error: $error');
    
    state = state.copyWith(
      errorMessage: 'WebSocket Error: $error',
      isWebSocketConnected: false,
    );
  }
  
  // Fetch notifications from API
  Future<void> fetchNotifications() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      
      // Get auth token
      final token = _ref.read(loginProvider).user.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not available. Please log in again.');
      }
      
      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Make API request to get notifications
      final url = Uri.parse('http://localhost:3000/api/users/notifications');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<NotificationModel> notifications = [];
          
          for (var item in jsonData['data']) {
            final notification = NotificationModel.fromJson(item);
            // Exclude OTP notifications
            if (notification.type != 'order_otp') {
              notifications.add(notification);
            }
          }
          
          state = state.copyWith(
            notifications: notifications,
            isLoading: false,
            clearError: true,
          );
          
          // Also update unread count
          await fetchUnreadCount();
          
          return;
        } else {
          throw Exception('Invalid data format from API');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load notifications');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error fetching notifications: ${e.toString()}',
      );
    }
  }
  
  // Fetch unread notification count
  Future<void> fetchUnreadCount() async {
    try {
      // Get auth token
      final token = _ref.read(loginProvider).user.token;
      if (token == null || token.isEmpty) {
        return; // Silent fail for count
      }
      
      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Make API request to get unread count
      final url = Uri.parse('http://localhost:3000/api/users/notifications/unread-count');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final int count = jsonData['data'];
          
          state = state.copyWith(
            unreadCount: count,
          );
          
          return;
        }
      }
    } catch (e) {
      // Silent fail for count
      debugPrint('Error fetching unread count: ${e.toString()}');
    }
  }
  
  // Mark a notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      // Get auth token
      final token = _ref.read(loginProvider).user.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not available. Please log in again.');
      }
      
      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Make API request to mark as read
      final url = Uri.parse('http://localhost:3000/api/users/notifications/$notificationId/read');
      final response = await http.patch(url, headers: headers);
      
      if (response.statusCode == 200) {
        // Update notification in state
        final updatedNotifications = state.notifications.map((notification) {
          if (notification.id == notificationId) {
            return notification.copyWith(isRead: true);
          }
          return notification;
        }).toList();
        
        // Also update realtime notifications
        final updatedRealtimeNotifications = state.realtimeNotifications.map((notification) {
          if (notification.id == notificationId) {
            return NotificationData(
              id: notification.id,
              title: notification.title,
              message: notification.message,
              type: notification.type,
              data: notification.data,
              createdAt: notification.createdAt,
              isRead: true,
            );
          }
          return notification;
        }).toList();
        
        state = state.copyWith(
          notifications: updatedNotifications,
          realtimeNotifications: updatedRealtimeNotifications,
          unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
        );
      }
    } catch (e) {
      debugPrint('Error marking notification as read: ${e.toString()}');
    }
  }
  
  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      // Get auth token
      final token = _ref.read(loginProvider).user.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not available. Please log in again.');
      }
      
      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Make API request to mark all as read
      final url = Uri.parse('http://localhost:3000/api/users/notifications/read-all');
      final response = await http.patch(url, headers: headers);
      
      if (response.statusCode == 200) {
        // Update all notifications in state
        final updatedNotifications = state.notifications.map((notification) {
          return notification.copyWith(isRead: true);
        }).toList();
        
        // Update all realtime notifications
        final updatedRealtimeNotifications = state.realtimeNotifications.map((notification) {
          return NotificationData(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            data: notification.data,
            createdAt: notification.createdAt,
            isRead: true,
          );
        }).toList();
        
        state = state.copyWith(
          notifications: updatedNotifications,
          realtimeNotifications: updatedRealtimeNotifications,
          unreadCount: 0,
        );
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: ${e.toString()}');
    }
  }
  
  // Reconnect WebSocket
  Future<void> reconnectWebSocket() async {
    try {
      if (_webSocketService != null) {
        await _webSocketService!.reconnect();
      } else {
        await _initializeWebSocket();
      }
    } catch (e) {
      debugPrint('Error reconnecting WebSocket: $e');
      state = state.copyWith(
        errorMessage: 'Failed to reconnect: $e',
      );
    }
  }
  
  // Test WebSocket connection
  void testWebSocketConnection() {
    _webSocketService?.requestTestNotification();
  }
  
  // Get WebSocket debug info
  Map<String, dynamic> getWebSocketDebugInfo() {
    return _webSocketService?.getDebugInfo() ?? {'error': 'WebSocket service not initialized'};
  }
  
  // Clear real-time notifications
  void clearRealtimeNotifications() {
    state = state.copyWith(realtimeNotifications: []);
  }
  
  @override
  void dispose() {
    _webSocketService?.disconnect();
    super.dispose();
  }
}

// Provider for enhanced notification state
final enhancedNotificationProvider = StateNotifierProvider<EnhancedNotificationNotifier, EnhancedNotificationState>((ref) {
  return EnhancedNotificationNotifier(ref);
});