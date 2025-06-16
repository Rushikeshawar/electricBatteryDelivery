// lib/providers/provider_providers.dart - Corrected with better error handling
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/provider_models.dart';
import '../services/provider_service.dart';
import 'login_provider.dart';

// Provider Request Status Provider
final providerRequestStatusProvider = FutureProvider<ProviderRequestStatus?>((ref) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderRequestStatus(token);
    
    if (result['success']) {
      return result['data'] as ProviderRequestStatus?;
    } else {
      // If no request found, return null instead of throwing error
      if (result['message']?.contains('not found') == true) {
        return null;
      }
      throw Exception(result['message']);
    }
  } catch (e) {
    // Return null for 404 errors (no request found)
    if (e.toString().contains('404') || e.toString().contains('not found')) {
      return null;
    }
    throw Exception('Failed to get provider request status: ${e.toString()}');
  }
});

// Provider Profile Provider (for approved providers)
final providerProfileProvider = FutureProvider<ProviderProfile?>((ref) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderProfile(token);
    
    if (result['success']) {
      return result['data'] as ProviderProfile?;
    } else {
      throw Exception(result['message']);
    }
  } catch (e) {
    throw Exception('Failed to get provider profile: ${e.toString()}');
  }
});

// Provider Slots Provider
final providerSlotsProvider = FutureProvider<List<ProviderSlot>>((ref) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderSlots(token);
    
    if (result['success']) {
      return result['data'] as List<ProviderSlot>;
    } else {
      throw Exception(result['message']);
    }
  } catch (e) {
    throw Exception('Failed to get provider slots: ${e.toString()}');
  }
});

// Fixed: Create stable parameters class for bookings
class BookingsParameters {
  final int page;
  final int limit;
  final String? status;
  final String? date;

  const BookingsParameters({
    this.page = 1,
    this.limit = 10,
    this.status,
    this.date,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingsParameters &&
          runtimeType == other.runtimeType &&
          page == other.page &&
          limit == other.limit &&
          status == other.status &&
          date == other.date;

  @override
  int get hashCode => Object.hash(page, limit, status, date);

  @override
  String toString() => 'BookingsParameters(page: $page, limit: $limit, status: $status, date: $date)';
}

// Provider Bookings Provider - Fixed to use stable parameters
final providerBookingsProvider = FutureProvider.family<List<ProviderBooking>, BookingsParameters>((ref, params) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderBookings(
      token,
      page: params.page,
      limit: params.limit,
      status: params.status,
      date: params.date,
    );
    
    if (result['success']) {
      return result['data'] as List<ProviderBooking>;
    } else {
      throw Exception(result['message']);
    }
  } catch (e) {
    throw Exception('Failed to get provider bookings: ${e.toString()}');
  }
});

// Provider Analytics Provider
final providerAnalyticsProvider = FutureProvider<ProviderAnalytics?>((ref) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderAnalytics(token);
    
    if (result['success']) {
      return result['data'] as ProviderAnalytics?;
    } else {
      throw Exception(result['message']);
    }
  } catch (e) {
    throw Exception('Failed to get provider analytics: ${e.toString()}');
  }
});

