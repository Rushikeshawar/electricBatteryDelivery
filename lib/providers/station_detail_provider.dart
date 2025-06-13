import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// State class to manage station details state
class StationDetailState {
  final Station station;
  final Battery? selectedBattery;
  final bool isLoading;
  final List<StationProduct> products; // Added products list
  final String? errorMessage; // Added error message field

  StationDetailState({
    required this.station,
    this.selectedBattery,
    this.isLoading = false,
    this.products = const [], // Initialize with empty list
    this.errorMessage,
  });

  // Create a copy of the current state with some values changed
  StationDetailState copyWith({
    Station? station,
    Battery? selectedBattery,
    bool? isLoading,
    List<StationProduct>? products,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StationDetailState(
      station: station ?? this.station,
      selectedBattery: selectedBattery ?? this.selectedBattery,
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// New StationProduct model to represent products from the API
class StationProduct {
  final int id;
  final String name;
  final String description;
  final String batteryType;
  final String capacity;
  final String voltage;
  final double price;
  final int stockQuantity;
  final Map<String, dynamic> specifications;
  final bool isActive;
  final int stationId;
  final String createdAt;
  final String updatedAt;

  StationProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.batteryType,
    required this.capacity,
    required this.voltage,
    required this.price,
    required this.stockQuantity,
    required this.specifications,
    required this.isActive,
    required this.stationId,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert product to Battery model for compatibility with existing UI
  Battery toBattery() {
    return Battery(
      id: id,
      type: batteryType,
      description: description,
      price: price,
      availableQuantity: stockQuantity,
      voltage: double.tryParse(voltage.replaceAll('V', '')) ?? 0.0,
      capacity: double.tryParse(capacity.replaceAll('Ah', '')) ?? 0.0,
      imageUrl: "",  // No image in the API data
    );
  }

  // Factory to create a StationProduct from JSON
  factory StationProduct.fromJson(Map<String, dynamic> json) {
    return StationProduct(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Product',
      description: json['description'] ?? 'No description available',
      batteryType: json['batteryType'] ?? 'Standard',
      capacity: json['capacity'] ?? '0Ah',
      voltage: json['voltage'] ?? '0V',
      price: (json['price'] is num) ? json['price'].toDouble() : 0.0,
      stockQuantity: json['stockQuantity'] ?? 0,
      specifications: json['specifications'] ?? {},
      isActive: json['isActive'] ?? false,
      stationId: json['stationId'] ?? 0,
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toString(),
    );
  }
}

// Provider notifier to handle station detail operations
class StationDetailNotifier extends StateNotifier<StationDetailState> {
  final Ref _ref; // Added Ref to access other providers

  StationDetailNotifier(this._ref, Station station) 
      : super(StationDetailState(
          station: station,
          selectedBattery: station.availableBatteryTypes.isNotEmpty 
              ? station.availableBatteryTypes.first 
              : null,
        ));

  // Initialize the state - can be used for fetching fresh data in the future
  Future<void> initialize() async {
    // Set loading state
    state = state.copyWith(isLoading: true);
    
    // Fetch station products from API
    await fetchStationProducts();
    
    // If no batteries available after API call, add demo batteries
    if (state.products.isEmpty && state.station.availableBatteryTypes.isEmpty) {
      // Create a copy of the station with demo batteries
      Station updatedStation = state.station;
      updatedStation = Station(
        id: updatedStation.id,
        name: updatedStation.name,
        address: updatedStation.address,
        managerName: updatedStation.managerName,
        email: updatedStation.email,
        phone: updatedStation.phone,
        latitude: updatedStation.latitude,
        longitude: updatedStation.longitude,
        isActive: updatedStation.isActive,
        createdAt: updatedStation.createdAt,
        updatedAt: updatedStation.updatedAt,
        status: updatedStation.status,
        etaMinutes: updatedStation.etaMinutes,
        availableBatteries: 3, // Set to match the number of demo batteries
        batteryCapacity: updatedStation.batteryCapacity,
        price: updatedStation.price,
        imageUrl: updatedStation.imageUrl,
        features: updatedStation.features,
        // Add demo batteries
        availableBatteryTypes: [
          Battery(
            id: 1,
            type: "Lithium-Ion 48V Standard",
            description: "Standard capacity battery for everyday use",
            price: 1000,
            availableQuantity: 8,
            voltage: 48.0,
            capacity: 20.0,
            imageUrl: "",
          ),

      
        ],
      );
      
      // Update the state with the new station that includes batteries
      state = state.copyWith(
        station: updatedStation, 
        selectedBattery: updatedStation.availableBatteryTypes.first,
        isLoading: false,
      );
    } else if (state.products.isNotEmpty) {
      // If products were loaded from API, convert them to Battery objects
      final List<Battery> batteries = state.products.map((product) => product.toBattery()).toList();
      
      // Create updated station with batteries from products
      final updatedStation = Station(
        id: state.station.id,
        name: state.station.name,
        address: state.station.address,
        managerName: state.station.managerName,
        email: state.station.email,
        phone: state.station.phone,
        latitude: state.station.latitude,
        longitude: state.station.longitude,
        isActive: state.station.isActive,
        createdAt: state.station.createdAt,
        updatedAt: state.station.updatedAt,
        status: state.station.status,
        etaMinutes: state.station.etaMinutes,
        availableBatteries: batteries.length,
        batteryCapacity: state.station.batteryCapacity,
        price: state.station.price,
        imageUrl: state.station.imageUrl,
        features: state.station.features,
        availableBatteryTypes: batteries,
      );
      
      // Update state with station that includes batteries from API
      state = state.copyWith(
        station: updatedStation,
        selectedBattery: batteries.isNotEmpty ? batteries.first : null,
        isLoading: false,
      );
    } else {
      // Just update loading state if batteries are already present
      state = state.copyWith(isLoading: false);
    }
  }

  // New function to fetch station products from API
  Future<void> fetchStationProducts() async {
    try {
      // Get auth token from loginProvider
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        // User might not be logged in, proceed without token
        state = state.copyWith(
          errorMessage: 'Authentication required. Please log in.',
        );
        return;
      }
      
      // If no token is available, we can't make authenticated requests
      if (token == null) {
        state = state.copyWith(
          errorMessage: 'Authentication token not found. Please log in again.',
        );
        return;
      }
      
      // Set up headers with authorization token
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Build URL to fetch products for this station
      final url = Uri.parse('${ApiConfig.stationsUrl}/${state.station.id}/products');
      
      // Make the API call
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          // Parse products from the response
          final List<StationProduct> products = (jsonData['data'] as List)
              .map((productData) => StationProduct.fromJson(productData))
              .toList();
          
          // Update state with the products
          state = state.copyWith(
            products: products,
            clearError: true,
          );
        } else {
          throw Exception('Invalid data format from API');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load station products');
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Error loading station products: ${e.toString()}',
      );
    }
  }

  // Select a battery
  void selectBattery(Battery battery) {
    state = state.copyWith(selectedBattery: battery);
  }

  // Check if the battery is available for booking
  bool canBookBattery() {
    return state.selectedBattery != null && 
           state.selectedBattery!.availableQuantity > 0;
  }
}

// Provider for station detail state - updated to include Ref
final stationDetailProvider = StateNotifierProvider.family<StationDetailNotifier, StationDetailState, Station>(
  (ref, station) => StationDetailNotifier(ref, station),
);

// Convenience provider to check if booking is available
final canBookProvider = Provider.family<bool, Station>((ref, station) {
  final state = ref.watch(stationDetailProvider(station));
  return state.selectedBattery != null && 
         state.selectedBattery!.availableQuantity > 0;
});