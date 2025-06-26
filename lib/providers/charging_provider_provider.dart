// lib/providers/charging_booking_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/models/booking_model.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart' show TimeSlot, PaginationInfo;
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

class ChargingBookingState {
  final bool isLoading;
  final bool isBooking;
  final List<Booking> bookings;
  final List<TimeSlot> availableSlots;
  final String? errorMessage;
  final BasicPagination? pagination;
  final int currentPage;
  final bool hasReachedEnd;

  const ChargingBookingState({
    this.isLoading = false,
    this.isBooking = false,
    this.bookings = const [],
    this.availableSlots = const [],
    this.errorMessage,
    this.pagination,
    this.currentPage = 1,
    this.hasReachedEnd = false,
  });

  ChargingBookingState copyWith({
    bool? isLoading,
    bool? isBooking,
    List<Booking>? bookings,
    List<TimeSlot>? availableSlots,
    String? errorMessage,
    bool clearError = false,
    BasicPagination? pagination,
    int? currentPage,
    bool? hasReachedEnd,
  }) {
    return ChargingBookingState(
      isLoading: isLoading ?? this.isLoading,
      isBooking: isBooking ?? this.isBooking,
      bookings: bookings ?? this.bookings,
      availableSlots: availableSlots ?? this.availableSlots,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pagination: pagination ?? this.pagination,
      currentPage: currentPage ?? this.currentPage,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
    );
  }
}

class ChargingBookingNotifier extends StateNotifier<ChargingBookingState> {
  final Ref _ref;
  bool _disposed = false;

  ChargingBookingNotifier(this._ref) : super(const ChargingBookingState());

  void _safeUpdateState(ChargingBookingState Function(ChargingBookingState) updater) {
    if (!_disposed && mounted) {
      try {
        state = updater(state);
      } catch (e) {
        debugPrint('Error updating charging booking state: $e');
      }
    }
  }

  Future<void> loadAvailableSlots(int providerId, DateTime date) async {
    if (_disposed) return;

    _safeUpdateState((state) => state.copyWith(
      isLoading: true,
      clearError: true,
    ));

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      final dateString = date.toIso8601String().split('T')[0];
      // Fixed: Properly construct URL without duplicate /api
      final baseUrl = ApiConfig.baseUrl.endsWith('/api') 
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 4)
          : ApiConfig.baseUrl;
      
      final uri = Uri.parse('$baseUrl/api/providers/$providerId/slots')
          .replace(queryParameters: {'date': dateString});

      debugPrint('Loading slots from: $uri'); // Debug log

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (_disposed) return;

