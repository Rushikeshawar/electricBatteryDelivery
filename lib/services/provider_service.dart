// lib/services/provider_service.dart - Fixed with correct endpoints
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/provider_models.dart';
import '../config/api_config.dart';

class ProviderService {
  // Remove const since ApiConfig.baseUrl is not a compile-time constant
  static String get baseUrl => ApiConfig.baseUrl;

  // Get Provider Profile
  static Future<Map<String, dynamic>> getProviderProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/providers/provider-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Provider Profile Response Status: ${response.statusCode}');
      print('Provider Profile Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle different response structures safely
        dynamic profileData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            profileData = responseData['data'];
          } else if (responseData.containsKey('profile')) {
            profileData = responseData['profile'];
          } else {
            profileData = responseData;
          }
        } else {
          profileData = responseData;
        }

        if (profileData != null && profileData is Map<String, dynamic>) {
          final profile = ProviderProfile.fromJson(profileData);
          return {
            'success': true,
            'data': profile,
            'message': 'Profile fetched successfully'
          };
        } else {
          return {
            'success': false,
            'data': null,
            'message': 'Invalid profile data format'
          };
        }
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'data': null,
          'message': 'Provider profile not found'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to fetch profile'
        };
      }
    } catch (e) {
      print('Error in getProviderProfile: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Update Provider Profile
  static Future<Map<String, dynamic>> updateProviderProfile(
      Map<String, dynamic> updates, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/providers/provider-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updates),
      );

      print('Update Profile Response Status: ${response.statusCode}');
      print('Update Profile Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Profile updated successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to update profile'
        };
      }
    } catch (e) {
      print('Error in updateProviderProfile: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Get Provider Slots
  static Future<Map<String, dynamic>> getProviderSlots(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/providers/provider-slots'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Provider Slots Response Status: ${response.statusCode}');
      print('Provider Slots Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Safely extract list data
        List<dynamic> slotsData = [];
        
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') && responseData['data'] is List) {
            slotsData = responseData['data'];
          } else if (responseData.containsKey('slots') && responseData['slots'] is List) {
            slotsData = responseData['slots'];
          }
        } else if (responseData is List) {
          slotsData = responseData;
        }

        final slots = slotsData
            .where((item) => item is Map<String, dynamic>)
            .map((slot) => ProviderSlot.fromJson(slot))
            .toList();
            
        return {
          'success': true,
          'data': slots,
          'message': 'Slots fetched successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': <ProviderSlot>[],
          'message': errorData['message'] ?? 'Failed to fetch slots'
        };
      }
    } catch (e) {
      print('Error in getProviderSlots: $e');
      return {
        'success': false,
        'data': <ProviderSlot>[],
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Update Provider Slots
  static Future<Map<String, dynamic>> updateProviderSlots(
      List<ProviderSlot> slots, String token) async {
    try {
      final slotsJson = slots.map((slot) => slot.toJson()).toList();
      
      final response = await http.post(
        Uri.parse('$baseUrl/providers/provider-slots'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'slots': slotsJson}),
      );

      print('Update Slots Response Status: ${response.statusCode}');
      print('Update Slots Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Slots updated successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to update slots'
        };
      }
    } catch (e) {
      print('Error in updateProviderSlots: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Toggle Slot Availability
  static Future<Map<String, dynamic>> toggleSlotAvailability(
      String slotId, bool isAvailable, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/providers/provider-slots/$slotId/toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'isAvailable': isAvailable}),
      );

      print('Toggle Slot Response Status: ${response.statusCode}');
      print('Toggle Slot Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Slot availability updated successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to toggle slot availability'
        };
      }
    } catch (e) {
      print('Error in toggleSlotAvailability: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Get Provider Bookings
  static Future<Map<String, dynamic>> getProviderBookings(
    String token, {
    int page = 1,
    int limit = 10,
    String? status,
    String? date,
  }) async {
    try {
      String url = '$baseUrl/providers/provider-bookings?page=$page&limit=$limit';
      if (status != null) url += '&status=$status';
      if (date != null) url += '&date=$date';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Provider Bookings Response Status: ${response.statusCode}');
      print('Provider Bookings Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Safely extract list data
        List<dynamic> bookingsData = [];
        
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') && responseData['data'] is List) {
            bookingsData = responseData['data'];
          } else if (responseData.containsKey('bookings') && responseData['bookings'] is List) {
            bookingsData = responseData['bookings'];
          }
        } else if (responseData is List) {
          bookingsData = responseData;
        }

        final bookings = bookingsData
            .where((item) => item is Map<String, dynamic>)
            .map((booking) => ProviderBooking.fromJson(booking))
            .toList();
            
        return {
          'success': true,
          'data': bookings,
          'message': 'Bookings fetched successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': <ProviderBooking>[],
          'message': errorData['message'] ?? 'Failed to fetch bookings'
        };
      }
    } catch (e) {
      print('Error in getProviderBookings: $e');
      return {
        'success': false,
        'data': <ProviderBooking>[],
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Update Booking Status
  static Future<Map<String, dynamic>> updateBookingStatus(
    String bookingId,
    String status,
    String token, {
    double? actualAmount,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'status': status,
      };
      if (actualAmount != null) {
        requestBody['actualAmount'] = actualAmount;
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/providers/provider-bookings/$bookingId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Update Booking Status Response Status: ${response.statusCode}');
      print('Update Booking Status Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Booking status updated successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to update booking status'
        };
      }
    } catch (e) {
      print('Error in updateBookingStatus: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Get Provider Analytics
  static Future<Map<String, dynamic>> getProviderAnalytics(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/providers/provider-analytics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Provider Analytics Response Status: ${response.statusCode}');
      print('Provider Analytics Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle different response structures safely
        dynamic analyticsData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            analyticsData = responseData['data'];
          } else if (responseData.containsKey('analytics')) {
            analyticsData = responseData['analytics'];
          } else {
            analyticsData = responseData;
          }
        } else {
          analyticsData = responseData;
        }

        if (analyticsData != null && analyticsData is Map<String, dynamic>) {
          final analytics = ProviderAnalytics.fromJson(analyticsData);
          return {
            'success': true,
            'data': analytics,
            'message': 'Analytics fetched successfully'
          };
        } else {
          return {
            'success': false,
            'data': null,
            'message': 'Invalid analytics data format'
          };
        }
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to fetch analytics'
        };
      }
    } catch (e) {
      print('Error in getProviderAnalytics: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Get Provider Request Status - FIXED ENDPOINT
  static Future<Map<String, dynamic>> getProviderRequestStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/providers/provider-request-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Provider Request Status Response Status: ${response.statusCode}');
      print('Provider Request Status Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle different response structures safely
        dynamic statusData;
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data') && responseData['data'] != null) {
            statusData = responseData['data'];
          } else if (responseData.containsKey('status') && responseData['status'] != null) {
            statusData = responseData['status'];
          }
        }

        ProviderRequestStatus? status;
        if (statusData != null && statusData is Map<String, dynamic>) {
          status = ProviderRequestStatus.fromJson(statusData);
        }

        return {
          'success': true,
          'data': status,
          'message': 'Request status fetched successfully'
        };
      } else if (response.statusCode == 404) {
        return {
          'success': true,
          'data': null,
          'message': 'No provider request found'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to fetch request status'
        };
      }
    } catch (e) {
      print('Error in getProviderRequestStatus: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Submit Provider Request - FIXED ENDPOINT
  static Future<Map<String, dynamic>> submitProviderRequest(
      ProviderRegistrationRequest request, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/providers/become-provider'), // FIXED: Changed from submit-request
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      print('Submit Provider Request Response Status: ${response.statusCode}');
      print('Submit Provider Request Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Provider request submitted successfully'
        };
      } else if (response.statusCode == 409) {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Conflict: Request already exists',
          'isConflict': true
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to submit provider request'
        };
      }
    } catch (e) {
      print('Error in submitProviderRequest: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Update Provider Request - FIXED ENDPOINT
  static Future<Map<String, dynamic>> updateProviderRequest(
      Map<String, dynamic> updates, String token) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/providers/provider-request'), // FIXED: Changed from update-request
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(updates),
      );

      print('Update Provider Request Response Status: ${response.statusCode}');
      print('Update Provider Request Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Provider request updated successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to update provider request'
        };
      }
    } catch (e) {
      print('Error in updateProviderRequest: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }

  // Cancel Provider Request - FIXED ENDPOINT
  static Future<Map<String, dynamic>> cancelProviderRequest(String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/providers/provider-request'), // FIXED: Changed from cancel-request
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Cancel Provider Request Response Status: ${response.statusCode}');
      print('Cancel Provider Request Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
          'message': 'Provider request cancelled successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'data': null,
          'message': errorData['message'] ?? 'Failed to cancel provider request'
        };
      }
    } catch (e) {
      print('Error in cancelProviderRequest: $e');
      return {
        'success': false,
        'data': null,
        'message': 'Network error: ${e.toString()}'
      };
    }
  }
}