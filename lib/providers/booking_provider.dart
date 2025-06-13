import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// State class for booking
class BookingState {
  final Station station;
  final Battery battery;
  final int quantity;
  final double totalPrice;
  final TextEditingController addressController;
  final TextEditingController notesController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;

  BookingState({
    required this.station,
    required this.battery,
    this.quantity = 1,
    required this.totalPrice,
    required this.addressController,
    required this.notesController,
    required this.formKey,
    this.isLoading = false,
  });

  // Create a copy of the current state with some values changed
  BookingState copyWith({
    Station? station,
    Battery? battery,
    int? quantity,
    double? totalPrice,
    TextEditingController? addressController,
    TextEditingController? notesController,
    GlobalKey<FormState>? formKey,
    bool? isLoading,
  }) {
    return BookingState(
      station: station ?? this.station,
      battery: battery ?? this.battery,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      addressController: addressController ?? this.addressController,
      notesController: notesController ?? this.notesController,
      formKey: formKey ?? this.formKey,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // Calculate price summary with delivery and tax
  PriceSummary get priceSummary {
    const deliveryFee = 50.0;
    const taxRate = 0.18; // 18% GST
    
    final subtotal = totalPrice;
    final tax = subtotal * taxRate;
    final total = subtotal + tax + deliveryFee;
    
    return PriceSummary(
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      tax: tax,
      total: total,
    );
  }
}

// A simple class to hold price calculation results
class PriceSummary {
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double total;

  PriceSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
  });
}

// Provider notifier for booking
class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier({
    required Station station,
    required Battery battery,
  }) : super(
          BookingState(
            station: station,
            battery: battery,
            totalPrice: battery.price,
            addressController: TextEditingController(),
            notesController: TextEditingController(),
            formKey: GlobalKey<FormState>(),
          ),
        );

  // Update quantity and recalculate price
  void updateQuantity(int newQuantity) {
    if (newQuantity >= 1 && newQuantity <= state.battery.availableQuantity) {
      final newTotalPrice = state.battery.price * newQuantity;
      state = state.copyWith(
        quantity: newQuantity,
        totalPrice: newTotalPrice,
      );
    }
  }

  // Increment quantity
  void incrementQuantity() {
    updateQuantity(state.quantity + 1);
  }

  // Decrement quantity
  void decrementQuantity() {
    updateQuantity(state.quantity - 1);
  }

  // Create a booking object from current state
  BatteryBooking createBooking() {
    return BatteryBooking(
      stationId: state.station.id,
      batteryType: state.battery.type,
      quantity: state.quantity,
      totalPrice: state.totalPrice,
      deliveryAddress: state.addressController.text,
      deliveryLatitude: state.station.latitude,
      deliveryLongitude: state.station.longitude,
      deliveryNotes: state.notesController.text,
    );
  }

  // Validate form
  bool validateForm() {
    return state.formKey.currentState?.validate() ?? false;
  }

  // Clean up resources
  @override
  void dispose() {
    state.addressController.dispose();
    state.notesController.dispose();
    super.dispose();
  }
}

// Provider for booking state
final bookingProvider = StateNotifierProvider.family<BookingNotifier, BookingState, (Station, Battery)>(
  (ref, params) => BookingNotifier(
    station: params.$1,
    battery: params.$2,
  ),
);

// Convenience provider for price summary
final priceSummaryProvider = Provider.family<PriceSummary, (Station, Battery)>((ref, params) {
  final state = ref.watch(bookingProvider(params));
  return state.priceSummary;
});