// websocket_notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math' as math;


class NotificationData {
  final int id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.data,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
    );
  }
}

class WebSocketNotificationService extends ChangeNotifier {
  static final WebSocketNotificationService _instance = 
      WebSocketNotificationService._internal();
  
  factory WebSocketNotificationService() {
    return _instance;
  }
  
  WebSocketNotificationService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  String _connectionStatus = 'Disconnected';
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  // Notification callbacks
  Function(NotificationData)? onNotificationReceived;
  Function(String)? onConnectionStatusChange;
  Function(String)? onError;

  // Connection state getters
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  String get connectionStatus => _connectionStatus;
  IO.Socket? get socket => _socket;

  // Initialize the WebSocket connection
  Future<void> initialize({
    required String serverUrl,
    required String authToken,
    required String userType,
    required int userId,
  }) async {
    try {
      debugPrint('🔌 NOTIFICATION: Initializing WebSocket connection...');
      debugPrint('🔌 NOTIFICATION: Server URL: $serverUrl');
      debugPrint('🔌 NOTIFICATION: User Type: $userType');
      debugPrint('🔌 NOTIFICATION: User ID: $userId');

      // Disconnect existing connection if any
      await disconnect();

      // Create socket connection
      _socket = IO.io(serverUrl, 
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(maxReconnectAttempts)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .enableForceNew()
          .setTimeout(20000)
          .build()
      );

      _setupSocketListeners(userType, userId, authToken);
      
      debugPrint('✅ NOTIFICATION: WebSocket initialization started');
      
    } catch (e) {
      debugPrint('❌ NOTIFICATION: Failed to initialize WebSocket: $e');
      _updateConnectionStatus('Connection Failed: $e');
      onError?.call('Failed to initialize WebSocket: $e');
    }
  }

