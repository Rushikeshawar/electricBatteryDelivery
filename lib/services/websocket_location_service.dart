import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WebSocketLocationService extends ChangeNotifier {
  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  
  // Current tracking state
  int? _currentOrderId;
  LatLng? _driverLocation;
  DateTime? _lastLocationUpdate;
  
  // Connection details
  String? _serverUrl;
  String? _authToken;
  String? _userType;
  int? _userId;
  
  // Callbacks for location updates and events
  Function(LatLng location, int orderId)? onDriverLocationUpdate;
  Function(String message)? onConnectionStatusChange;
  Function(String error)? onError;
  Function(String message)? onLocationSharingEnded;
  Function(Map<String, dynamic> data)? onTrackingStarted;
  Function(Map<String, dynamic> data)? onTrackingStopped;
  
  // NEW: Enhanced callbacks for order events
  Function(Map<String, dynamic> data)? onOrderDelivered;
  Function(Map<String, dynamic> data)? onLocationSharingStarted;
  Function(Map<String, dynamic> data)? onLocationSharingStatusChanged;
  
  // Auto-reconnect timer
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  
  // Connection status
  String _connectionStatus = 'Disconnected';
  String _lastError = '';
  
  // Store multiple location tracking sessions
  final Map<int, LatLng> _orderLocations = {};
  final Map<int, DateTime> _locationUpdateTimes = {};
  
  // NEW: Track location sharing status per order
  final Map<int, bool> _locationSharingStatus = {};
  final Map<int, String> _orderStatus = {};
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  LatLng? get driverLocation => _driverLocation;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  int? get currentOrderId => _currentOrderId;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  IO.Socket? get socket => _socket; // Expose socket for direct access
  
  // Get location for specific order
  LatLng? getLocationForOrder(int orderId) => _orderLocations[orderId];
  DateTime? getLocationUpdateTimeForOrder(int orderId) => _locationUpdateTimes[orderId];
  
  // NEW: Get location sharing status for specific order
  bool getLocationSharingStatusForOrder(int orderId) => _locationSharingStatus[orderId] ?? false;
  String getOrderStatus(int orderId) => _orderStatus[orderId] ?? 'UNKNOWN';

  // Initialize WebSocket connection
  Future<void> initialize({
    required String serverUrl,
    required String authToken,
    required String userType,
    required int userId,
  }) async {
    debugPrint('🔌 WebSocketLocationService: Initializing...');
    
    _serverUrl = serverUrl;
    _authToken = authToken;
    _userType = userType;
    _userId = userId;
    
    _connectionStatus = 'Initializing...';
    notifyListeners();
    
    await _connect();
  }

  // Connect to WebSocket server
  Future<void> _connect() async {
    try {
      debugPrint('🔌 WebSocketLocationService: Connecting to $_serverUrl');
      _connectionStatus = 'Connecting...';
      notifyListeners();
      
      // Dispose existing connection
      await disconnect();
      
      _socket = IO.io(
        _serverUrl!,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $_authToken'})
            .setTimeout(15000)
            .build(),
      );

      _setupEventHandlers();
      _socket!.connect();
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Connection error: $e');
      _lastError = 'Connection failed: $e';
      _connectionStatus = 'Connection Error';
      onError?.call('Connection failed: $e');
      notifyListeners();
      _scheduleReconnect();
    }
  }

  // Setup WebSocket event handlers with enhanced order event support
  void _setupEventHandlers() {
    if (_socket == null) return;

    debugPrint('🔧 WebSocketLocationService: Setting up enhanced event handlers');

    // Connection events
    _socket!.onConnect((_) {
      debugPrint('✅ WebSocketLocationService: Connected successfully');
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStatus = 'Connected';
      _lastError = '';
      onConnectionStatusChange?.call('Connected');
      _authenticate();
      _startPingTimer();
      notifyListeners();
    });

    _socket!.onDisconnect((reason) {
      debugPrint('🔌 WebSocketLocationService: Disconnected: $reason');
      _isConnected = false;
      _isAuthenticated = false;
      _connectionStatus = 'Disconnected: $reason';
      onConnectionStatusChange?.call('Disconnected: $reason');
      _pingTimer?.cancel();
      notifyListeners();
      
      // Auto-reconnect if not intentional disconnect
      if (reason != 'io client disconnect') {
        _scheduleReconnect();
      }
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ WebSocketLocationService: Connection error: $error');
      _isConnected = false;
      _connectionStatus = 'Connection Error';
      _lastError = 'Connection error: $error';
      onConnectionStatusChange?.call('Connection Error');
      onError?.call('Connection error: $error');
      notifyListeners();
      _scheduleReconnect();
    });

    // Authentication events
    _socket!.on('authenticated', (data) {
      debugPrint('✅ WebSocketLocationService: Authenticated: $data');
      _isAuthenticated = true;
      _connectionStatus = 'Authenticated';
      onConnectionStatusChange?.call('Authenticated');
      notifyListeners();
      
      // Restart tracking if we had an active order
      if (_currentOrderId != null) {
        debugPrint('🔄 WebSocketLocationService: Restarting tracking for order $_currentOrderId');
        Future.delayed(Duration(seconds: 1), () {
          startLocationTracking(_currentOrderId!);
        });
      }
    });

    _socket!.on('auth_error', (data) {
      debugPrint('❌ WebSocketLocationService: Authentication error: $data');
      _isAuthenticated = false;
      _lastError = 'Authentication failed: $data';
      onError?.call('Authentication failed: $data');
      notifyListeners();
    });

    // Location tracking events - Multiple event handlers for compatibility
    _socket!.on('driver_location', (data) {
      debugPrint('📍 WebSocketLocationService: Received driver_location: $data');
      _handleDriverLocationUpdate(data);
    });

    _socket!.on('location_update', (data) {
      debugPrint('📍 WebSocketLocationService: Received location_update: $data');
      _handleDriverLocationUpdate(data);
    });

    _socket!.on('driver_position', (data) {
      debugPrint('📍 WebSocketLocationService: Received driver_position: $data');
      _handleDriverLocationUpdate(data);
    });

    _socket!.on('real_time_location', (data) {
      debugPrint('📍 WebSocketLocationService: Received real_time_location: $data');
      _handleDriverLocationUpdate(data);
    });

    _socket!.on('current_location_response', (data) {
      debugPrint('📍 WebSocketLocationService: Received current_location_response: $data');
      _handleDriverLocationUpdate(data);
    });

    // NEW: Enhanced order and delivery events
    _socket!.on('order_delivered', (data) {
      debugPrint('📦 WebSocketLocationService: Order delivered: $data');
      _handleOrderDelivered(data);
    });

    _socket!.on('location_sharing_started', (data) {
      debugPrint('🚀 WebSocketLocationService: Location sharing started: $data');
      _handleLocationSharingStarted(data);
    });

    _socket!.on('location_sharing_ended', (data) {
      debugPrint('🛑 WebSocketLocationService: Location sharing ended: $data');
      _handleLocationSharingEnded(data);
    });

    // Tracking status events
    _socket!.on('tracking_started', (data) {
      debugPrint('🎯 WebSocketLocationService: Tracking started: $data');
      if (data != null && data['orderId'] != null) {
        _currentOrderId = _parseOrderId(data['orderId']);
        onTrackingStarted?.call(data);
        notifyListeners();
      }
    });

    _socket!.on('tracking_stopped', (data) {
      debugPrint('⏹️ WebSocketLocationService: Tracking stopped: $data');
      if (data != null && data['orderId'] != null) {
        final orderId = _parseOrderId(data['orderId']);
        if (_currentOrderId == orderId) {
          _currentOrderId = null;
          _driverLocation = null;
          _lastLocationUpdate = null;
        }
        _orderLocations.remove(orderId);
        _locationUpdateTimes.remove(orderId);
        _locationSharingStatus.remove(orderId);
        onTrackingStopped?.call(data);
        notifyListeners();
      }
    });

    // Room events
    _socket!.on('room_joined', (data) {
      debugPrint('🏠 WebSocketLocationService: Room joined: $data');
    });

    _socket!.on('tracking_room_joined', (data) {
      debugPrint('🎯 WebSocketLocationService: Tracking room joined: $data');
    });

    // Error handling
    _socket!.on('error', (data) {
      debugPrint('❌ WebSocketLocationService: Socket error: $data');
      _lastError = 'Socket error: $data';
      onError?.call('Socket error: $data');
      notifyListeners();
    });

    // Ping/Pong for connection health
    _socket!.on('pong', (data) {
      debugPrint('🏓 WebSocketLocationService: Received pong: $data');
    });

    // Debug events
    _socket!.on('debug_response', (data) {
      debugPrint('🐛 WebSocketLocationService: Debug response: $data');
    });

    // Server events
    _socket!.on('server_shutdown', (data) {
      debugPrint('⚠️ WebSocketLocationService: Server shutting down: $data');
      _connectionStatus = 'Server shutting down';
      onConnectionStatusChange?.call('Server shutting down');
      notifyListeners();
    });
  }

  // NEW: Handle order delivered event
  void _handleOrderDelivered(dynamic data) {
    try {
      debugPrint('📦 WebSocketLocationService: Processing order delivered event');
      
      if (data == null) return;
      
      Map<String, dynamic> deliveryData;
      
      if (data is Map<String, dynamic>) {
        deliveryData = data;
      } else if (data is String) {
        try {
          deliveryData = jsonDecode(data);
        } catch (e) {
          debugPrint('❌ WebSocketLocationService: Error parsing delivery JSON: $e');
          return;
        }
      } else {
        return;
      }
      
      final orderId = _parseOrderId(deliveryData['orderId']);
      if (orderId == null) return;
      
      // Update order status
      _orderStatus[orderId] = 'DELIVERED';
      _locationSharingStatus[orderId] = false;
      
      // Clean up location tracking
      if (_currentOrderId == orderId) {
        _currentOrderId = null;
        _driverLocation = null;
        _lastLocationUpdate = null;
      }
      
      _orderLocations.remove(orderId);
      _locationUpdateTimes.remove(orderId);
      
      // Notify callback
      onOrderDelivered?.call(deliveryData);
      onLocationSharingEnded?.call('Order $orderId delivered successfully');
      
      notifyListeners();
      
      debugPrint('✅ WebSocketLocationService: Order $orderId marked as delivered, location tracking stopped');
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error handling order delivered: $e');
    }
  }

  // NEW: Handle location sharing started event
  void _handleLocationSharingStarted(dynamic data) {
    try {
      debugPrint('🚀 WebSocketLocationService: Processing location sharing started event');
      
      if (data == null) return;
      
      Map<String, dynamic> sharingData;
      
      if (data is Map<String, dynamic>) {
        sharingData = data;
      } else if (data is String) {
        try {
          sharingData = jsonDecode(data);
        } catch (e) {
          debugPrint('❌ WebSocketLocationService: Error parsing sharing started JSON: $e');
          return;
        }
      } else {
        return;
      }
      
      final orderId = _parseOrderId(sharingData['orderId']);
      if (orderId == null) return;
      
      // Update location sharing status
      _locationSharingStatus[orderId] = true;
      
      // Notify callback
      onLocationSharingStarted?.call(sharingData);
      
      notifyListeners();
      
      debugPrint('✅ WebSocketLocationService: Location sharing started for order $orderId');
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error handling location sharing started: $e');
    }
  }

  // UPDATED: Enhanced location sharing ended handler
  void _handleLocationSharingEnded(dynamic data) {
    try {
      debugPrint('🛑 WebSocketLocationService: Processing location sharing ended event');
      
      if (data == null) return;
      
      Map<String, dynamic> endData;
      
      if (data is Map<String, dynamic>) {
        endData = data;
      } else if (data is String) {
        try {
          endData = jsonDecode(data);
        } catch (e) {
          debugPrint('❌ WebSocketLocationService: Error parsing sharing ended JSON: $e');
          return;
        }
      } else {
        return;
      }
      
      final orderId = _parseOrderId(endData['orderId']);
      if (orderId == null) return;
      
      // Update location sharing status
      _locationSharingStatus[orderId] = false;
      
      // Clean up if this was the current order
      if (_currentOrderId == orderId) {
        _driverLocation = null;
        _lastLocationUpdate = null;
      }
      
      _orderLocations.remove(orderId);
      _locationUpdateTimes.remove(orderId);
      
      // Determine reason for ending
      final reason = endData['reason'] ?? 'unknown';
      String message = 'Location sharing ended';
      
      switch (reason) {
        case 'order_delivered':
          message = 'Location sharing ended - Order delivered';
          _orderStatus[orderId] = 'DELIVERED';
          break;
        case 'otp_verified':
          message = 'Location sharing ended - Delivery verified with OTP';
          _orderStatus[orderId] = 'DELIVERED';
          break;
        case 'driver_disconnected':
          message = 'Location sharing ended - Driver disconnected';
          break;
        case 'session_timeout':
          message = 'Location sharing ended - Session timeout';
          break;
        case 'manual_stop':
          message = 'Location sharing ended - Manually stopped';
          break;
        case 'server_shutdown':
          message = 'Location sharing ended - Server maintenance';
          break;
        default:
          message = endData['message'] ?? 'Location sharing ended';
      }
      
      // Notify callbacks
      onLocationSharingEnded?.call(message);
      onLocationSharingStatusChanged?.call({
        'orderId': orderId,
        'status': false,
        'reason': reason,
        'message': message,
      });
      
      notifyListeners();
      
      debugPrint('✅ WebSocketLocationService: Location sharing ended for order $orderId: $message');
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error handling location sharing ended: $e');
    }
  }

  // Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 25), (timer) {
      if (_isConnected && _socket != null) {
        try {
          debugPrint('🏓 WebSocketLocationService: Sending ping');
          _socket!.emit('ping', {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'userType': _userType,
            'userId': _userId,
          });
        } catch (e) {
          debugPrint('❌ WebSocketLocationService: Error sending ping: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  // Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ WebSocketLocationService: Max reconnection attempts reached');
      _connectionStatus = 'Max reconnection attempts reached';
      onError?.call('Failed to reconnect after $_maxReconnectAttempts attempts');
      notifyListeners();
      return;
    }

    _reconnectTimer?.cancel();
    
    // Exponential backoff: 2^attempts seconds, max 60 seconds
    final delay = Duration(seconds: (2 << _reconnectAttempts).clamp(2, 60));
    _reconnectAttempts++;
    
    debugPrint('🔄 WebSocketLocationService: Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');
    _connectionStatus = 'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)';
    notifyListeners();
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && _serverUrl != null) {
        _connect();
      }
    });
  }

  // Authenticate with the server
  void _authenticate() {
    if (_socket == null || !_isConnected) return;
    
    debugPrint('🔐 WebSocketLocationService: Authenticating as $_userType with ID $_userId');
    
    _socket!.emit('authenticate', {
      'userType': _userType,
      'id': _userId,
    });
  }

  // UPDATED: Enhanced driver location update handler
  void _handleDriverLocationUpdate(dynamic data) {
    try {
      debugPrint('📍 WebSocketLocationService: Processing location update: $data');
      
      if (data == null) {
        debugPrint('❌ WebSocketLocationService: Null location data received');
        return;
      }

      Map<String, dynamic> locationData;
      
      if (data is Map<String, dynamic>) {
        locationData = data;
      } else if (data is String) {
        try {
          locationData = jsonDecode(data);
        } catch (e) {
          debugPrint('❌ WebSocketLocationService: Error parsing JSON: $e');
          return;
        }
      } else {
        debugPrint('❌ WebSocketLocationService: Invalid location data format: ${data.runtimeType}');
        return;
      }

      debugPrint('📍 WebSocketLocationService: Location data keys: ${locationData.keys.join(', ')}');

      final orderId = _parseOrderId(locationData['orderId']);
      
      // Handle different data structures
      Map<String, dynamic>? location;
      double? latitude;
      double? longitude;
      
      if (locationData['location'] != null) {
        // Standard format: {orderId: x, location: {latitude: y, longitude: z}}
        location = locationData['location'] as Map<String, dynamic>?;
        latitude = _parseDouble(location?['latitude']);
        longitude = _parseDouble(location?['longitude']);
      } else if (locationData['latitude'] != null && locationData['longitude'] != null) {
        // Direct format: {orderId: x, latitude: y, longitude: z}
        latitude = _parseDouble(locationData['latitude']);
        longitude = _parseDouble(locationData['longitude']);
      } else {
        debugPrint('❌ WebSocketLocationService: No location data found in: $locationData');
        return;
      }
      
      if (orderId == null || latitude == null || longitude == null) {
        debugPrint('❌ WebSocketLocationService: Missing required data: orderId=$orderId, lat=$latitude, lng=$longitude');
        return;
      }

      final driverLatLng = LatLng(latitude, longitude);
      final updateTime = DateTime.now();
      
      debugPrint('✅ WebSocketLocationService: Valid location: $latitude, $longitude for order $orderId');
      
      // Store location data
      _orderLocations[orderId] = driverLatLng;
      _locationUpdateTimes[orderId] = updateTime;
      
      // NEW: Update location sharing status to active when receiving location
      _locationSharingStatus[orderId] = true;
      
      // Update current tracking if this is the tracked order
      if (_currentOrderId == orderId || _currentOrderId == null) {
        _driverLocation = driverLatLng;
        _lastLocationUpdate = updateTime;
        _currentOrderId = orderId;
      }
      
      // Notify callbacks
      onDriverLocationUpdate?.call(driverLatLng, orderId);
      notifyListeners();
      
      debugPrint('🎯 WebSocketLocationService: Location update processed and callbacks notified');
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error handling location update: $e');
      _lastError = 'Location update error: $e';
      onError?.call('Location update error: $e');
      notifyListeners();
    }
  }

  // UPDATED: Enhanced start tracking with better room joining
  Future<void> startLocationTracking(int orderId) async {
    if (_socket == null || !_isConnected) {
      debugPrint('❌ WebSocketLocationService: Cannot start tracking - not connected');
      onError?.call('Not connected to server');
      return;
    }

    debugPrint('🎯 WebSocketLocationService: Starting enhanced location tracking for order $orderId');
    _currentOrderId = orderId;
    
    try {
      // Send multiple events to ensure server receives the request
      _socket!.emit('start_location_tracking', {
        'orderId': orderId,
        'userId': _userId,
      });
      
      _socket!.emit('track_order', {
        'orderId': orderId,
        'userId': _userId,
      });
      
      _socket!.emit('join_order_room', {
        'orderId': orderId,
        'userId': _userId,
      });
      
      _socket!.emit('join_tracking_room', {
        'orderId': orderId,
      });
      
      _socket!.emit('request_driver_location', {
        'orderId': orderId,
      });
      
      _socket!.emit('request_current_location', {
        'orderId': orderId,
      });
      
      debugPrint('✅ WebSocketLocationService: Sent all enhanced tracking requests for order $orderId');
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error starting tracking: $e');
      onError?.call('Error starting tracking: $e');
    }
    
    notifyListeners();
  }

  // UPDATED: Enhanced stop tracking
  Future<void> stopLocationTracking(int orderId) async {
    debugPrint('⏹️ WebSocketLocationService: Stopping enhanced location tracking for order $orderId');
    
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('stop_location_tracking', {
          'orderId': orderId,
        });
        
        _socket!.emit('stop_tracking_order', {
          'orderId': orderId,
        });
        
        debugPrint('✅ WebSocketLocationService: Sent enhanced stop tracking requests for order $orderId');
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error stopping tracking: $e');
      }
    }
    
    // Clean up local state
    if (_currentOrderId == orderId) {
      _currentOrderId = null;
      _driverLocation = null;
      _lastLocationUpdate = null;
    }
    
    _orderLocations.remove(orderId);
    _locationUpdateTimes.remove(orderId);
    _locationSharingStatus.remove(orderId);
    
    notifyListeners();
  }

  // Update driver location (for drivers only)
  Future<void> updateDriverLocation(int orderId, double latitude, double longitude) async {
    if (_socket == null || !_isConnected) {
      debugPrint('❌ WebSocketLocationService: Cannot update location - not connected');
      return;
    }

    debugPrint('📍 WebSocketLocationService: Updating driver location for order $orderId: $latitude, $longitude');
    
    try {
      _socket!.emit('update_location', {
        'orderId': orderId,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }
      });
      
      // Also emit alternative event for compatibility
      _socket!.emit('driver_location_update', {
        'orderId': orderId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      debugPrint('✅ WebSocketLocationService: Sent location update for order $orderId');
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error updating location: $e');
      onError?.call('Error updating location: $e');
    }
  }

  // Join order room (for users)
  void joinOrderRoom(int orderId, int userId) {
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('join_order_room', {
          'orderId': orderId,
          'userId': userId,
        });
        
        debugPrint('🏠 WebSocketLocationService: Joined order room for order $orderId');
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error joining order room: $e');
      }
    }
  }

  // Request current location for an order
  void requestCurrentLocation(int orderId) {
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('request_current_location', {
          'orderId': orderId,
        });
        
        debugPrint('📍 WebSocketLocationService: Requested current location for order $orderId');
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error requesting current location: $e');
      }
    }
  }

  // Send ping to keep connection alive
  void sendPing() {
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('ping', {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'userType': _userType,
          'userId': _userId,
        });
        
        debugPrint('🏓 WebSocketLocationService: Sent ping');
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error sending ping: $e');
      }
    }
  }

  // Request debug information
  void requestDebugInfo() {
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('debug_info', {});
        debugPrint('🐛 WebSocketLocationService: Requested debug info');
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error requesting debug info: $e');
      }
    }
  }

  // Reconnect to the server
  Future<void> reconnect() async {
    debugPrint('🔄 WebSocketLocationService: Manual reconnection requested');
    _reconnectAttempts = 0;
    await _connect();
  }

  // Disconnect from the server
  Future<void> disconnect() async {
    debugPrint('🔌 WebSocketLocationService: Disconnecting');
    
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    
    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error during disconnect: $e');
      }
      _socket = null;
    }
    
    _isConnected = false;
    _isAuthenticated = false;
    _currentOrderId = null;
    _driverLocation = null;
    _lastLocationUpdate = null;
    _orderLocations.clear();
    _locationUpdateTimes.clear();
    _locationSharingStatus.clear();
    _orderStatus.clear();
    _connectionStatus = 'Disconnected';
    
    notifyListeners();
  }

  // Helper method to parse order ID
  int? _parseOrderId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    debugPrint('❌ WebSocketLocationService: Cannot parse order ID: $value (${value.runtimeType})');
    return null;
  }

  // Helper method to parse double values
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    debugPrint('❌ WebSocketLocationService: Cannot parse double: $value (${value.runtimeType})');
    return null;
  }

  // Get connection status as string
  String getConnectionStatus() {
    return _connectionStatus;
  }

  // UPDATED: Enhanced connection info with location sharing status
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'isAuthenticated': _isAuthenticated,
      'connectionStatus': _connectionStatus,
      'lastError': _lastError,
      'serverUrl': _serverUrl,
      'userType': _userType,
      'userId': _userId,
      'reconnectAttempts': _reconnectAttempts,
      'currentOrderId': _currentOrderId,
      'hasDriverLocation': _driverLocation != null,
      'lastLocationUpdate': _lastLocationUpdate?.toIso8601String(),
      'trackedOrdersCount': _orderLocations.length,
      'locationSharingActiveOrders': _locationSharingStatus.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
    };
  }

  // UPDATED: Enhanced debug info with location sharing and order status
  Map<String, dynamic> getDebugInfo() {
    return {
      ...getConnectionInfo(),
      'orderLocations': _orderLocations.map((key, value) => 
        MapEntry(key.toString(), {
          'latitude': value.latitude,
          'longitude': value.longitude,
          'updateTime': _locationUpdateTimes[key]?.toIso8601String(),
          'locationSharingActive': _locationSharingStatus[key] ?? false,
          'orderStatus': _orderStatus[key] ?? 'UNKNOWN',
        })
      ),
      'locationSharingStatus': _locationSharingStatus,
      'orderStatus': _orderStatus,
      'socketId': _socket?.id,
      'socketConnected': _socket?.connected,
    };
  }

  // Check if tracking specific order
  bool isTrackingOrder(int orderId) {
    return _currentOrderId == orderId || _orderLocations.containsKey(orderId);
  }

  // NEW: Check if location sharing is active for specific order
  bool isLocationSharingActive(int orderId) {
    return _locationSharingStatus[orderId] ?? false;
  }

  // Get all tracked orders
  List<int> getTrackedOrders() {
    return _orderLocations.keys.toList();
  }

  // NEW: Get all orders with active location sharing
  List<int> getActiveSharingOrders() {
    return _locationSharingStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // NEW: Get order status summary
  Map<String, dynamic> getOrderStatusSummary(int orderId) {
    return {
      'orderId': orderId,
      'hasLocation': _orderLocations.containsKey(orderId),
      'currentLocation': _orderLocations[orderId] != null 
          ? {
              'latitude': _orderLocations[orderId]!.latitude,
              'longitude': _orderLocations[orderId]!.longitude,
            }
          : null,
      'lastUpdate': _locationUpdateTimes[orderId]?.toIso8601String(),
      'locationSharingActive': _locationSharingStatus[orderId] ?? false,
      'orderStatus': _orderStatus[orderId] ?? 'UNKNOWN',
      'isCurrentlyTracked': _currentOrderId == orderId,
    };
  }

  // NEW: Update order status manually (for sync purposes)
  void updateOrderStatus(int orderId, String status) {
    _orderStatus[orderId] = status;
    
    // If order is delivered, stop location sharing
    if (status == 'DELIVERED') {
      _locationSharingStatus[orderId] = false;
      
      // Clean up if this was the current order
      if (_currentOrderId == orderId) {
        _driverLocation = null;
        _lastLocationUpdate = null;
      }
      
      _orderLocations.remove(orderId);
      _locationUpdateTimes.remove(orderId);
    }
    
    notifyListeners();
  }

  // NEW: Force refresh location sharing status for an order
  void refreshLocationSharingStatus(int orderId) {
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('get_location_status', {
          'orderId': orderId,
        });
        
        debugPrint('🔄 WebSocketLocationService: Requested location sharing status for order $orderId');
      } catch (e) {
        debugPrint('❌ WebSocketLocationService: Error requesting location status: $e');
      }
    }
  }

  // Clear tracking data for specific order
  void clearOrderTracking(int orderId) {
    if (_currentOrderId == orderId) {
      _currentOrderId = null;
      _driverLocation = null;
      _lastLocationUpdate = null;
    }
    
    _orderLocations.remove(orderId);
    _locationUpdateTimes.remove(orderId);
    _locationSharingStatus.remove(orderId);
    _orderStatus.remove(orderId);
    
    notifyListeners();
  }

  // Clear all tracking data
  void clearAllTracking() {
    _currentOrderId = null;
    _driverLocation = null;
    _lastLocationUpdate = null;
    _orderLocations.clear();
    _locationUpdateTimes.clear();
    _locationSharingStatus.clear();
    _orderStatus.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ WebSocketLocationService: Disposing');
    disconnect();
    super.dispose();
  }
}