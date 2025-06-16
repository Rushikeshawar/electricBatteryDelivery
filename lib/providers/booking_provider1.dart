// lib/providers/booking_provider.dart - Fixed for actual API structure
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/models/booking_model.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart' show TimeSlot;
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

class BookingState {
  final bool isLoading;
  final bool isBooking;
  final List<Booking> bookings;
  final List<TimeSlot> availableSlots;
  final String? errorMessage;
  final BasicPagination? pagination;
  final int currentPage;
  final bool hasReachedEnd;

  const BookingState({
    this.isLoading = false,
    this.isBooking = false,
    this.bookings = const [],
    this.availableSlots = const [],
    this.errorMessage,
    this.pagination,
    this.currentPage = 1,
    this.hasReachedEnd = false,
  });

  BookingState copyWith({
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
    return BookingState(
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

class BookingNotifier extends StateNotifier<BookingState> {
  final Ref _ref;
  bool _disposed = false;

  BookingNotifier(this._ref) : super(const BookingState());

  void _safeUpdateState(BookingState Function(BookingState) updater) {
    if (!_disposed && mounted) {
      try {
        state = updater(state);
      } catch (e) {
        debugPrint('Error updating booking state: $e');
      }
    }
  }

  // Updated to use the provider details endpoint which includes slots
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
      
      // Use the provider details endpoint which includes slots
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/providers/$providerId')
          .replace(queryParameters: {'date': dateString});

      debugPrint('Loading available slots from: $uri');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (_disposed) return;

      debugPrint('Available slots response status: ${response.statusCode}');
      debugPrint('Available slots response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final providerData = jsonData['data'];
          final slotsData = providerData['slots'] as List<dynamic>? ?? [];
          
          // If no slots are defined, create default time slots
          List<TimeSlot> slots = [];
          
          if (slotsData.isEmpty) {
            // Generate default time slots from 9 AM to 6 PM
            slots = _generateDefaultTimeSlots();
          } else {
            // Parse existing slots from API
            slots = slotsData
                .map((slot) => TimeSlot.fromJson(slot))
                .toList();
          }

          _safeUpdateState((state) => state.copyWith(
            availableSlots: slots,
            isLoading: false,
          ));
        } else {
          _safeUpdateState((state) => state.copyWith(
            availableSlots: [],
            isLoading: false,
            errorMessage: 'No provider data found',
          ));
        }
      } else {
        String errorMessage = 'Failed to load available slots';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }

        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: errorMessage,
        ));
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error loading available slots: $e');
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: 'Error: ${e.toString()}',
        ));
      }
    }
  }

  // Generate default time slots when none are provided by the API
  List<TimeSlot> _generateDefaultTimeSlots() {
    final List<TimeSlot> slots = [];
    
    for (int hour = 9; hour < 18; hour++) {
      final startTime = '${hour.toString().padLeft(2, '0')}:00';
      final endTime = '${(hour + 1).toString().padLeft(2, '0')}:00';
      
      slots.add(TimeSlot(
        id: hour, // Use hour as ID for default slots
        startTime: startTime,
        endTime: endTime,
        isAvailable: hour != 12 && hour != 15, // Make some slots unavailable for demo
        price: 50.0, // Default price
        chargerType: 'Type 2 AC', // Add required chargerType
      ));
    }
    
    return slots;
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

      final bookingRequest = {
        'providerId': providerId,
        'slotId': slotId,
        'bookingDate': bookingDate.toIso8601String().split('T')[0],
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber.isNotEmpty ? vehicleNumber : null,
        'specialNotes': specialNotes.isNotEmpty ? specialNotes : null,
      };

      // CORRECTED: Use the providers/bookings endpoint
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings');

      debugPrint('Creating booking at: $uri');
      debugPrint('Booking request: ${json.encode(bookingRequest)}');

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(bookingRequest),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (_disposed) return null;

      debugPrint('Create booking response status: ${response.statusCode}');
      debugPrint('Create booking response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        
        // Handle successful booking creation
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final booking = Booking.fromJson(jsonData['data']);
          
          _safeUpdateState((state) => state.copyWith(
            isBooking: false,
          ));

          return booking;
        } else {
          throw Exception('Invalid booking response format');
        }
      } else {
        String errorMessage = 'Failed to create booking';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }

        _safeUpdateState((state) => state.copyWith(
          isBooking: false,
          errorMessage: errorMessage,
        ));

        throw Exception(errorMessage);
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error creating booking: $e');
        _safeUpdateState((state) => state.copyWith(
          isBooking: false,
          errorMessage: 'Error: ${e.toString()}',
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

      // CORRECTED: Use the providers/bookings endpoint
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings')
          .replace(queryParameters: queryParams);

      debugPrint('Loading user bookings from: $uri');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (_disposed) return;

      debugPrint('User bookings response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          List<Booking> bookings = [];
          BasicPagination? pagination;
          
          if (jsonData['data'] is List) {
            bookings = (jsonData['data'] as List<dynamic>)
                .map((booking) => Booking.fromJson(booking))
                .toList();
          }
          
          if (jsonData['pagination'] != null) {
            pagination = BasicPagination.fromJson(jsonData['pagination']);
          }

          if (refresh || page == 1) {
            _safeUpdateState((state) => state.copyWith(
              bookings: bookings,
              pagination: pagination,
              isLoading: false,
              currentPage: page,
              hasReachedEnd: bookings.length < limit,
            ));
          } else {
            final existingIds = state.bookings.map((b) => b.id).toSet();
            final newBookings = bookings
                .where((b) => !existingIds.contains(b.id))
                .toList();

            _safeUpdateState((state) => state.copyWith(
              bookings: [...state.bookings, ...newBookings],
              pagination: pagination,
              isLoading: false,
              currentPage: page,
              hasReachedEnd: newBookings.length < limit,
            ));
          }
        } else {
          _safeUpdateState((state) => state.copyWith(
            isLoading: false,
            bookings: [],
          ));
        }
      } else {
        String errorMessage = 'Failed to load bookings';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }

        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: errorMessage,
        ));
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error loading user bookings: $e');
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: 'Error: ${e.toString()}',
        ));
      }
    }
  }

  Future<bool> cancelBooking(int bookingId, {String? reason}) async {
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

      // CORRECTED: Use the providers/bookings endpoint
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings/$bookingId/cancel');

      final body = reason != null ? {'reason': reason} : <String, dynamic>{};

      debugPrint('Cancelling booking at: $uri');

      final response = await http.patch(
        uri, 
        headers: headers,
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      debugPrint('Cancel booking response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true) {
          final updatedBookings = state.bookings.map((booking) {
            if (booking.id == bookingId) {
              return booking.copyWith(
                status: 'CANCELLED',
                updatedAt: DateTime.now(),
              );
            }
            return booking;
          }).toList();

          _safeUpdateState((state) => state.copyWith(
            bookings: updatedBookings,
          ));

          return true;
        }
      }
      
      String errorMessage = 'Failed to cancel booking';
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
      } catch (e) {
        errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
      }

      _safeUpdateState((state) => state.copyWith(
        errorMessage: errorMessage,
      ));
      return false;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      _safeUpdateState((state) => state.copyWith(
        errorMessage: 'Error: ${e.toString()}',
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

      // CORRECTED: Use the providers/bookings endpoint
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings/$bookingId');

      debugPrint('Loading booking details from: $uri');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      debugPrint('Booking details response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          return Booking.fromJson(jsonData['data']);
        }
        throw Exception('Invalid booking details response format');
      } else {
        String errorMessage = 'Failed to load booking details';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error loading booking details: $e');
      throw Exception('Error loading booking details: ${e.toString()}');
    }
  }

  void clearBookings() {
    _safeUpdateState((state) => state.copyWith(
      bookings: [],
      clearError: true,
      currentPage: 1,
      hasReachedEnd: false,
    ));
  }

  void clearAvailableSlots() {
    _safeUpdateState((state) => state.copyWith(
      availableSlots: [],
      clearError: true,
    ));
  }

  void clearError() {
    _safeUpdateState((state) => state.copyWith(clearError: true));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// Provider for booking notifier
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(ref);
});