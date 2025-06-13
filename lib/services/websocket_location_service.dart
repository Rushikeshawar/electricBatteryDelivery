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
  Function(Map<String, dynamic> data)? onTrackingstopped;
  
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

  // Setup WebSocket event handlers
  void _setupEventHandlers() {
    if (_socket == null) return;

    debugPrint('🔧 WebSocketLocationService: Setting up event handlers');

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

    // Note: onConnecting is not available in socket_io_client
    // Connection status is handled in other events

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

    _socket!.on('current_location_response', (data) {
      debugPrint('📍 WebSocketLocationService: Received current_location_response: $data');
      _handleDriverLocationUpdate(data);
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
        onTrackingStarted?.call(data);
        notifyListeners();
      }
    });

    _socket!.on('location_sharing_ended', (data) {
      debugPrint('🛑 WebSocketLocationService: Location sharing ended: $data');
      if (data != null && data['orderId'] != null) {
        final orderId = _parseOrderId(data['orderId']);
        if (_currentOrderId == orderId) {
          _driverLocation = null;
          _lastLocationUpdate = null;
        }
        _orderLocations.remove(orderId);
        _locationUpdateTimes.remove(orderId);
        onLocationSharingEnded?.call('Location sharing ended for order $orderId');
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

  // Handle driver location updates
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

  // Start tracking driver location for an order
  Future<void> startLocationTracking(int orderId) async {
    if (_socket == null || !_isConnected) {
      debugPrint('❌ WebSocketLocationService: Cannot start tracking - not connected');
      onError?.call('Not connected to server');
      return;
    }

    debugPrint('🎯 WebSocketLocationService: Starting location tracking for order $orderId');
    _currentOrderId = orderId;
    
    try {
      // Send multiple events to ensure server receives the request
      _socket!.emit('start_location_tracking', {
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
      
      debugPrint('✅ WebSocketLocationService: Sent all tracking requests for order $orderId');
      
    } catch (e) {
      debugPrint('❌ WebSocketLocationService: Error starting tracking: $e');
      onError?.call('Error starting tracking: $e');
    }
    
    notifyListeners();
  }

  // Stop tracking driver location for an order
  Future<void> stopLocationTracking(int orderId) async {
    debugPrint('⏹️ WebSocketLocationService: Stopping location tracking for order $orderId');
    
    if (_socket != null && _isConnected) {
      try {
        _socket!.emit('stop_location_tracking', {
          'orderId': orderId,
        });
        
        debugPrint('✅ WebSocketLocationService: Sent stop tracking request for order $orderId');
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

  // Get detailed connection info
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
    };
  }

  // Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      ...getConnectionInfo(),
      'orderLocations': _orderLocations.map((key, value) => 
        MapEntry(key.toString(), {
          'latitude': value.latitude,
          'longitude': value.longitude,
          'updateTime': _locationUpdateTimes[key]?.toIso8601String(),
        })
      ),
      'socketId': _socket?.id,
      'socketConnected': _socket?.connected,
    };
  }

  // Check if tracking specific order
  bool isTrackingOrder(int orderId) {
    return _currentOrderId == orderId || _orderLocations.containsKey(orderId);
  }

  // Get all tracked orders
  List<int> getTrackedOrders() {
    return _orderLocations.keys.toList();
  }

  // Clear all tracking data
  void clearAllTracking() {
    _currentOrderId = null;
    _driverLocation = null;
    _lastLocationUpdate = null;
    _orderLocations.clear();
    _locationUpdateTimes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ WebSocketLocationService: Disposing');
    disconnect();
    super.dispose();
  }
}