      debugPrint('Slots response status: ${response.statusCode}'); // Debug log
      debugPrint('Slots response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final slots = (jsonData['data'] as List<dynamic>?)
            ?.map((slot) => TimeSlot.fromJson(slot))
            .toList() ?? [];

        _safeUpdateState((state) => state.copyWith(
          availableSlots: slots,
          isLoading: false,
        ));
      } else {
        final errorMsg = 'Failed to load available slots. Status: ${response.statusCode}';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error loading slots: $e');
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: 'Error loading slots: ${e.toString()}',
        ));
      }
    }
  }

  Future<Booking?> createBooking({
    required int providerId,
    required int slotId,
    required DateTime bookingDate,
    required String vehicleType,
    required String vehicleNumber,
    required String specialNotes,
  }) async {
    if (_disposed) return null;

    _safeUpdateState((state) => state.copyWith(
      isBooking: true,
      clearError: true,
    ));

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      final bookingRequest = BookingRequest(
        providerId: providerId,
        slotId: slotId,
        bookingDate: bookingDate,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        specialNotes: specialNotes,
      );

      // Fixed: Properly construct URL without duplicate /api
      final baseUrl = ApiConfig.baseUrl.endsWith('/api') 
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 4)
          : ApiConfig.baseUrl;
      
      final uri = Uri.parse('$baseUrl/api/providers/bookings');

      debugPrint('Creating booking at: $uri'); // Debug log
      debugPrint('Booking request: ${json.encode(bookingRequest.toJson())}'); // Debug log

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(bookingRequest.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (_disposed) return null;

      debugPrint('Booking response status: ${response.statusCode}'); // Debug log
      debugPrint('Booking response body: ${response.body}'); // Debug log

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        final bookingResponse = BookingResponse.fromJson(jsonData);

        _safeUpdateState((state) => state.copyWith(isBooking: false));
        return bookingResponse.data;
      } else {
        final errorMsg = 'Failed to create booking. Status: ${response.statusCode}';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error creating booking: $e');
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(
          isBooking: false,
          errorMessage: 'Error creating booking: ${e.toString()}',
        ));
        rethrow;
      }
      return null;
    }
  }

  Future<void> loadUserBookings({
    int page = 1,
    int limit = 20,
    String? status,
    bool upcoming = false,
    bool refresh = false,
  }) async {
    if (_disposed) return;

    if (refresh || page == 1) {
      _safeUpdateState((state) => state.copyWith(
        isLoading: true,
        bookings: refresh ? [] : state.bookings,
        clearError: true,
        hasReachedEnd: false,
      ));
    }

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (upcoming) {
        queryParams['upcoming'] = 'true';
      }

      // Fixed: Properly construct URL without duplicate /api
      final baseUrl = ApiConfig.baseUrl.endsWith('/api') 
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 4)
          : ApiConfig.baseUrl;
      
      final uri = Uri.parse('$baseUrl/api/providers/bookings')
          .replace(queryParameters: queryParams);

      debugPrint('Loading bookings from: $uri'); // Debug log

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
      );

      if (_disposed) return;

      debugPrint('Bookings response status: ${response.statusCode}'); // Debug log
      debugPrint('Bookings response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Handle different response formats
        List<Booking> bookingsList;
        BasicPagination? paginationInfo;
        
        if (jsonData is Map<String, dynamic>) {
          if (jsonData.containsKey('data')) {
            // Response format: { "data": [...], "pagination": {...} }
            final bookingsResponse = BookingsResponse.fromJson(jsonData);
            bookingsList = bookingsResponse.data;
            paginationInfo = bookingsResponse.pagination;
          } else if (jsonData.containsKey('bookings')) {
            // Alternative format: { "bookings": [...] }
            bookingsList = (jsonData['bookings'] as List<dynamic>?)
                ?.map((booking) => Booking.fromJson(booking))
                .toList() ?? [];
            
            // Try to extract pagination info if available
            if (jsonData.containsKey('pagination')) {
              try {
                paginationInfo = BasicPagination.fromJson(jsonData['pagination']);
              } catch (e) {
                debugPrint('Error parsing pagination: $e');
              }
            }
          } else {
            // Direct array in data field
            bookingsList = (jsonData as List<dynamic>?)
                ?.map((booking) => Booking.fromJson(booking))
                .toList() ?? [];
          }
        } else if (jsonData is List) {
          // Direct array response
          bookingsList = jsonData
              .map((booking) => Booking.fromJson(booking))
              .toList();
        } else {
          throw Exception('Unexpected response format');
        }

        debugPrint('Loaded ${bookingsList.length} bookings'); // Debug log

        if (refresh || page == 1) {
          _safeUpdateState((state) => state.copyWith(
            bookings: bookingsList,
            pagination: paginationInfo,
            isLoading: false,
            currentPage: page,
            hasReachedEnd: bookingsList.length < limit,
          ));
        } else {
          final existingIds = state.bookings.map((b) => b.id).toSet();
          final newBookings = bookingsList
              .where((b) => !existingIds.contains(b.id))
              .toList();

          _safeUpdateState((state) => state.copyWith(
            bookings: [...state.bookings, ...newBookings],
            pagination: paginationInfo,
            isLoading: false,
            currentPage: page,
            hasReachedEnd: newBookings.length < limit,
          ));
        }
      } else {
        final errorMsg = 'Failed to load bookings. Status: ${response.statusCode}';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: 'Error loading bookings: ${e.toString()}',
        ));
      }
    }
  }

  Future<bool> cancelBooking(int bookingId) async {
    if (_disposed) return false;

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      // Fixed: Properly construct URL without duplicate /api
      final baseUrl = ApiConfig.baseUrl.endsWith('/api') 
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 4)
          : ApiConfig.baseUrl;
      
      final uri = Uri.parse('$baseUrl/api/providers/bookings/$bookingId/cancel');

      debugPrint('Cancelling booking at: $uri'); // Debug log

      final response = await http.patch(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      debugPrint('Cancel response status: ${response.statusCode}'); // Debug log
      debugPrint('Cancel response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final updatedBookings = state.bookings.map((booking) {
          if (booking.id == bookingId) {
            return booking.copyWith(
              status: 'CANCELLED',
              updatedAt: DateTime.now(),
            );
          }
          return booking;
        }).toList();

        _safeUpdateState((state) => state.copyWith(bookings: updatedBookings));
        return true;
      } else {
        final errorMsg = 'Failed to cancel booking. Status: ${response.statusCode}';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      _safeUpdateState((state) => state.copyWith(
        errorMessage: 'Error cancelling booking: ${e.toString()}',
      ));
      return false;
    }
  }

  Future<Booking?> getBookingDetails(int bookingId) async {
    if (_disposed) return null;

    try {
      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      // Fixed: Properly construct URL without duplicate /api
      final baseUrl = ApiConfig.baseUrl.endsWith('/api') 
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 4)
          : ApiConfig.baseUrl;
      
      final uri = Uri.parse('$baseUrl/api/providers/bookings/$bookingId');

      debugPrint('Loading booking details from: $uri'); // Debug log

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      debugPrint('Booking details response status: ${response.statusCode}'); // Debug log
      debugPrint('Booking details response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Handle different response formats
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          final bookingResponse = BookingResponse.fromJson(jsonData);
          return bookingResponse.data;
        } else {
          // Direct booking object
          return Booking.fromJson(jsonData);
        }
      } else {
        final errorMsg = 'Failed to load booking details. Status: ${response.statusCode}';
        debugPrint(errorMsg);
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error loading booking details: $e');
      throw Exception('Error loading booking details: ${e.toString()}');
    }
  }

  // Method to refresh specific booking by ID
  Future<void> refreshBooking(int bookingId) async {
    if (_disposed) return;

    try {
      final updatedBooking = await getBookingDetails(bookingId);
      if (updatedBooking != null) {
        final updatedBookings = state.bookings.map((booking) {
          return booking.id == bookingId ? updatedBooking : booking;
        }).toList();

        _safeUpdateState((state) => state.copyWith(bookings: updatedBookings));
      }
    } catch (e) {
      debugPrint('Error refreshing booking $bookingId: $e');
    }
  }

  // Method to clear error messages
  void clearError() {
    _safeUpdateState((state) => state.copyWith(clearError: true));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// Provider for charging booking notifier
final chargingBookingProvider = StateNotifierProvider<ChargingBookingNotifier, ChargingBookingState>((ref) {
  return ChargingBookingNotifier(ref);
});