// Enhanced Provider Registration State Notifier with Better Conflict Handling
class ProviderRegistrationNotifier extends StateNotifier<AsyncValue<String?>> {
  ProviderRegistrationNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> submitProviderRequest(ProviderRegistrationRequest request) async {
    state = const AsyncValue.loading();
    
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.submitProviderRequest(request, token);
      
      if (result['success']) {
        state = const AsyncValue.data('Provider request submitted successfully');
        // Refresh the request status
        ref.invalidate(providerRequestStatusProvider);
        return true;
      } else {
        // Handle different types of errors
        String errorMessage = result['message'] ?? 'Failed to submit provider request';
        
        // Check for conflict scenarios
        if (result['isConflict'] == true || 
            result.containsKey('isConflict') ||
            errorMessage.toLowerCase().contains('already') ||
            errorMessage.toLowerCase().contains('exists') ||
            errorMessage.toLowerCase().contains('conflict')) {
          // This is a 409 conflict - user already has a request
          errorMessage = 'You already have a provider request. Please check your status.';
          state = AsyncValue.error('CONFLICT: $errorMessage', StackTrace.current);
        } else {
          state = AsyncValue.error(errorMessage, StackTrace.current);
        }
        
        return false;
      }
    } catch (e) {
      String errorMessage = e.toString();
      
      // Check if it's a conflict error in the exception
      if (errorMessage.contains('409') || 
          errorMessage.toLowerCase().contains('conflict') ||
          errorMessage.toLowerCase().contains('already have')) {
        errorMessage = 'CONFLICT: You already have a provider request. Please check your status.';
      }
      
      state = AsyncValue.error(errorMessage, StackTrace.current);
      return false;
    }
  }

  Future<bool> updateProviderRequest(Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.updateProviderRequest(updates, token);
      
      if (result['success']) {
        state = const AsyncValue.data('Provider request updated successfully');
        // Refresh the request status
        ref.invalidate(providerRequestStatusProvider);
        return true;
      } else {
        state = AsyncValue.error(result['message'], StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> cancelProviderRequest() async {
    state = const AsyncValue.loading();
    
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.cancelProviderRequest(token);
      
      if (result['success']) {
        state = const AsyncValue.data('Provider request cancelled successfully');
        // Refresh the request status
        ref.invalidate(providerRequestStatusProvider);
        return true;
      } else {
        state = AsyncValue.error(result['message'], StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final providerRegistrationProvider = StateNotifierProvider<ProviderRegistrationNotifier, AsyncValue<String?>>((ref) {
  return ProviderRegistrationNotifier(ref);
});

// Provider Management State Notifier (for approved providers)
class ProviderManagementNotifier extends StateNotifier<AsyncValue<String?>> {
  ProviderManagementNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> updateProviderProfile(Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.updateProviderProfile(updates, token);
      
      if (result['success']) {
        state = const AsyncValue.data('Provider profile updated successfully');
        // Refresh the provider profile
        ref.invalidate(providerProfileProvider);
        return true;
      } else {
        state = AsyncValue.error(result['message'], StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> updateProviderSlots(List<ProviderSlot> slots) async {
    state = const AsyncValue.loading();
    
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.updateProviderSlots(slots, token);
      
      if (result['success']) {
        state = const AsyncValue.data('Provider slots updated successfully');
        // Refresh the provider slots
        ref.invalidate(providerSlotsProvider);
        return true;
      } else {
        state = AsyncValue.error(result['message'], StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> toggleSlotAvailability(String slotId, bool isAvailable) async {
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.toggleSlotAvailability(slotId, isAvailable, token);
      
      if (result['success']) {
        // Refresh the provider slots
        ref.invalidate(providerSlotsProvider);
        return true;
      } else {
        state = AsyncValue.error(result['message'], StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status, {double? actualAmount}) async {
    try {
      final token = ref.read(loginProvider).user.token;
      final result = await ProviderService.updateBookingStatus(bookingId, status, token, actualAmount: actualAmount);
      
      if (result['success']) {
        // Only invalidate specific providers to avoid infinite loops
        ref.invalidate(providerAnalyticsProvider);
        // Don't invalidate all booking providers, just refresh specific ones if needed
        return true;
      } else {
        state = AsyncValue.error(result['message'], StackTrace.current);
        return false;
      }
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return false;
    }
  }

  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final providerManagementProvider = StateNotifierProvider<ProviderManagementNotifier, AsyncValue<String?>>((ref) {
  return ProviderManagementNotifier(ref);
});

// Helper provider to check if user is a provider
final isProviderProvider = Provider<bool>((ref) {
  final requestStatus = ref.watch(providerRequestStatusProvider);
  return requestStatus.when(
    data: (status) => status?.status == 'APPROVED',
    loading: () => false,
    error: (_, __) => false,
  );
});

// Helper provider to check if user has a pending provider request
final hasPendingProviderRequestProvider = Provider<bool>((ref) {
  final requestStatus = ref.watch(providerRequestStatusProvider);
  return requestStatus.when(
    data: (status) => status?.status == 'PENDING',
    loading: () => false,
    error: (_, __) => false,
  );
});

// Helper provider to check if user has a rejected provider request
final hasRejectedProviderRequestProvider = Provider<bool>((ref) {
  final requestStatus = ref.watch(providerRequestStatusProvider);
  return requestStatus.when(
    data: (status) => status?.status == 'REJECTED',
    loading: () => false,
    error: (_, __) => false,
  );
});

// Provider status provider that returns the current status string
final providerStatusProvider = Provider<String?>((ref) {
  final requestStatus = ref.watch(providerRequestStatusProvider);
  return requestStatus.when(
    data: (status) => status?.status,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Fixed: Provider to get recent bookings (last 5) - using stable parameters
final recentProviderBookingsProvider = FutureProvider<List<ProviderBooking>>((ref) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderBookings(
      token,
      page: 1,
      limit: 5,
    );
    
    if (result['success']) {
      return result['data'] as List<ProviderBooking>;
    } else {
      throw Exception(result['message']);
    }
  } catch (e) {
    throw Exception('Failed to get recent bookings: ${e.toString()}');
  }
});

// Fixed: Provider to get pending bookings count - using stable parameters
final pendingBookingsCountProvider = FutureProvider<int>((ref) async {
  try {
    final token = ref.read(loginProvider).user.token;
    final result = await ProviderService.getProviderBookings(
      token,
      page: 1,
      limit: 100, // Get more to count properly
      status: 'PENDING',
    );
    
    if (result['success']) {
      final bookings = result['data'] as List<ProviderBooking>;
      return bookings.length;
    } else {
      return 0;
    }
  } catch (e) {
    return 0;
  }
});

// Provider to check if user can access provider features
final canAccessProviderFeaturesProvider = Provider<bool>((ref) {
  final isProvider = ref.watch(isProviderProvider);
  final hasPending = ref.watch(hasPendingProviderRequestProvider);
  final hasRejected = ref.watch(hasRejectedProviderRequestProvider);
  
  return isProvider || hasPending || hasRejected;
});

// Enhanced provider request existence checker
final hasAnyProviderRequestProvider = Provider<bool>((ref) {
  final requestStatus = ref.watch(providerRequestStatusProvider);
  return requestStatus.when(
    data: (status) => status != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Provider request conflict checker
final hasProviderRequestConflictProvider = Provider<bool>((ref) {
  final registrationState = ref.watch(providerRegistrationProvider);
  return registrationState.when(
    data: (_) => false,
    loading: () => false,
    error: (error, _) => error.toString().contains('CONFLICT'),
  );
});

// Provider registration form state
class ProviderRegistrationFormState {
  final String? businessName;
  final String chargerType;
  final List<String> vehicleTypes;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? hourlyRate;
  final String description;
  final List<String> amenities;
  final String contactNumber;
  final bool isValid;

  const ProviderRegistrationFormState({
    this.businessName,
    this.chargerType = 'Type 2 AC',
    this.vehicleTypes = const [],
    this.address = '',
    this.latitude,
    this.longitude,
    this.hourlyRate,
    this.description = '',
    this.amenities = const [],
    this.contactNumber = '',
    this.isValid = false,
  });

  ProviderRegistrationFormState copyWith({
    String? businessName,
    String? chargerType,
    List<String>? vehicleTypes,
    String? address,
    double? latitude,
    double? longitude,
    double? hourlyRate,
    String? description,
    List<String>? amenities,
    String? contactNumber,
    bool? isValid,
  }) {
    return ProviderRegistrationFormState(
      businessName: businessName ?? this.businessName,
      chargerType: chargerType ?? this.chargerType,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      description: description ?? this.description,
      amenities: amenities ?? this.amenities,
      contactNumber: contactNumber ?? this.contactNumber,
      isValid: isValid ?? this.isValid,
    );
  }

  ProviderRegistrationRequest toRequest() {
    return ProviderRegistrationRequest(
      businessName: businessName?.isEmpty == true ? null : businessName,
      chargerType: chargerType,
      vehicleTypes: vehicleTypes,
      address: address,
      latitude: latitude!,
      longitude: longitude!,
      hourlyRate: hourlyRate!,
      description: description,
      amenities: amenities.isEmpty ? null : amenities,
      contactNumber: contactNumber,
    );
  }

  bool get canSubmit {
    return vehicleTypes.isNotEmpty &&
           address.isNotEmpty &&
           latitude != null &&
           longitude != null &&
           hourlyRate != null &&
           hourlyRate! > 0 &&
           description.isNotEmpty &&
           contactNumber.isNotEmpty;
  }
}

// Provider registration form state notifier
class ProviderRegistrationFormNotifier extends StateNotifier<ProviderRegistrationFormState> {
  ProviderRegistrationFormNotifier() : super(const ProviderRegistrationFormState());

  void updateBusinessName(String? businessName) {
    state = state.copyWith(businessName: businessName);
  }

  void updateChargerType(String chargerType) {
    state = state.copyWith(chargerType: chargerType);
  }

  void updateVehicleTypes(List<String> vehicleTypes) {
    state = state.copyWith(vehicleTypes: vehicleTypes);
  }

  void updateAddress(String address) {
    state = state.copyWith(address: address);
  }

  void updateCoordinates(double latitude, double longitude) {
    state = state.copyWith(latitude: latitude, longitude: longitude);
  }

  void updateHourlyRate(double? hourlyRate) {
    state = state.copyWith(hourlyRate: hourlyRate);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updateAmenities(List<String> amenities) {
    state = state.copyWith(amenities: amenities);
  }

  void updateContactNumber(String contactNumber) {
    state = state.copyWith(contactNumber: contactNumber);
  }

  void reset() {
    state = const ProviderRegistrationFormState();
  }
}

final providerRegistrationFormProvider = StateNotifierProvider<ProviderRegistrationFormNotifier, ProviderRegistrationFormState>((ref) {
  return ProviderRegistrationFormNotifier();
});

// Helper providers for quick status checks
final isProviderApprovedProvider = Provider<bool>((ref) {
  return ref.watch(providerStatusProvider) == 'APPROVED';
});

final isProviderPendingProvider = Provider<bool>((ref) {
  return ref.watch(providerStatusProvider) == 'PENDING';
});

final isProviderRejectedProvider = Provider<bool>((ref) {
  return ref.watch(providerStatusProvider) == 'REJECTED';
});

// Provider that automatically refreshes request status
final autoRefreshProviderStatusProvider = StateNotifierProvider<AutoRefreshNotifier, bool>((ref) {
  return AutoRefreshNotifier(ref);
});

class AutoRefreshNotifier extends StateNotifier<bool> {
  final Ref ref;
  
  AutoRefreshNotifier(this.ref) : super(false);

  void refreshProviderStatus() {
    state = true;
    ref.invalidate(providerRequestStatusProvider);
    
    // Reset the refresh flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        state = false;
      }
    });
  }

  void forceRefresh() {
    ref.invalidate(providerRequestStatusProvider);
    ref.invalidate(providerProfileProvider);
    ref.invalidate(providerAnalyticsProvider);
  }
}