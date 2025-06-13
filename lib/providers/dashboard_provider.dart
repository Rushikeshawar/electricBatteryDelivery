import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/components/dummy.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// Dashboard state class to hold all the state information
class DashboardState {
  final bool isLoading;
  final List<Station> stations;
  final List<Station> availableStations;
  final String searchQuery;
  final String selectedFilter;
  final TextEditingController searchController;
  final AnimationController? animationController;
  final Position? userLocation;
  final String? errorMessage;

  DashboardState({
    required this.isLoading,
    required this.stations,
    required this.availableStations,
    required this.searchQuery,
    required this.selectedFilter,
    required this.searchController,
    this.animationController,
    this.userLocation,
    this.errorMessage,
  });

  // Create a copy of the current state with some values changed
  DashboardState copyWith({
    bool? isLoading,
    List<Station>? stations,
    List<Station>? availableStations,
    String? searchQuery,
    String? selectedFilter,
    TextEditingController? searchController,
    AnimationController? animationController,
    Position? userLocation,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      stations: stations ?? this.stations,
      availableStations: availableStations ?? this.availableStations,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchController: searchController ?? this.searchController,
      animationController: animationController ?? this.animationController,
      userLocation: userLocation ?? this.userLocation,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  // Return filtered stations based on search query and selected filter
  List<Station> get filteredStations {
    return stations.where((station) {
      // Apply search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return station.name.toLowerCase().contains(query) ||
            station.address.toLowerCase().contains(query);
      }

      // Apply filters
      switch (selectedFilter) {
        case 'Available':
          return station.status.toLowerCase() == 'available';
        default:
          return true;
      }
    }).toList();
  }
}

// Dashboard notifier class to handle state changes
class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;
  
  DashboardNotifier(this._ref)
      : super(
          DashboardState(
            isLoading: true,
            stations: [],
            availableStations: [],
            searchQuery: '',
            selectedFilter: 'All',
            searchController: TextEditingController(),
          ),
        );

  // Initialize the dashboard - load stations
  Future<void> initDashboard(TickerProvider vsync) async {
    // Create animation controller
    final animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: vsync,
    );

    // Update state with the animation controller
    state = state.copyWith(animationController: animationController);

    // Get user location first
    await getUserLocation();
    
