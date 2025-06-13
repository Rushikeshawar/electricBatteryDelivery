import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// Import your existing models and services
import 'package:electric_battery_delivery_frontend/services/auth_service.dart';

// Simple Product model for this API service (to avoid conflicts)
class SimpleProduct {
  final int id;
  final String name;
  final String batteryType;
  final double price;
  final String? capacity;
  final String? voltage;
  final SimpleStationInfo? station;

  SimpleProduct({
    required this.id,
    required this.name,
    required this.batteryType,
    required this.price,
    this.capacity,
    this.voltage,
    this.station,
  });

  factory SimpleProduct.fromJson(Map<String, dynamic> json) {
    return SimpleProduct(
      id: json['id'],
      name: json['name'],
      batteryType: json['batteryType'],
      price: json['price'].toDouble(),
      capacity: json['capacity'],
      voltage: json['voltage'],
      station: json['station'] != null ? SimpleStationInfo.fromJson(json['station']) : null,
    );
  }
}

class SimpleStationInfo {
  final int id;
  final String name;
  final String address;

  SimpleStationInfo({
    required this.id,
    required this.name,
    required this.address,
  });

  factory SimpleStationInfo.fromJson(Map<String, dynamic> json) {
    return SimpleStationInfo(
      id: json['id'],
      name: json['name'],
      address: json['address'],
    );
  }
}

class ApiService {
  final String baseUrl;
  final AuthService authService;

  ApiService({
    required this.baseUrl,
    required this.authService,
  });

  // Get auth headers
  Map<String, String> get _headers => authService.getAuthHeaders();

  // Fetch all orders for the current user - Returns raw JSON data
  Future<Map<String, dynamic>> getUserOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (status != null && status != 'All') {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$baseUrl/users/orders').replace(queryParameters: queryParams);
      
      debugPrint('🌐 Fetching orders from: $uri');
      
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Orders fetched successfully: ${data['data']?.length ?? 0} orders');
        return data;
      } else {
        debugPrint('❌ Failed to fetch orders: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load orders: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching orders: $e');
      throw Exception('Error fetching orders: $e');
    }
  }

  // Fetch a single order by ID - Returns raw JSON data
  Future<Map<String, dynamic>> getOrderById(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/orders/$orderId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load order: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching order $orderId: $e');
      throw Exception('Error fetching order: $e');
    }
  }

  // Get OTP for a specific order
  Future<Map<String, dynamic>> getOrderOTP(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/orders/$orderId/otp'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['message'] ?? 'Failed to get OTP');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load OTP');
      }
    } catch (e) {
      debugPrint('❌ Error fetching OTP for order $orderId: $e');
      throw Exception('Error fetching OTP: $e');
    }
  }

  // Cancel an order
  Future<bool> cancelOrder(int orderId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/orders/$orderId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        debugPrint('❌ Failed to cancel order: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error cancelling order $orderId: $e');
      return false;
    }
  }

  // Create a new order - Returns raw JSON data
  Future<Map<String, dynamic>> createOrder({
    required int stationId,
    int? productId,
    String? batteryType,
    required int quantity,
    required double totalPrice,
    required String deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryNotes,
  }) async {
    try {
      final body = {
        'stationId': stationId,
        'quantity': quantity,
        'totalPrice': totalPrice,
        'deliveryAddress': deliveryAddress,
        if (productId != null) 'productId': productId,
        if (batteryType != null) 'batteryType': batteryType,
        if (deliveryLatitude != null) 'deliveryLatitude': deliveryLatitude,
        if (deliveryLongitude != null) 'deliveryLongitude': deliveryLongitude,
        if (deliveryNotes != null) 'deliveryNotes': deliveryNotes,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/users/orders'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      throw Exception('Error creating order: $e');
    }
  }

  // Get nearby stations - Returns list of station JSON data
  Future<List<Map<String, dynamic>>> getNearbyStations({
    double? latitude,
    double? longitude,
    double radius = 10.0,
  }) async {
    try {
      final queryParams = <String, String>{
        'radius': radius.toString(),
      };
      
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
      }

      final uri = Uri.parse('$baseUrl/users/nearby-stations').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load stations: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching nearby stations: $e');
      throw Exception('Error fetching stations: $e');
    }
  }

  // Get available products
  Future<List<SimpleProduct>> getAvailableProducts({
    int page = 1,
    int limit = 10,
    String? batteryType,
    int? stationId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (batteryType != null) queryParams['batteryType'] = batteryType;
      if (stationId != null) queryParams['stationId'] = stationId.toString();

      final uri = Uri.parse('$baseUrl/users/products').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((productJson) => SimpleProduct.fromJson(productJson))
              .toList();
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load products: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching products: $e');
      throw Exception('Error fetching products: $e');
    }
  }

  // Get products by station
  Future<List<SimpleProduct>> getProductsByStation(int stationId, {
    int page = 1,
    int limit = 10,
    String? batteryType,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (batteryType != null) queryParams['batteryType'] = batteryType;

      final uri = Uri.parse('$baseUrl/users/stations/$stationId/products').replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((productJson) => SimpleProduct.fromJson(productJson))
              .toList();
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load products: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching products for station $stationId: $e');
      throw Exception('Error fetching products: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to fetch profile: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching user profile: $e');
      throw Exception('Error fetching profile: $e');
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? oldPassword,
    String? newPassword,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (oldPassword != null && newPassword != null) {
        body['oldPassword'] = oldPassword;
        body['newPassword'] = newPassword;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/profile'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        debugPrint('❌ Failed to update profile: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      return false;
    }
  }

  // Get driver location status for an order
  Future<Map<String, dynamic>?> getDriverLocationStatus(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/orders/$orderId/driver-location'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching driver location status: $e');
      return null;
    }
  }
}

// Provider for the API service
final apiServiceProvider = Provider<ApiService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiService(
    baseUrl: 'http://localhost:3000/api', // Replace with your actual API URL
    authService: authService,
  );
});