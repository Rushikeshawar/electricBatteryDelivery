// lib/providers/simple_charging_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/models/charging_provider_model.dart';

// Simple state for charging providers
class SimpleChargingProviderState {
  final bool isLoading;
  final List<ChargingProvider> providers;
  final ChargingProvider? selectedProvider;
  final String? errorMessage;

  const SimpleChargingProviderState({
    this.isLoading = false,
    this.providers = const [],
    this.selectedProvider,
    this.errorMessage,
  });

  SimpleChargingProviderState copyWith({
    bool? isLoading,
    List<ChargingProvider>? providers,
    ChargingProvider? selectedProvider,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SimpleChargingProviderState(
      isLoading: isLoading ?? this.isLoading,
      providers: providers ?? this.providers,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Simple notifier
class SimpleChargingProviderNotifier extends StateNotifier<SimpleChargingProviderState> {
  SimpleChargingProviderNotifier() : super(const SimpleChargingProviderState());

  // Add method to load sample data for testing
  void loadSampleData() {
    final sampleProviders = _generateSampleProviders();
    
    state = state.copyWith(
      providers: sampleProviders,
      isLoading: false,
      clearError: true,
    );
  }

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
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Generate mock data based on location
      final mockProviders = _generateLocationBasedProviders(latitude, longitude);
      
      state = state.copyWith(
        isLoading: false,
        providers: mockProviders,
      );
    } catch (e) {
      // Handle error and load sample data as fallback
      print('Error loading providers: $e');
      
      state = state.copyWith(
        isLoading: false,
        providers: _generateSampleProviders(),
        errorMessage: 'Using sample data due to connection error',
      );
    }
  }

  Future<void> loadProviderDetails(dynamic providerId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Convert providerId to int if it's a string
    int id;
    if (providerId is String) {
      id = int.tryParse(providerId) ?? 1;
    } else {
      id = providerId as int;
    }
    
    // Find provider from existing list or create mock
    ChargingProvider? provider;
    try {
      provider = state.providers.firstWhere((p) => p.id == id);
    } catch (e) {
      // If not found, create a mock provider
      provider = ChargingProvider(
        id: id,
        businessName: 'PowerPoint Provider $id',
        address: 'Sample Address, Pimpri-Chinchwad',
        latitude: 18.5204,
        longitude: 73.8567,
        distance: 2.0,
        rating: 4.0,
        totalSlots: 6,
        availableSlots: 4,
        ratePerHour: 100.0,
        fastCharging: false,
        isOpen: true,
        description: 'A reliable charging station',
        images: ['https://images.unsplash.com/photo-1593941707882-a5bac6861d75?w=300&h=150&fit=crop'],
        amenities: ['Parking', 'WiFi'],
        reviews: [],
        phoneNumber: '+91 9876543212',
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
    }
    
    state = state.copyWith(
      isLoading: false,
      selectedProvider: provider,
    );
  }

  // Helper method to generate sample providers
  List<ChargingProvider> _generateSampleProviders() {
    return [
      ChargingProvider(
        id: 1,
        businessName: 'PowerPoint Station Alpha',
        address: 'Shop No. 15, Pimpri Market, Pimpri-Chinchwad, Maharashtra 411018',
        latitude: 18.6298,
        longitude: 73.7997,
        distance: 0.5,
        rating: 4.5,
        totalSlots: 6,
        availableSlots: 3,
        ratePerHour: 25.0,
        fastCharging: true,
        isOpen: true,
        description: 'Premium charging station with all modern amenities',
        images: [
          'https://images.unsplash.com/photo-1593941707882-a5bac6861d75?w=300&h=150&fit=crop',
        ],
        amenities: ['WiFi', 'Parking', 'Restroom', 'Cafe'],
        reviews: [],
        phoneNumber: '+91 98765 43210',
        operatingHours: {
          'monday': '6:00 AM - 11:00 PM',
          'tuesday': '6:00 AM - 11:00 PM',
          'wednesday': '6:00 AM - 11:00 PM',
          'thursday': '6:00 AM - 11:00 PM',
          'friday': '6:00 AM - 11:00 PM',
          'saturday': '6:00 AM - 11:00 PM',
          'sunday': '7:00 AM - 10:00 PM',
        },
      ),
      ChargingProvider(
        id: 2,
        businessName: 'EV Hub Beta',
        address: 'Near Railway Station, Station Road, Pimpri, Maharashtra 411018',
        latitude: 18.6350,
        longitude: 73.8000,
        distance: 1.2,
        rating: 4.2,
        totalSlots: 4,
        availableSlots: 0,
        ratePerHour: 20.0,
        fastCharging: false,
        isOpen: true,
        description: 'Convenient location near railway station',
        images: [
          'https://images.unsplash.com/photo-1571068316344-75bc76f77890?w=300&h=150&fit=crop',
        ],
        amenities: ['WiFi', 'Cafe', 'ATM'],
        reviews: [],
        phoneNumber: '+91 98765 43211',
        operatingHours: {
          'monday': '24/7',
          'tuesday': '24/7',
          'wednesday': '24/7',
          'thursday': '24/7',
          'friday': '24/7',
          'saturday': '24/7',
          'sunday': '24/7',
        },
      ),
      ChargingProvider(
        id: 3,
        businessName: 'Green Charge Point',
        address: 'Akurdi Road, Near Phoenix Mall, Pimpri-Chinchwad, Maharashtra 411018',
        latitude: 18.6400,
        longitude: 73.7950,
        distance: 2.1,
        rating: 4.8,
        totalSlots: 8,
        availableSlots: 5,
        ratePerHour: 30.0,
        fastCharging: true,
        isOpen: true,
        description: 'Premium charging facility with shopping complex',
        images: [
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=300&h=150&fit=crop',
        ],
        amenities: ['WiFi', 'Parking', 'Food Court', 'ATM', 'Shopping'],
        reviews: [],
        phoneNumber: '+91 98765 43212',
        operatingHours: {
          'monday': '6:00 AM - 11:00 PM',
          'tuesday': '6:00 AM - 11:00 PM',
          'wednesday': '6:00 AM - 11:00 PM',
          'thursday': '6:00 AM - 11:00 PM',
          'friday': '6:00 AM - 11:00 PM',
          'saturday': '6:00 AM - 11:00 PM',
          'sunday': '7:00 AM - 10:00 PM',
        },
      ),
      ChargingProvider(
        id: 4,
        businessName: 'Quick Charge Express',
        address: 'Chinchwad Road, Near IT Park, Pune, Maharashtra 411019',
        latitude: 18.6280,
        longitude: 73.8100,
        distance: 3.5,
        rating: 4.0,
        totalSlots: 6,
        availableSlots: 2,
        ratePerHour: 22.0,
        fastCharging: true,
        isOpen: true,
        description: 'Fast charging for busy professionals',
        images: [
          'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=300&h=150&fit=crop',
        ],
        amenities: ['WiFi', 'Parking', 'Restroom'],
        reviews: [],
        phoneNumber: '+91 98765 43213',
        operatingHours: {
          'monday': '7:00 AM - 9:00 PM',
          'tuesday': '7:00 AM - 9:00 PM',
          'wednesday': '7:00 AM - 9:00 PM',
          'thursday': '7:00 AM - 9:00 PM',
          'friday': '7:00 AM - 9:00 PM',
          'saturday': '8:00 AM - 8:00 PM',
          'sunday': '8:00 AM - 6:00 PM',
        },
      ),
      ChargingProvider(
        id: 5,
        businessName: 'EcoCharge Station',
        address: 'Bhosari Road, Industrial Area, Pimpri-Chinchwad, Maharashtra 411026',
        latitude: 18.6500,
        longitude: 73.8200,
        distance: 4.8,
        rating: 4.3,
        totalSlots: 10,
        availableSlots: 4,
        ratePerHour: 18.0,
        fastCharging: false,
        isOpen: true,
        description: 'Eco-friendly charging with green surroundings',
        images: [
          'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=300&h=150&fit=crop',
        ],
        amenities: ['WiFi', 'Parking', 'Cafe', 'Garden'],
        reviews: [],
        phoneNumber: '+91 98765 43214',
        operatingHours: {
          'monday': '6:00 AM - 11:00 PM',
          'tuesday': '6:00 AM - 11:00 PM',
          'wednesday': '6:00 AM - 11:00 PM',
          'thursday': '6:00 AM - 11:00 PM',
          'friday': '6:00 AM - 11:00 PM',
          'saturday': '6:00 AM - 11:00 PM',
          'sunday': '7:00 AM - 10:00 PM',
        },
      ),
    ];
  }

  // Helper method to generate location-based providers
  List<ChargingProvider> _generateLocationBasedProviders(double centerLat, double centerLng) {
    final baseProviders = _generateSampleProviders();
    
    // Adjust coordinates based on the center location
    return baseProviders.map((provider) {
      final latOffset = (provider.id % 3 - 1) * 0.01; // -0.01, 0, or 0.01
      final lngOffset = (provider.id % 5 - 2) * 0.01; // -0.02, -0.01, 0, 0.01, or 0.02
      
      return ChargingProvider(
        id: provider.id,
        businessName: provider.businessName,
        address: provider.address,
        latitude: centerLat + latOffset,
        longitude: centerLng + lngOffset,
        distance: provider.distance,
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
    }).toList();
  }

  // Method to handle errors
  void handleError(String error) {
    state = state.copyWith(
      isLoading: false,
      errorMessage: error,
    );
  }

  // Method to clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Method to refresh providers
  Future<void> refreshProviders({
    required double latitude,
    required double longitude,
  }) async {
    await loadProvidersNearLocation(
      latitude: latitude,
      longitude: longitude,
      refresh: true,
    );
  }
}

// Provider
final chargingProviderProvider = StateNotifierProvider<SimpleChargingProviderNotifier, SimpleChargingProviderState>((ref) {
  return SimpleChargingProviderNotifier();
});