    // Then load stations based on location
    if (state.userLocation != null) {
      await loadStations();
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to get location. Please check permissions and try again.',
      );
    }
  }
  
  // Get user's current location
  Future<void> getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          errorMessage: 'Location services are disabled. Please enable them to find nearby stations.',
          isLoading: false,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            errorMessage: 'Location permissions are denied. Please allow access to find nearby stations.',
            isLoading: false,
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          errorMessage: 'Location permissions are permanently denied. Please enable them in settings.',
          isLoading: false,
        );
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      state = state.copyWith(userLocation: position, clearError: true);
    } catch (e) {
      // Make the fallback more transparent to the user
      state = state.copyWith(
        errorMessage: 'Error getting location: ${e.toString()}. Using default location instead.',
      );
      
      // Fallback to a default location (Pune in this case)
      state = state.copyWith(
        userLocation: Position(
          latitude: 18.5204, 
          longitude: 73.8567,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
    }
  }

  // Load stations from API
  Future<void> loadStations() async {
    if (state.userLocation == null) {
      // If location is not available, load dummy data as fallback
      state = state.copyWith(
        errorMessage: 'Unable to get location. Loading example stations instead.',
      );
      await _loadDummyStations();
      return;
    }
    
    try {
      // Get auth token if user is logged in
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        // User might not be logged in yet, proceed without token
      }
      
      // Set up headers
      final headers = {
        'Content-Type': 'application/json',
      };
      
      // Add authorization header if token is available
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Build URL with location parameters
      final url = Uri.parse('${ApiConfig.stationsUrl}?latitude=${state.userLocation!.latitude}&longitude=${state.userLocation!.longitude}&radius=10');
      
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final stations = _parseStations(jsonData['data']);
          
          // Filter available stations
          final availableStations = stations
              .where((station) => station.status.toLowerCase() == 'available')
              .toList();
          
          state = state.copyWith(
            stations: stations,
            availableStations: availableStations,
            isLoading: false,
            clearError: true,
          );
          
          // Start animation
          state.animationController?.forward();
        } else {
          throw Exception('Invalid data format from API');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load stations');
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error loading stations: ${e.toString()}. Loading example stations instead.',
      );
      
      // Load dummy data as fallback
      await _loadDummyStations();
    }
  }
  
  // Parse API response into Station objects
  List<Station> _parseStations(List<dynamic> data) {
    return data.map((stationData) {
      return Station(
        id: stationData['id'] ?? 0,
        name: stationData['name'] ?? 'Unknown Station',
        address: stationData['address'] ?? 'No address provided',
        managerName: stationData['managerName'] ?? 'Unknown Manager',
        email: stationData['email'] ?? 'email@example.com',
        phone: stationData['phone'] ?? '123-456-7890',
        latitude: stationData['latitude'] ?? 0.0,
        longitude: stationData['longitude'] ?? 0.0,
        isActive: stationData['isActive'] ?? true,
        createdAt: stationData['createdAt'] ?? DateTime.now().toString(),
        updatedAt: stationData['updatedAt'] ?? DateTime.now().toString(),
        status: stationData['status'] ?? 'Available',
        etaMinutes: stationData['etaMinutes'] ?? calculateETA(stationData),
        availableBatteries: stationData['availableBatteries'] ?? 5,
        batteryCapacity: stationData['batteryCapacity'] ?? '5000 mAh',
        price: stationData['price']?.toDouble() ?? 299.0,
        imageUrl: stationData['imageUrl'] ?? '',
        features: stationData['features'] ?? {},
        availableBatteryTypes: parseAvailableBatteryTypes(stationData),
      );
    }).toList();
  }
  
  // Calculate ETA based on distance
  int calculateETA(Map<String, dynamic> stationData) {
    // If distance is provided by API, calculate ETA based on that
    if (stationData['distance'] != null) {
      // Assuming average speed of 30 km/h for delivery
      final double distance = stationData['distance'] is int 
          ? stationData['distance'].toDouble() 
          : stationData['distance'];
      
      // Convert distance to minutes (at 30 km/h, 1 km takes 2 minutes)
      return (distance * 2).round();
    }
    
    // Default ETA if distance is not available
    return 15;
  }
  
  // Parse battery types from API data
  List<Battery> parseAvailableBatteryTypes(Map<String, dynamic> stationData) {
    if (stationData['availableBatteryTypes'] is List) {
      return (stationData['availableBatteryTypes'] as List).map((batteryData) {
        return Battery(
          id: batteryData['id'] ?? 0,
          type: batteryData['type'] ?? 'Standard',
          description: batteryData['description'] ?? 'Standard battery',
          price: batteryData['price']?.toDouble() ?? 299.0,
          availableQuantity: batteryData['availableQuantity'] ?? 5,
          voltage: batteryData['voltage']?.toDouble() ?? 48.0,
          capacity: batteryData['capacity']?.toDouble() ?? 15.0,
          imageUrl: batteryData['imageUrl'] ?? '',
        );
      }).toList();
    }
    
    // Return empty list if no battery types are provided
    return [];
  }

  // Load dummy stations as fallback
  Future<void> _loadDummyStations() async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    final stations = DummyData.stations;
    final availableStations = stations
        .where((station) => station.status.toLowerCase() == 'available')
        .toList();
    
    state = state.copyWith(
      stations: stations,
      availableStations: availableStations,
      isLoading: false,
    );
    
    // Start animation
    state.animationController?.forward();
  }

  // Update search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  // Update selected filter
  void updateSelectedFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  // Clear search
  void clearSearch() {
    state.searchController.clear();
    state = state.copyWith(searchQuery: '');
  }

  // Refresh stations (e.g., after pull-to-refresh)
  Future<void> refreshStations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    // First get location and wait for it to complete
    await getUserLocation();
    
    // Then load stations only if location was successful or fallback was applied
    if (state.userLocation != null) {
      await loadStations();
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to get location. Please check permissions and try again.',
      );
    }
  }

  // Dispose resources
  @override
  void dispose() {
    state.searchController.dispose();
    state.animationController?.dispose();
    super.dispose();
  }
}

// Provider for dashboard state
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});

// Provider for available filters
final filtersProvider = Provider<List<String>>((ref) {
  return ['All', 'Available'];
});

// Provider for the current user info (simplified)
final userInfoProvider = Provider<Map<String, String>>((ref) {
  // First try to get from login provider
  try {
    final user = ref.read(loginProvider).user;
    return {
      'userName': user.name,
      'userEmail': user.email,
      'phoneNumber': user.phoneNumber ?? '+1234567890',
    };
  } catch (e) {
    // Fallback to default values if not logged in
    return {
      'userName': 'User',
      'userEmail': 'user@example.com',
      'phoneNumber': '+1234567890',
    };
  }
});