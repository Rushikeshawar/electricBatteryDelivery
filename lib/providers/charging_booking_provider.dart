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
      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/providers/$providerId/slots')
          .replace(queryParameters: {'date': dateString});

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (_disposed) return;

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
        throw Exception('Failed to load available slots');
      }
    } catch (e) {
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: 'Error: ${e.toString()}',
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

      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings');

      final response = await http.post(
        uri,
        headers: headers,
        body: json.encode(bookingRequest.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (_disposed) return null;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        final bookingResponse = BookingResponse.fromJson(jsonData);

        _safeUpdateState((state) => state.copyWith(isBooking: false));
        return bookingResponse.data;
      } else {
        throw Exception('Failed to create booking');
      }
    } catch (e) {
      if (!_disposed) {
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

      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
      );

      if (_disposed) return;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final bookingsResponse = BookingsResponse.fromJson(jsonData);

        if (refresh || page == 1) {
          _safeUpdateState((state) => state.copyWith(
            bookings: bookingsResponse.data,
            pagination: bookingsResponse.pagination,
            isLoading: false,
            currentPage: page,
            hasReachedEnd: bookingsResponse.data.length < limit,
          ));
        } else {
          final existingIds = state.bookings.map((b) => b.id).toSet();
          final newBookings = bookingsResponse.data
              .where((b) => !existingIds.contains(b.id))
              .toList();

          _safeUpdateState((state) => state.copyWith(
            bookings: [...state.bookings, ...newBookings],
            pagination: bookingsResponse.pagination,
            isLoading: false,
            currentPage: page,
            hasReachedEnd: newBookings.length < limit,
          ));
        }
      } else {
        throw Exception('Failed to load bookings');
      }
    } catch (e) {
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          errorMessage: 'Error: ${e.toString()}',
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

      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings/$bookingId/cancel');

      final response = await http.patch(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

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
        throw Exception('Failed to cancel booking');
      }
    } catch (e) {
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

      final uri = Uri.parse('${ApiConfig.baseUrl}/providers/bookings/$bookingId');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final bookingResponse = BookingResponse.fromJson(jsonData);
        return bookingResponse.data;
      } else {
        throw Exception('Failed to load booking details');
      }
    } catch (e) {
      throw Exception('Error loading booking details: ${e.toString()}');
    }
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