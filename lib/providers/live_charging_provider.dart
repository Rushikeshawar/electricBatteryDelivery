// lib/providers/live_charging_provider.dart
import 'dart:math' as math; // Add this import for sin, cos, sqrt functions
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart';
import 'package:electric_battery_delivery_frontend/services/charging_provider_api_service.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart'; // Add this import

// State for charging providers
class ChargingProviderState {
  final bool isLoading;
  final List<ChargingProvider> providers;
  final ChargingProvider? selectedProvider;
  final String? errorMessage;
  final int currentPage;
  final bool hasMoreData;
  final Map<String, dynamic>? lastSearchParams;
  final bool isAuthenticated;

  const ChargingProviderState({
    this.isLoading = false,
    this.providers = const [],
    this.selectedProvider,
    this.errorMessage,
    this.currentPage = 1,
    this.hasMoreData = true,
    this.lastSearchParams,
    this.isAuthenticated = false,
  });

  ChargingProviderState copyWith({
    bool? isLoading,
    List<ChargingProvider>? providers,
    ChargingProvider? selectedProvider,
    String? errorMessage,
    int? currentPage,
    bool? hasMoreData,
    Map<String, dynamic>? lastSearchParams,
    bool? isAuthenticated,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return ChargingProviderState(
      isLoading: isLoading ?? this.isLoading,
      providers: providers ?? this.providers,
      selectedProvider: clearSelected ? null : (selectedProvider ?? this.selectedProvider),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      hasMoreData: hasMoreData ?? this.hasMoreData,
      lastSearchParams: lastSearchParams ?? this.lastSearchParams,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// Live API notifier with authentication
class LiveChargingProviderNotifier extends StateNotifier<ChargingProviderState> {
  final Ref _ref;

  LiveChargingProviderNotifier(this._ref) : super(const ChargingProviderState());

  Future<void> loadProvidersNearLocation({
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
    bool refresh = false,
  }) async {
    // Store search parameters for potential refresh/pagination
    final searchParams = {
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'chargerType': chargerType,
      'vehicleType': vehicleType,
      'minRating': minRating,
      'maxRate': maxRate,
      'amenities': amenities,
      'limit': limit,
    };

    // If refreshing or first page, show loading and clear previous data
    if (refresh || page == 1) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        providers: [],
        currentPage: 1,
        hasMoreData: true,
        lastSearchParams: searchParams,
      );
    } else {
      // For pagination, just set loading without clearing data
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final newProviders = await ChargingProviderApiService.findNearbyProviders(
        ref: _ref, // Pass the ref for authentication
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        chargerType: chargerType,
        vehicleType: vehicleType,
        minRating: minRating,
        maxRate: maxRate,
        amenities: amenities,
        page: page,
        limit: limit,
      );

      // Calculate distances if not provided by API
      final providersWithDistance = newProviders.map((provider) {
        if (provider.distance == 0.0) {
          // Calculate distance using basic formula
          final distance = _calculateDistance(
            latitude, longitude,
            provider.latitude, provider.longitude,
          );
          return ChargingProvider(
            id: provider.id,
            businessName: provider.businessName,
            address: provider.address,
            latitude: provider.latitude,
            longitude: provider.longitude,
            distance: distance,
            rating: provider.rating,
            totalSlots: provider.totalSlots,
            availableSlots: provider.availableSlots,
            ratePerHour: provider.ratePerHour,
            fastCharging: provider.fastCharging,
            isOpen: provider.isOpen,
            description: provider.description,
            images: provider.images,
            amenities: provider.amenities,
            reviews: provider.reviews,
            phoneNumber: provider.phoneNumber,
            operatingHours: provider.operatingHours,
          );
        }
        return provider;
      }).toList();

      List<ChargingProvider> allProviders;
      if (page == 1 || refresh) {
        allProviders = providersWithDistance;
      } else {
        // Append to existing providers for pagination
        allProviders = [...state.providers, ...providersWithDistance];
      }

      state = state.copyWith(
        isLoading: false,
        providers: allProviders,
        currentPage: page,
        hasMoreData: newProviders.length >= limit,
        lastSearchParams: searchParams,
        isAuthenticated: true, // Successfully made authenticated request
      );

    } catch (e) {
      print('Error loading providers: $e');
      
      // Check if this is an authentication error
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Access forbidden')) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Authentication required. Please login to view charging providers.',
          isAuthenticated: false,
        );
      } else {
        // Show error but keep existing data if this was a pagination request
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> loadProviderDetails(dynamic providerId, {String? date}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final provider = await ChargingProviderApiService.getProviderDetails(
        ref: _ref, // Pass the ref for authentication
        providerId: providerId,
        date: date,
      );
      
      state = state.copyWith(
        isLoading: false,
        selectedProvider: provider,
        isAuthenticated: true,
      );
    } catch (e) {
      print('Error loading provider details: $e');
      
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Access forbidden')) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Authentication required. Please login to view provider details.',
          isAuthenticated: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  Future<void> loadMoreProviders() async {
    if (state.isLoading || !state.hasMoreData || state.lastSearchParams == null) {
      return;
    }

    final params = state.lastSearchParams!;
    await loadProvidersNearLocation(
      latitude: params['latitude'],
      longitude: params['longitude'],
      radius: params['radius'] ?? 10.0,
      chargerType: params['chargerType'],
      vehicleType: params['vehicleType'],
      minRating: params['minRating'],
      maxRate: params['maxRate'],
      amenities: params['amenities'],
      page: state.currentPage + 1,
      limit: params['limit'] ?? 20,
    );
  }

  Future<void> refreshProviders() async {
    if (state.lastSearchParams == null) return;

    final params = state.lastSearchParams!;
    await loadProvidersNearLocation(
      latitude: params['latitude'],
      longitude: params['longitude'],
      radius: params['radius'] ?? 10.0,
      chargerType: params['chargerType'],
      vehicleType: params['vehicleType'],
      minRating: params['minRating'],
      maxRate: params['maxRate'],
      amenities: params['amenities'],
      page: 1,
      limit: params['limit'] ?? 20,
      refresh: true,
    );
  }

  // Booking related methods with authentication
  Future<Map<String, dynamic>> createBooking({
    required int providerId,
    required int slotId,
    required String bookingDate,
    required String vehicleType,
    String? vehicleNumber,
    String? specialNotes,
  }) async {
    try {
      return await ChargingProviderApiService.createBooking(
        ref: _ref, // Pass the ref for authentication
        providerId: providerId,
        slotId: slotId,
        bookingDate: bookingDate,
        vehicleType: vehicleType,
        vehicleNumber: vehicleNumber,
        specialNotes: specialNotes,
      );
    } catch (e) {
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Access forbidden')) {
        throw Exception('Authentication required. Please login to create bookings.');
      }
      throw Exception('Failed to create booking: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserBookings({
    int page = 1,
    int limit = 10,
    String? status,
    bool upcoming = false,
  }) async {
    try {
      return await ChargingProviderApiService.getUserBookings(
        ref: _ref, // Pass the ref for authentication
        page: page,
        limit: limit,
        status: status,
        upcoming: upcoming,
      );
    } catch (e) {
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Access forbidden')) {
        throw Exception('Authentication required. Please login to view bookings.');
      }
      throw Exception('Failed to load bookings: $e');
    }
  }

  Future<Map<String, dynamic>> cancelBooking({
    required dynamic bookingId,
    String? reason,
  }) async {
    try {
      return await ChargingProviderApiService.cancelBooking(
        ref: _ref, // Pass the ref for authentication
        bookingId: bookingId,
        reason: reason,
      );
    } catch (e) {
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Access forbidden')) {
        throw Exception('Authentication required. Please login to cancel bookings.');
      }
      throw Exception('Failed to cancel booking: $e');
    }
  }

  Future<Map<String, dynamic>> addReview({
    required dynamic providerId,
    required int rating,
    required String comment,
    dynamic bookingId,
  }) async {
    try {
      return await ChargingProviderApiService.addProviderReview(
        ref: _ref, // Pass the ref for authentication
        providerId: providerId,
        rating: rating,
        comment: comment,
        bookingId: bookingId,
      );
    } catch (e) {
      if (e.toString().contains('Authentication failed') || 
          e.toString().contains('Access forbidden')) {
        throw Exception('Authentication required. Please login to add reviews.');
      }
      throw Exception('Failed to add review: $e');
    }
  }

  // Utility methods
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearSelectedProvider() {
    state = state.copyWith(clearSelected: true);
  }

  // Fixed distance calculation with proper math functions
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    // Fixed: Use math.sin, math.cos, math.sqrt
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Check authentication status
  bool get isAuthenticated => state.isAuthenticated;
  
  // Get login status from login provider
  bool get isLoggedIn {
    try {
      final loginState = _ref.read(loginProvider);
      return loginState.user.token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

// Provider - replace your existing chargingProviderProvider with this
final chargingProviderProvider = StateNotifierProvider<LiveChargingProviderNotifier, ChargingProviderState>((ref) {
  return LiveChargingProviderNotifier(ref);
});