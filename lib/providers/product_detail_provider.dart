import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import '../models/product_model.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// State class to manage product details state
class ProductDetailState {
  final BatteryProduct product;
  final Station? station;
  final Battery? selectedBattery;
  final bool isLoading;

  ProductDetailState({
    required this.product,
    this.station,
    this.selectedBattery,
    this.isLoading = false,
  });

  // Create a copy of the current state with some values changed
  ProductDetailState copyWith({
    BatteryProduct? product,
    Station? station,
    Battery? selectedBattery,
    bool? isLoading,
  }) {
    return ProductDetailState(
      product: product ?? this.product,
      station: station ?? this.station,
      selectedBattery: selectedBattery ?? this.selectedBattery,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Provider notifier to handle product detail operations
class ProductDetailNotifier extends StateNotifier<ProductDetailState> {
  ProductDetailNotifier(BatteryProduct product) 
      : super(ProductDetailState(
          product: product,
          selectedBattery: null,
        ));

  // Initialize the state - fetch station details if needed
  Future<void> initialize() async {
    // Set loading state
    state = state.copyWith(isLoading: true);
    
    // In a real app, you might need to fetch additional product details or station info
    // For now, we'll just simulate a delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Create a Station object from product.station if available
    Station? station;
    if (state.product.station != null) {
      station = Station(
        id: state.product.station!.id,
        name: state.product.station!.name,
        address: state.product.station!.address,
        managerName: '', // Not provided in product station data
        email: '',
        phone: '',
        latitude: state.product.station!.latitude,
        longitude: state.product.station!.longitude,
        isActive: true,
        createdAt: '',
        updatedAt: '',
        status: 'Available',
        etaMinutes: 15, // Default value
        availableBatteries: 1,
        batteryCapacity: state.product.capacity,
        price: state.product.price,
      );
    }
    
    // Create a Battery from the product for consistency with the station detail screen
    final battery = Battery(
      id: state.product.id,
      type: state.product.batteryType,
      description: state.product.description,
      price: state.product.price,
      availableQuantity: state.product.stockQuantity,
      voltage: double.tryParse(state.product.voltage.replaceAll('V', '')) ?? 0.0,
      capacity: double.tryParse(state.product.capacity.replaceAll('Ah', '')) ?? 0.0,
      imageUrl: '',
    );
    
    // Update state with station and battery
    state = state.copyWith(
      station: station,
      selectedBattery: battery,
      isLoading: false,
    );
  }

  // Check if the product is available for booking
  bool canBookProduct() {
    return state.product.stockQuantity > 0 && state.product.isActive;
  }
}

// Provider for product detail state
final productDetailProvider = StateNotifierProvider.family<ProductDetailNotifier, ProductDetailState, BatteryProduct>(
  (ref, product) => ProductDetailNotifier(product),
);

// Convenience provider to check if booking is available
final canBookProductProvider = Provider.family<bool, BatteryProduct>((ref, product) {
  final state = ref.watch(productDetailProvider(product));
  return state.product.stockQuantity > 0 && state.product.isActive;
});