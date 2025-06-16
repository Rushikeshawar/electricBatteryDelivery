// lib/services/charging_provider_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

class ChargingProviderApiService {
  // Your actual API base URL
  static const String baseUrl = 'http://localhost:3000/api';
  static const Duration timeout = Duration(seconds: 30);

  // Get auth token from login provider
  static String? _getAuthToken(Ref ref) {
    try {
      final loginState = ref.read(loginProvider);
      return loginState.user.token.isNotEmpty ? loginState.user.token : null;
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  static Map<String, String> _getHeaders(Ref ref) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    final token = _getAuthToken(ref);
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      print('Using auth token: ${token.substring(0, 20)}...'); // Debug log (partial token)
    } else {
      print('No auth token available'); // Debug log
    }
    
    return headers;
  }

  // Find Nearby Providers - FIXED TO MATCH YOUR API RESPONSE
  static Future<List<ChargingProvider>> findNearbyProviders({
    required Ref ref,
    required double latitude,
    required double longitude,
    double radius = 10.0,
    String? chargerType,
    String? vehicleType,
    double? minRating,
    double? maxRate,
    List<String>? amenities,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Build query parameters - matching your working API call
      final queryParams = <String, String>{
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
        'radius': radius.toInt().toString(),
      };

      final uri = Uri.parse('$baseUrl/providers/find-providers')
          .replace(queryParameters: queryParams);

      print('🚀 Making API call to: $uri');

      final response = await http.get(
        uri,
        headers: _getHeaders(ref),
      ).timeout(timeout);

      print('📡 Response status: ${response.statusCode}');
      
      // Handle authentication errors
      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }
      
      // Check if response is HTML (indicates wrong URL or server error)
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        throw Exception('Received HTML response instead of JSON. Server might not be running or endpoint is incorrect.');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Parsed response structure: ${responseData.keys}');
        
        // Handle your specific API response structure
        List<dynamic> providersJson = [];
        
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            // Your API returns: { "success": true, "data": [...], "meta": {...} }
            providersJson = responseData['data'] as List<dynamic>;
            print('📊 Found ${providersJson.length} providers in API response');
          } else {
            throw Exception('API response indicates failure or no data');
          }
        } else {
          throw Exception('Unexpected response format: ${responseData.runtimeType}');
        }

        // Convert API response to ChargingProvider objects with CORRECT field mapping
        return providersJson.map((providerJson) {
          try {
            print('🔧 Processing provider: ${providerJson['businessName']}');
            
            // Calculate available slots from the slots array
            final slots = providerJson['slots'] as List? ?? [];
            final availableSlots = slots.where((slot) => slot['isAvailable'] == true).length;
            final totalSlots = slots.length > 0 ? slots.length : 4; // Default to 4 slots if none defined
            
            // Handle images safely - convert null to empty list
            List<String> imagesList = [];
            if (providerJson['images'] != null) {
              if (providerJson['images'] is List) {
                imagesList = (providerJson['images'] as List).cast<String>();
              }
            }
            
            // Handle amenities safely
            List<String> amenitiesList = [];
            if (providerJson['amenities'] != null && providerJson['amenities'] is List) {
              amenitiesList = (providerJson['amenities'] as List).cast<String>();
            }
            
            // Map your API response fields to ChargingProvider model - FIXED FIELD NAMES
            final provider = ChargingProvider(
              id: providerJson['id'] ?? 0,
              businessName: providerJson['businessName'] ?? 'Unknown Provider',
              address: providerJson['address'] ?? 'Address not available',
              latitude: (providerJson['latitude'] ?? 0).toDouble(),
              longitude: (providerJson['longitude'] ?? 0).toDouble(),
              distance: (providerJson['distance'] ?? 0).toDouble(),
              rating: (providerJson['rating'] ?? 0).toDouble(),
              totalSlots: totalSlots,
              availableSlots: availableSlots,
              ratePerHour: (providerJson['hourlyRate'] ?? 50).toDouble(), // FIXED: hourlyRate -> ratePerHour
              fastCharging: providerJson['chargerType']?.toString().contains('DC') ?? false,
              isOpen: providerJson['isActive'] ?? true,
              description: providerJson['description'] ?? 'No description available',
              images: imagesList,
              amenities: amenitiesList,
              reviews: [], // You can populate this from your reviews API if needed
              phoneNumber: providerJson['contactNumber'] ?? '',
              operatingHours: {
                'monday': '6:00 AM - 11:00 PM',
                'tuesday': '6:00 AM - 11:00 PM',
                'wednesday': '6:00 AM - 11:00 PM',
                'thursday': '6:00 AM - 11:00 PM',
                'friday': '6:00 AM - 11:00 PM',
                'saturday': '6:00 AM - 11:00 PM',
                'sunday': '7:00 AM - 10:00 PM',
              },
            );
            
            print('✅ Successfully mapped provider: ${provider.businessName} - ${provider.availableSlots}/${provider.totalSlots} slots - ₹${provider.ratePerHour}/hr');
            return provider;
            
          } catch (e) {
            print('❌ Error parsing provider: $e');
            print('📄 Provider data: $providerJson');
            throw Exception('Error parsing provider data: $e');
          }
        }).toList();
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('💥 Error in findNearbyProviders: $e');
      
      // If API fails and it's an auth issue, throw the error
      if (e.toString().contains('Authentication') || e.toString().contains('forbidden')) {
        rethrow;
      }
      
      // For network errors, you might want to show mock data or rethrow
      rethrow; // Change this to return _getMockProviders(latitude, longitude); if you want fallback
    }
  }

  // Get Provider Details - FIXED to match your API structure
  static Future<ChargingProvider> getProviderDetails({
    required Ref ref,
    required dynamic providerId,
    String? date,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (date != null) {
        queryParams['date'] = date;
      }

      final uri = Uri.parse('$baseUrl/providers/$providerId')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      print('🔍 Getting provider details from: $uri');

      final response = await http.get(
        uri,
        headers: _getHeaders(ref),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle your API response structure for single provider
        Map<String, dynamic> providerData;
        
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            providerData = responseData['data'];
          } else if (responseData['id'] != null) {
            // Direct provider object
            providerData = responseData;
          } else {
            throw Exception('Invalid provider details response');
          }
        } else {
          throw Exception('Unexpected response format');
        }
        
        // Map the response using the same logic as findNearbyProviders
        final slots = providerData['slots'] as List? ?? [];
        final availableSlots = slots.where((slot) => slot['isAvailable'] == true).length;
        final totalSlots = slots.length > 0 ? slots.length : 4;
        
        List<String> imagesList = [];
        if (providerData['images'] != null && providerData['images'] is List) {
          imagesList = (providerData['images'] as List).cast<String>();
        }
        
        List<String> amenitiesList = [];
        if (providerData['amenities'] != null && providerData['amenities'] is List) {
          amenitiesList = (providerData['amenities'] as List).cast<String>();
        }
        
        return ChargingProvider(
          id: providerData['id'] ?? 0,
          businessName: providerData['businessName'] ?? 'Unknown Provider',
          address: providerData['address'] ?? 'Address not available',
          latitude: (providerData['latitude'] ?? 0).toDouble(),
          longitude: (providerData['longitude'] ?? 0).toDouble(),
          distance: (providerData['distance'] ?? 0).toDouble(),
          rating: (providerData['rating'] ?? 0).toDouble(),
          totalSlots: totalSlots,
          availableSlots: availableSlots,
          ratePerHour: (providerData['hourlyRate'] ?? 50).toDouble(), // FIXED: hourlyRate -> ratePerHour
          fastCharging: providerData['chargerType']?.toString().contains('DC') ?? false,
          isOpen: providerData['isActive'] ?? true,
          description: providerData['description'] ?? 'No description available',
          images: imagesList,
          amenities: amenitiesList,
          reviews: [],
          phoneNumber: providerData['contactNumber'] ?? '',
          operatingHours: {
            'monday': '6:00 AM - 11:00 PM',
            'tuesday': '6:00 AM - 11:00 PM',
            'wednesday': '6:00 AM - 11:00 PM',
            'thursday': '6:00 AM - 11:00 PM',
            'friday': '6:00 AM - 11:00 PM',
            'saturday': '6:00 AM - 11:00 PM',
            'sunday': '7:00 AM - 10:00 PM',
          },
        );
      } else {
        throw Exception('Failed to load provider details: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('Authentication') || e.toString().contains('forbidden')) {
        rethrow;
      }
      throw Exception('Error loading provider details: $e');
    }
  }

  // Keep all your other methods (checkSlotAvailability, createBooking, etc.) unchanged
  // ... (rest of the methods remain the same)

  // Check Slot Availability
  static Future<Map<String, dynamic>> checkSlotAvailability({
    required Ref ref,
    required dynamic providerId,
    required dynamic slotId,
    required String date,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/providers/$providerId/slots/$slotId/availability')
          .replace(queryParameters: {'date': date});

      final response = await http.get(
        uri,
        headers: _getHeaders(ref),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to check slot availability: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create Booking
  static Future<Map<String, dynamic>> createBooking({
    required Ref ref,
    required int providerId,
    required int slotId,
    required String bookingDate,
    required String vehicleType,
    String? vehicleNumber,
    String? specialNotes,
  }) async {
    try {
      final requestBody = {
        'providerId': providerId,
        'slotId': slotId,
        'bookingDate': bookingDate,
        'vehicleType': vehicleType,
      };

      if (vehicleNumber != null) {
        requestBody['vehicleNumber'] = vehicleNumber;
      }
      if (specialNotes != null) {
        requestBody['specialNotes'] = specialNotes;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/bookings'),
        headers: _getHeaders(ref),
        body: json.encode(requestBody),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create booking: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get User Bookings
  static Future<List<Map<String, dynamic>>> getUserBookings({
    required Ref ref,
    int page = 1,
    int limit = 10,
    String? status,
    bool upcoming = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'upcoming': upcoming.toString(),
      };

      if (status != null) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$baseUrl/bookings')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(ref),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['bookings'] != null) {
          return List<Map<String, dynamic>>.from(data['bookings']);
        }
        return [];
      } else {
        throw Exception('Failed to load bookings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Cancel Booking
  static Future<Map<String, dynamic>> cancelBooking({
    required Ref ref,
    required dynamic bookingId,
    String? reason,
  }) async {
    try {
      final requestBody = <String, dynamic>{};
      if (reason != null) {
        requestBody['reason'] = reason;
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
        headers: _getHeaders(ref),
        body: json.encode(requestBody),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to cancel booking: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Add Provider Review
  static Future<Map<String, dynamic>> addProviderReview({
    required Ref ref,
    required dynamic providerId,
    required int rating,
    required String comment,
    dynamic bookingId,
  }) async {
    try {
      final requestBody = {
        'rating': rating,
        'comment': comment,
      };

      if (bookingId != null) {
        requestBody['bookingId'] = bookingId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/providers/$providerId/reviews'),
        headers: _getHeaders(ref),
        body: json.encode(requestBody),
      ).timeout(timeout);

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Please check your permissions.');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add review: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}