  // Setup socket event listeners
  void _setupSocketListeners(String userType, int userId, String authToken) {
    if (_socket == null) return;

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('🔌 NOTIFICATION: Socket connected');
      _isConnected = true;
      _reconnectAttempts = 0;
      _updateConnectionStatus('Connected');
      
      // Authenticate immediately after connection
      _authenticate(userType, userId, authToken);
      
      // Start heartbeat
      _startHeartbeat();
      
      notifyListeners();
    });

    _socket!.onDisconnect((reason) {
      debugPrint('🔌 NOTIFICATION: Socket disconnected: $reason');
      _isConnected = false;
      _isAuthenticated = false;
      _updateConnectionStatus('Disconnected: $reason');
      
      // Stop heartbeat
      _stopHeartbeat();
      
      // Auto-reconnect for certain disconnect reasons
      if (reason == 'transport close' || reason == 'transport error') {
        _scheduleReconnect();
      }
      
      notifyListeners();
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ NOTIFICATION: Connection error: $error');
      _isConnected = false;
      _isAuthenticated = false;
      _updateConnectionStatus('Connection Error: $error');
      onError?.call('Connection error: $error');
      
      _scheduleReconnect();
      notifyListeners();
    });

    _socket!.onError((error) {
      debugPrint('❌ NOTIFICATION: Socket error: $error');
      onError?.call('Socket error: $error');
    });

    // Authentication response
    _socket!.on('authenticated', (data) {
      debugPrint('✅ NOTIFICATION: Authentication successful: $data');
      _isAuthenticated = true;
      _updateConnectionStatus('Authenticated');
      notifyListeners();
    });

    _socket!.on('auth_error', (data) {
      debugPrint('❌ NOTIFICATION: Authentication failed: $data');
      _isAuthenticated = false;
      _updateConnectionStatus('Authentication Failed');
      onError?.call('Authentication failed: ${data['message']}');
      notifyListeners();
    });

    // Notification events
    _socket!.on('notification', (data) {
      debugPrint('📢 NOTIFICATION: Received notification: $data');
      _handleNotification(data);
    });

    // Heartbeat response
    _socket!.on('pong', (data) {
      debugPrint('🏓 NOTIFICATION: Pong received');
    });

    // Server shutdown notification
    _socket!.on('server_shutdown', (data) {
      debugPrint('🛑 NOTIFICATION: Server shutting down: $data');
      _updateConnectionStatus('Server Shutting Down');
      onError?.call('Server is shutting down');
    });

    debugPrint('✅ NOTIFICATION: Socket listeners configured');
  }

  // Authenticate with the server
  void _authenticate(String userType, int userId, String authToken) {
    if (_socket == null || !_isConnected) {
      debugPrint('❌ NOTIFICATION: Cannot authenticate - socket not connected');
      return;
    }

    debugPrint('🔐 NOTIFICATION: Authenticating...');
    
    _socket!.emit('authenticate', {
      'userType': userType,
      'id': userId,
      'token': authToken,
    });
  }

  // Handle incoming notifications
  void _handleNotification(dynamic data) {
    try {
      Map<String, dynamic> notificationMap;
      
      if (data is String) {
        notificationMap = json.decode(data);
      } else if (data is Map<String, dynamic>) {
        notificationMap = data;
      } else {
        debugPrint('❌ NOTIFICATION: Invalid notification data format');
        return;
      }

      final notification = NotificationData.fromJson(notificationMap);
      
      debugPrint('📢 NOTIFICATION: Processed notification: ${notification.title}');
      
      // Call the notification callback
      onNotificationReceived?.call(notification);
      
    } catch (e) {
      debugPrint('❌ NOTIFICATION: Error processing notification: $e');
      onError?.call('Error processing notification: $e');
    }
  }

  // Update connection status
  void _updateConnectionStatus(String status) {
    _connectionStatus = status;
    debugPrint('📊 NOTIFICATION: Status updated: $status');
    onConnectionStatusChange?.call(status);
  }

  // Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _stopHeartbeat(); // Stop existing timer
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_socket != null && _isConnected) {
        debugPrint('🏓 NOTIFICATION: Sending heartbeat');
        _socket!.emit('ping', {'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
    
    debugPrint('💓 NOTIFICATION: Heartbeat started');
  }

  // Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('💔 NOTIFICATION: Heartbeat stopped');
  }

  // Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('❌ NOTIFICATION: Max reconnection attempts reached');
      _updateConnectionStatus('Max Reconnection Attempts Reached');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: math.min(_reconnectAttempts * 2, 30));
    
    debugPrint('🔄 NOTIFICATION: Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');
    _updateConnectionStatus('Reconnecting in ${delay.inSeconds}s...');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_socket != null) {
        debugPrint('🔄 NOTIFICATION: Attempting to reconnect...');
        _socket!.connect();
      }
    });
  }

  // Manually reconnect
  Future<void> reconnect() async {
    debugPrint('🔄 NOTIFICATION: Manual reconnect requested');
    _reconnectAttempts = 0;
    
    if (_socket != null) {
      _socket!.connect();
    }
  }

  // Disconnect the WebSocket
  Future<void> disconnect() async {
    debugPrint('🔌 NOTIFICATION: Disconnecting WebSocket...');
    
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    
    _isConnected = false;
    _isAuthenticated = false;
    _updateConnectionStatus('Disconnected');
    
    notifyListeners();
    
    debugPrint('✅ NOTIFICATION: WebSocket disconnected');
  }

  // Send a test notification request
  void requestTestNotification() {
    if (_socket != null && _isConnected && _isAuthenticated) {
      debugPrint('🧪 NOTIFICATION: Requesting test notification');
      _socket!.emit('request_test_notification');
    } else {
      debugPrint('❌ NOTIFICATION: Cannot send test request - not connected/authenticated');
    }
  }

  // Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'isConnected': _isConnected,
      'isAuthenticated': _isAuthenticated,
      'connectionStatus': _connectionStatus,
      'reconnectAttempts': _reconnectAttempts,
      'hasSocket': _socket != null,
      'socketConnected': _socket?.connected ?? false,
    };
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}