import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// Import your existing services
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_location_service.dart';

// Add your Google Maps API key here
const String GOOGLE_MAPS_API_KEY = 'AIzaSyBr_r8bq7m1A5aIh9-rkEIUB7chNfbwimM'; // Replace with your actual API key

// Simple Order model for this screen (to avoid conflicts)
class SimpleOrder {
  final int id;
  final String orderNumber;
  final String status;
  final String batteryType;
  final int quantity;
  final double totalPrice;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? deliveryNotes;
  final SimpleStation station;
  final SimpleDriver? driver;

  SimpleOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.batteryType,
    required this.quantity,
    required this.totalPrice,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.deliveryNotes,
    required this.station,
    this.driver,
  });

  factory SimpleOrder.fromJson(Map<String, dynamic> json) {
    return SimpleOrder(
      id: json['id'],
      orderNumber: json['orderNumber'],
      status: json['status'],
      batteryType: json['batteryType'],
      quantity: json['quantity'],
      totalPrice: json['totalPrice'].toDouble(),
      deliveryAddress: json['deliveryAddress'],
      deliveryLatitude: json['deliveryLatitude'].toDouble(),
      deliveryLongitude: json['deliveryLongitude'].toDouble(),
      deliveryNotes: json['deliveryNotes'],
      station: SimpleStation.fromJson(json['station']),
      driver: json['driver'] != null ? SimpleDriver.fromJson(json['driver']) : null,
    );
  }

  String get formattedStatus {
    return status.substring(0, 1) + status.substring(1).toLowerCase();
  }

  Color get statusColor {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'ASSIGNED':
        return Colors.purple;
      case 'IN_TRANSIT':
        return Colors.teal;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class SimpleStation {
  final int id;
  final String name;
  final String address;

  SimpleStation({
    required this.id,
    required this.name,
    required this.address,
  });

  factory SimpleStation.fromJson(Map<String, dynamic> json) {
    return SimpleStation(
      id: json['id'],
      name: json['name'],
      address: json['address'],
    );
  }
}

class SimpleDriver {
  final int id;
  final String name;
  final String phone;

  SimpleDriver({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory SimpleDriver.fromJson(Map<String, dynamic> json) {
    return SimpleDriver(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
    );
  }
}

// Route information class
class RouteInfo {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final String distanceValue;
  final String durationValue;

  RouteInfo({
    required this.points,
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
  });
}

// Provider for WebSocket service
final webSocketLocationServiceProvider = ChangeNotifierProvider<WebSocketLocationService>((ref) {
  return WebSocketLocationService();
});

class DriverTrackingScreen extends ConsumerStatefulWidget {
  final int orderId;

  const DriverTrackingScreen({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  ConsumerState<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends ConsumerState<DriverTrackingScreen> {
  final Completer<GoogleMapController> _mapController = Completer();

  // Order data
  SimpleOrder? _order;
  bool _isLoadingOrder = true;
  String? _orderError;

  // Location data
  LatLng? _userDeliveryLocation;
  LatLng? _driverCurrentLocation;

  // Map markers and polylines
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Connection status
  String _connectionStatus = 'Disconnected';
  bool _isTrackingActive = false;

  // Route information
  RouteInfo? _currentRoute;
  bool _isLoadingRoute = false;
  DateTime? _lastLocationUpdate;
  Timer? _routeUpdateTimer;

  // NEW: Location sharing status tracking
  bool _isLocationSharingActive = false;
  String _locationSharingStatus = 'Unknown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      _loadOrderData();
    });
  }

  @override
  void dispose() {
    final webSocketService = ref.read(webSocketLocationServiceProvider);
    webSocketService.stopLocationTracking(widget.orderId);
    _routeUpdateTimer?.cancel();
    super.dispose();
  }

  // Initialize WebSocket service
  void _initializeServices() {
    final webSocketService = ref.read(webSocketLocationServiceProvider);

    // Set up callbacks
    webSocketService.onDriverLocationUpdate = (location, orderId) {
      if (orderId == widget.orderId) {
        _updateDriverLocation(location);
      }
    };

    webSocketService.onConnectionStatusChange = (status) {
      setState(() {
        _connectionStatus = status;
      });
    };

    webSocketService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WebSocket Error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    };

    // NEW: Handle location sharing ended
    webSocketService.onLocationSharingEnded = (message) {
      if (mounted) {
        setState(() {
          _isLocationSharingActive = false;
          _locationSharingStatus = 'Ended';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location sharing ended: $message'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    };

    // Initialize connection
    _connectWebSocket();
  }

  // Connect to WebSocket server
  Future<void> _connectWebSocket() async {
    try {
      final webSocketService = ref.read(webSocketLocationServiceProvider);

      // Get auth token and user ID
      String? token;
      int? userId;

      try {
        final loginState = ref.read(loginProvider);
        token = loginState.user.token;

        if (loginState.user.id != null) {
          userId = int.tryParse(loginState.user.id.toString());
        }

        if (token == null || token.isEmpty) {
          throw Exception('No authentication token available');
        }

        if (userId == null) {
          throw Exception('Invalid user ID: ${loginState.user.id}');
        }
      } catch (e) {
        throw Exception('User not authenticated: $e');
      }

      await webSocketService.initialize(
        serverUrl: 'ws://localhost:3000', // Replace with your actual URL
        authToken: token,
        userType: 'user',
        userId: userId,
      );

      // Wait for connection and authentication
      _waitForConnectionAndJoinRooms(userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to tracking service: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Wait for connection and join rooms
  void _waitForConnectionAndJoinRooms(int userId) {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final webSocketService = ref.read(webSocketLocationServiceProvider);

      if (webSocketService.isConnected && webSocketService.isAuthenticated) {
        timer.cancel();
        _joinOrderRooms(userId);
        _startLocationTracking();
      } else if (timer.tick > 15) {
        timer.cancel();
        _showError('Failed to connect to tracking service');
      }
    });
  }

  // Join order-specific rooms
  void _joinOrderRooms(int userId) {
    final webSocketService = ref.read(webSocketLocationServiceProvider);

    if (webSocketService.socket != null) {
      // Join multiple rooms for comprehensive coverage
      webSocketService.socket!.emit('join_order_room', {
        'orderId': widget.orderId,
        'userId': userId,
      });

      webSocketService.socket!.emit('track_order', {
        'orderId': widget.orderId,
        'userId': userId,
      });

      // Set up additional event listeners for delivery events
      webSocketService.socket!.on('order_delivered', (data) {
        if (data != null && data['orderId'] == widget.orderId) {
          _handleOrderDelivered(data);
        }
      });

      webSocketService.socket!.on('location_sharing_started', (data) {
        if (data != null && data['orderId'] == widget.orderId) {
          _handleLocationSharingStarted(data);
        }
      });

      print('🏠 User: Joined all tracking rooms for order ${widget.orderId}');
    }
  }

  // NEW: Handle order delivered event
  void _handleOrderDelivered(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _isLocationSharingActive = false;
        _locationSharingStatus = 'Order Delivered';
      });

      // Show delivery confirmation
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: Text('Order Delivered! 🎉'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your order has been delivered successfully!'),
                if (data['otpVerified'] == true) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Verified with OTP',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 12),
                Text(
                  'Location tracking has been stopped automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadOrderData(); // Refresh order data
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // NEW: Handle location sharing started event
  void _handleLocationSharingStarted(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _isLocationSharingActive = true;
        _locationSharingStatus = 'Active';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver started sharing location'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Load order data from API using your existing authentication
  Future<void> _loadOrderData() async {
    try {
      setState(() {
        _isLoadingOrder = true;
        _orderError = null;
      });

      // Get auth token using your existing login provider
      String? token;
      try {
        final loginState = ref.read(loginProvider);
        token = loginState.user.token;

        if (token == null || token.isEmpty) {
          throw Exception('No authentication token available');
        }
      } catch (e) {
        throw Exception('User not authenticated');
      }

      // Make API request to get orders
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/users/orders?page=1&limit=100'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          final orders = responseData['data'] as List;

          // Find the specific order
          final orderData = orders.firstWhere(
            (order) => order['id'] == widget.orderId,
            orElse: () => null,
          );

          if (orderData != null) {
            final order = SimpleOrder.fromJson(orderData);

            setState(() {
              _order = order;
              _userDeliveryLocation = LatLng(
                order.deliveryLatitude,
                order.deliveryLongitude,
              );
              _isLoadingOrder = false;
            });

            _setupMapMarkers();

            // Start WebSocket tracking if order is in transit
            if (order.status == 'IN_TRANSIT') {
              _startLocationTracking();
              // Check if location sharing is active
              _checkLocationSharingStatus();
            } else if (order.status == 'DELIVERED') {
              setState(() {
                _isLocationSharingActive = false;
                _locationSharingStatus = 'Order Delivered';
              });
            }
          } else {
            setState(() {
              _orderError = 'Order not found';
              _isLoadingOrder = false;
            });
          }
        } else {
          setState(() {
            _orderError = 'Failed to load orders: ${responseData['message'] ?? 'Unknown error'}';
            _isLoadingOrder = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _orderError = 'Authentication required. Please log in again.';
          _isLoadingOrder = false;
        });
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _orderError = 'API Error: ${errorData['message'] ?? response.reasonPhrase}';
          _isLoadingOrder = false;
        });
      }
    } catch (e) {
      setState(() {
        _orderError = 'Error loading order: $e';
        _isLoadingOrder = false;
      });
    }
  }

  // NEW: Check location sharing status from server
  Future<void> _checkLocationSharingStatus() async {
    try {
      final loginState = ref.read(loginProvider);
      final token = loginState.user.token;

      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:3000/api/users/orders/${widget.orderId}/location-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _isLocationSharingActive = responseData['data']['isLocationSharingActive'] ?? false;
            _locationSharingStatus = _isLocationSharingActive ? 'Active' : 'Inactive';
          });
        }
      }
    } catch (e) {
      print('Error checking location sharing status: $e');
    }
  }

  // Setup map markers for user delivery location
  void _setupMapMarkers() {
    if (_userDeliveryLocation == null) return;

    setState(() {
      _markers.clear();

      // Add delivery location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery_location'),
          position: _userDeliveryLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Delivery Location',
            snippet: _order?.deliveryAddress ?? 'Customer Location',
          ),
        ),
      );
    });
  }

  // Start location tracking
  Future<void> _startLocationTracking() async {
    if (_isTrackingActive) return;

    setState(() {
      _isTrackingActive = true;
    });

    final webSocketService = ref.read(webSocketLocationServiceProvider);

    // Ensure we're connected and authenticated
    if (!webSocketService.isConnected || !webSocketService.isAuthenticated) {
      setState(() {
        _isTrackingActive = false;
      });
      return;
    }

    try {
      // Get user ID
      final loginState = ref.read(loginProvider);
      final userId = int.tryParse(loginState.user.id.toString());

      if (userId != null) {
        // Send enhanced tracking request with user ID for server mapping
        webSocketService.socket?.emit('start_location_tracking', {
          'orderId': widget.orderId,
          'userId': userId,
        });

        // Also emit track_order for comprehensive coverage
        webSocketService.socket?.emit('track_order', {
          'orderId': widget.orderId,
          'userId': userId,
          'orderNumber': _order?.orderNumber,
        });
      }

      await webSocketService.startLocationTracking(widget.orderId);

      // Request any existing location data
      webSocketService.requestCurrentLocation(widget.orderId);

      // Start periodic route updates
      _startRouteUpdateTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Started tracking driver location'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isTrackingActive = false;
      });
      _showError('Failed to start location tracking: $e');
    }
  }

  // Stop WebSocket location tracking
  Future<void> _stopLocationTracking() async {
    setState(() {
      _isTrackingActive = false;
    });

    final webSocketService = ref.read(webSocketLocationServiceProvider);
    
    // Emit stop tracking to server
    if (webSocketService.socket != null) {
      webSocketService.socket!.emit('stop_tracking_order', {
        'orderId': widget.orderId,
      });
    }
    
    await webSocketService.stopLocationTracking(widget.orderId);

    _routeUpdateTimer?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stopped tracking driver location'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Start periodic route updates
  void _startRouteUpdateTimer() {
    _routeUpdateTimer?.cancel();
    _routeUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_driverCurrentLocation != null && _userDeliveryLocation != null && _isTrackingActive) {
        _fetchRouteFromGoogleDirections();
      }
    });
  }

  // Update driver location on map
  void _updateDriverLocation(LatLng newLocation) {
    setState(() {
      _driverCurrentLocation = newLocation;
      _lastLocationUpdate = DateTime.now();

      // Remove old driver marker and add new one
      _markers.removeWhere((marker) => marker.markerId.value == 'driver_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: newLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Driver Location',
            snippet: _order?.driver?.name ?? 'Driver',
          ),
        ),
      );

      // Update location sharing status to active when we receive location
      if (!_isLocationSharingActive) {
        _isLocationSharingActive = true;
        _locationSharingStatus = 'Active';
      }
    });

    // Fetch real route from Google Directions API
    _fetchRouteFromGoogleDirections();
    _updateCameraToShowBothLocations();
  }

  // Fetch route from Google Directions API
  Future<void> _fetchRouteFromGoogleDirections() async {
    if (_driverCurrentLocation == null || _userDeliveryLocation == null || _isLoadingRoute) {
      return;
    }

    if (GOOGLE_MAPS_API_KEY == 'YOUR_GOOGLE_MAPS_API_KEY') {
      _createStraightLineRoute();
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final origin = '${_driverCurrentLocation!.latitude},${_driverCurrentLocation!.longitude}';
      final destination = '${_userDeliveryLocation!.latitude},${_userDeliveryLocation!.longitude}';

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'mode=driving&'
        'traffic_model=best_guess&'
        'departure_time=now&'
        'key=$GOOGLE_MAPS_API_KEY'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Decode polyline points
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);

          final routeInfo = RouteInfo(
            points: polylinePoints,
            distance: leg['distance']['text'],
            duration: leg['duration_in_traffic']?['text'] ?? leg['duration']['text'],
            distanceValue: leg['distance']['value'].toString(),
            durationValue: (leg['duration_in_traffic']?['value'] ?? leg['duration']['value']).toString(),
          );

          setState(() {
            _currentRoute = routeInfo;
            _isLoadingRoute = false;
          });

          _createRoutePolyline();
        } else {
          _createStraightLineRoute();
        }
      } else {
        _createStraightLineRoute();
      }
    } catch (e) {
      _createStraightLineRoute();
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  // Decode Google polyline format
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      polylineCoordinates.add(LatLng(latitude, longitude));
    }

    return polylineCoordinates;
  }

  // Create route polyline from Google Directions
  void _createRoutePolyline() {
    if (_currentRoute == null) return;

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('driving_route'),
          points: _currentRoute!.points,
          color: _isLocationSharingActive ? Colors.green : Colors.blue,
          width: 4,
          patterns: [],
        ),
      );
    });
  }

  // Fallback: Create straight line route
  void _createStraightLineRoute() {
    if (_userDeliveryLocation == null || _driverCurrentLocation == null) return;

    final distance = _calculateDistance(_driverCurrentLocation!, _userDeliveryLocation!);

    setState(() {
      _currentRoute = RouteInfo(
        points: [_driverCurrentLocation!, _userDeliveryLocation!],
        distance: _formatDistance(distance),
        duration: _estimateTime(distance),
        distanceValue: distance.toString(),
        durationValue: ((distance / 1000) / 30 * 3600).toString(),
      );

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('straight_route'),
          points: [_driverCurrentLocation!, _userDeliveryLocation!],
          color: _isLocationSharingActive ? Colors.green : Colors.blue,
          width: 3,
          patterns: [PatternItem.dash(10), PatternItem.gap(5)],
        ),
      );
    });
  }

  // Update camera to show both locations
  void _updateCameraToShowBothLocations() async {
    if (_userDeliveryLocation == null || _driverCurrentLocation == null) return;
    if (!_mapController.isCompleted) return;

    try {
      final GoogleMapController controller = await _mapController.future;

      final double minLat = math.min(
        _driverCurrentLocation!.latitude,
        _userDeliveryLocation!.latitude,
      );
      final double maxLat = math.max(
        _driverCurrentLocation!.latitude,
        _userDeliveryLocation!.latitude,
      );
      final double minLng = math.min(
        _driverCurrentLocation!.longitude,
        _userDeliveryLocation!.longitude,
      );
      final double maxLng = math.max(
        _driverCurrentLocation!.longitude,
        _userDeliveryLocation!.longitude,
      );

      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.002, minLng - 0.002),
        northeast: LatLng(maxLat + 0.002, maxLng + 0.002),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } catch (e) {
      debugPrint('Error updating camera: $e');
    }
  }

  // Calculate distance between two points (Haversine formula)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters

    double dLat = (point2.latitude - point1.latitude) * math.pi / 180;
    double dLng = (point2.longitude - point1.longitude) * math.pi / 180;

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(point1.latitude * math.pi / 180) *
            math.cos(point2.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Format distance for display
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  // Estimate arrival time based on distance
  String _estimateTime(double distanceInMeters) {
    const double averageSpeedKmh = 30.0;
    final double distanceKm = distanceInMeters / 1000;
    final double timeHours = distanceKm / averageSpeedKmh;
    final int timeMinutes = (timeHours * 60).round();

    if (timeMinutes < 60) {
      return '$timeMinutes min';
    } else {
      final int hours = timeMinutes ~/ 60;
      final int minutes = timeMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }

 // Format time ago
  String _getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  // Helper methods
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final webSocketService = ref.watch(webSocketLocationServiceProvider);

    if (_isLoadingOrder) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver Tracking'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading order data...'),
            ],
          ),
        ),
      );
    }

    if (_orderError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver Tracking'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error Loading Order',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _orderError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadOrderData,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  if (_orderError!.contains('Authentication') || _orderError!.contains('authenticated')) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order ${_order?.orderNumber ?? ''}'),
        actions: [
          // NEW: Enhanced connection and sharing status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: webSocketService.isConnected
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  webSocketService.isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                  color: webSocketService.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  webSocketService.isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: webSocketService.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // NEW: Location sharing status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _isLocationSharingActive
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLocationSharingActive ? Icons.location_on : Icons.location_off,
                  size: 16,
                  color: _isLocationSharingActive ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  _locationSharingStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isLocationSharingActive ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isTrackingActive ? Icons.location_on : Icons.location_off,
              color: _isTrackingActive ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              if (_isTrackingActive) {
                _stopLocationTracking();
              } else {
                _startLocationTracking();
              }
            },
            tooltip: _isTrackingActive ? 'Stop Tracking' : 'Start Tracking',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userDeliveryLocation ?? const LatLng(0, 0),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            trafficEnabled: true,
            buildingsEnabled: true,
          ),
          // NEW: Enhanced status indicator with location sharing info
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: _order?.statusColor ?? Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Order Status: ${_order?.formattedStatus ?? 'Unknown'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isLocationSharingActive
                              ? Colors.green.withOpacity(0.2)
                              : _isTrackingActive
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoadingRoute)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1),
                              ),
                            if (_isLoadingRoute) const SizedBox(width: 4),
                            Text(
                              _isLocationSharingActive
                                  ? (_isLoadingRoute ? 'UPDATING' : 'LIVE TRACKING')
                                  : _isTrackingActive
                                      ? 'WAITING FOR DRIVER'
                                      : 'NOT TRACKING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isLocationSharingActive
                                    ? Colors.green
                                    : _isTrackingActive
                                        ? Colors.blue
                                        : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isTrackingActive && _driverCurrentLocation != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentRoute != null) ...[
                          _buildInfoChip(
                            Icons.route,
                            _currentRoute!.distance,
                            Colors.blue,
                          ),
                          _buildInfoChip(
                            Icons.schedule,
                            _currentRoute!.duration,
                            Colors.green,
                          ),
                        ],
                        if (_lastLocationUpdate != null)
                          _buildInfoChip(
                            Icons.update,
                            _getTimeAgo(_lastLocationUpdate!),
                            Colors.orange,
                          ),
                      ],
                    ),
                    if (_currentRoute != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _currentRoute!.points.length > 2 ? Icons.navigation : Icons.linear_scale,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentRoute!.points.length > 2 ? 'Real-time navigation route' : 'Direct route (no road data)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else if (_isTrackingActive) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLocationSharingActive 
                              ? 'Receiving driver location updates...' 
                              : 'Waiting for driver to start sharing location...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // NEW: Location sharing status
                  if (_order?.status == 'IN_TRANSIT') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isLocationSharingActive 
                            ? Colors.green.shade50 
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isLocationSharingActive 
                              ? Colors.green.shade200 
                              : Colors.orange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isLocationSharingActive ? Icons.gps_fixed : Icons.gps_not_fixed,
                            size: 16,
                            color: _isLocationSharingActive ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLocationSharingActive
                                  ? 'Driver is sharing live location'
                                  : 'Driver location sharing: $_locationSharingStatus',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isLocationSharingActive 
                                    ? Colors.green.shade700 
                                    : Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_driverCurrentLocation != null && _currentRoute != null)
            Positioned(
              top: 140,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _isLocationSharingActive ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLocationSharingActive ? 'Live Route' : 'Route',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 12,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Delivery',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.2,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Connection & Tracking Status'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: webSocketService.isConnected ? Colors.green.shade50 : Colors.red.shade50,
                            border: Border.all(
                              color: webSocketService.isConnected ? Colors.green.shade200 : Colors.red.shade200,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    webSocketService.isConnected ? Icons.check_circle : Icons.error,
                                    color: webSocketService.isConnected ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _connectionStatus,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: webSocketService.isConnected ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                        if (_isTrackingActive)
                                          Text(
                                            _isLocationSharingActive 
                                                ? 'Receiving live driver location updates'
                                                : 'Tracking active - waiting for driver to share location',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!webSocketService.isConnected)
                                    TextButton(
                                      onPressed: _connectWebSocket,
                                      child: const Text('Reconnect'),
                                    ),
                                ],
                              ),
                              // NEW: Location sharing status indicator
                              if (_order?.status == 'IN_TRANSIT') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _isLocationSharingActive 
                                        ? Colors.blue.shade50 
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isLocationSharingActive ? Icons.navigation : Icons.location_searching,
                                        size: 16,
                                        color: _isLocationSharingActive 
                                            ? Colors.blue.shade700 
                                            : Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _isLocationSharingActive
                                              ? 'Driver is actively sharing location with real-time updates'
                                              : 'Driver location sharing: $_locationSharingStatus',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _isLocationSharingActive 
                                                ? Colors.blue.shade700 
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_currentRoute != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _currentRoute!.points.length > 2 ? Icons.navigation : Icons.linear_scale,
                                        size: 16,
                                        color: Colors.purple.shade700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _currentRoute!.points.length > 2
                                              ? 'Using Google Maps routing with real-time traffic data'
                                              : 'Using direct route estimation (limited road data available)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.purple.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_currentRoute != null) ...[
                          _buildSectionTitle('Live Route Information'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildRouteInfoItem(
                                        Icons.straighten,
                                        'Distance',
                                        _currentRoute!.distance,
                                        Colors.blue,
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.blue.shade200,
                                    ),
                                    Expanded(
                                      child: _buildRouteInfoItem(
                                        Icons.schedule,
                                        'ETA',
                                        _currentRoute!.duration,
                                        Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_lastLocationUpdate != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isLocationSharingActive 
                                          ? Colors.green.shade50 
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.update,
                                          size: 16,
                                          color: _isLocationSharingActive 
                                              ? Colors.green.shade700 
                                              : Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Last updated: ${_getTimeAgo(_lastLocationUpdate!)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _isLocationSharingActive 
                                                ? Colors.green.shade700 
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildSectionTitle('Driver Information'),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.person,
                          'Name',
                          _order?.driver?.name ?? 'Not Assigned',
                        ),
                        _buildInfoRow(
                          Icons.phone,
                          'Phone',
                          _order?.driver?.phone ?? 'N/A',
                        ),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Order Details'),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.battery_charging_full,
                          'Battery Type',
                          _order?.batteryType ?? 'N/A',
                        ),
                        _buildInfoRow(
                          Icons.numbers,
                          'Quantity',
                          '${_order?.quantity ?? 'N/A'}',
                        ),
                        _buildInfoRow(
                          Icons.currency_rupee,
                          'Total Price',
                          '₹${_order?.totalPrice ?? 'N/A'}',
                        ),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Station Details'),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.store,
                          'Station',
                          _order?.station.name ?? 'N/A',
                        ),
                        _buildInfoRow(
                          Icons.location_city,
                          'Station Address',
                          _order?.station.address ?? 'N/A',
                        ),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Delivery Address'),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.location_on,
                          'Address',
                          _order?.deliveryAddress ?? 'N/A',
                        ),
                        if (_order?.deliveryNotes != null && _order!.deliveryNotes!.isNotEmpty) ...[
                          _buildInfoRow(
                            Icons.note,
                            'Notes',
                            _order!.deliveryNotes!,
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_order?.status == 'IN_TRANSIT') ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/order-otp',
                                      arguments: {'orderId': widget.orderId},
                                    );
                                  },
                                  icon: const Icon(Icons.security),
                                  label: const Text('View OTP'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _order?.driver?.phone != null
                                      ? () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Driver Phone: ${_order!.driver!.phone}'),
                                              action: SnackBarAction(
                                                label: 'Copy',
                                                onPressed: () {
                                                  // TODO: Copy to clipboard
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.phone),
                                  label: const Text('Call Driver'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingRoute
                                  ? null
                                  : () {
                                      if (_driverCurrentLocation != null && _userDeliveryLocation != null) {
                                        _fetchRouteFromGoogleDirections();
                                      } else {
                                        _checkLocationSharingStatus();
                                      }
                                    },
                              icon: _isLoadingRoute
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(_isLoadingRoute 
                                  ? 'Updating Route...' 
                                  : _driverCurrentLocation != null 
                                      ? 'Refresh Route'
                                      : 'Check Location Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ] else if (_order?.status == 'DELIVERED') ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order Delivered Successfully! 🎉',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Thank you for using our service!',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_driverCurrentLocation != null && _userDeliveryLocation != null)
            FloatingActionButton(
              heroTag: "center",
              onPressed: _updateCameraToShowBothLocations,
              backgroundColor: Colors.purple,
              child: const Icon(Icons.center_focus_strong),
              tooltip: 'Center on Route',
            ),
          if (_driverCurrentLocation != null && _userDeliveryLocation != null) 
            const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: () {
              _loadOrderData();
              _checkLocationSharingStatus();
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.refresh),
            tooltip: 'Refresh Order Data',
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "tracking",
            onPressed: () {
              if (_isTrackingActive) {
                _stopLocationTracking();
              } else {
                _startLocationTracking();
              }
            },
            icon: Icon(_isTrackingActive ? Icons.stop : Icons.play_arrow),
            label: Text(_isTrackingActive ? 'Stop Tracking' : 'Start Tracking'),
            backgroundColor: _isTrackingActive ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}