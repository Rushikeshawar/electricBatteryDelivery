import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// Define the state for the payment provider
class PaymentState {
  final bool isProcessing;
  final String? errorMessage;
  final bool useCurrentLocation;
  final Position? currentPosition;
  final LatLng? selectedLocation;
  final String selectedAddress;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String selectedPaymentMethod;
  final List<String> availablePaymentMethods;
  final Map<String, dynamic>? pricingData;
  final bool isPaymentSuccessful;

  PaymentState({
    this.isProcessing = false,
    this.errorMessage,
    this.useCurrentLocation = false,
    this.currentPosition,
    this.selectedLocation,
    this.selectedAddress = '',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.selectedPaymentMethod = 'razorpay',
    this.availablePaymentMethods = const ['razorpay', 'cod'],
    this.pricingData,
    this.isPaymentSuccessful = false,
  });

  PaymentState copyWith({
    bool? isProcessing,
    String? errorMessage,
    bool clearError = false,
    bool? useCurrentLocation,
    Position? currentPosition,
    LatLng? selectedLocation,
    String? selectedAddress,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? selectedPaymentMethod,
    List<String>? availablePaymentMethods,
    Map<String, dynamic>? pricingData,
    bool? isPaymentSuccessful,
  }) {
    return PaymentState(
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      useCurrentLocation: useCurrentLocation ?? this.useCurrentLocation,
      currentPosition: currentPosition ?? this.currentPosition,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      razorpayOrderId: razorpayOrderId ?? this.razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpaySignature: razorpaySignature ?? this.razorpaySignature,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      availablePaymentMethods: availablePaymentMethods ?? this.availablePaymentMethods,
      pricingData: pricingData ?? this.pricingData,
      isPaymentSuccessful: isPaymentSuccessful ?? this.isPaymentSuccessful,
    );
  }
}

// Define the notifier for the payment provider
class PaymentNotifier extends StateNotifier<PaymentState> {
  final Ref _ref;
  late Razorpay _razorpay;
  Completer<void>? _paymentCompleter; // Make it nullable and recreatable

  PaymentNotifier(this._ref) : super(PaymentState()) {
    _initializeRazorpay();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('Payment Success: ${response.paymentId}');
    state = state.copyWith(
      razorpayPaymentId: response.paymentId,
      razorpayOrderId: response.orderId,
      razorpaySignature: response.signature,
      isPaymentSuccessful: true,
      isProcessing: false,
      clearError: true,
    );
    
    _completePayment();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('Payment Error: ${response.code} - ${response.message}');
    state = state.copyWith(
      isProcessing: false,
      isPaymentSuccessful: false,
      errorMessage: 'Payment failed: ${response.message ?? 'Unknown error'}',
    );
    
    _completePayment();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External Wallet: ${response.walletName}');
    state = state.copyWith(
      isProcessing: false,
      errorMessage: 'External wallet payments are not supported currently',
    );
    
    _completePayment();
  }

  // Helper method to safely complete payment
  void _completePayment() {
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete();
    }
  }

  void setUseCurrentLocation(bool value) {
    state = state.copyWith(useCurrentLocation: value);
  }

  void setSelectedLocation(LatLng location, String address) {
    state = state.copyWith(
      selectedLocation: location,
      selectedAddress: address,
    );
  }

  void setSelectedPaymentMethod(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            errorMessage: 'Location permissions are denied',
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          errorMessage: 'Location permissions are permanently denied, cannot request permissions.',
        );
        return;
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      state = state.copyWith(
        currentPosition: position,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to get current location: ${e.toString()}',
      );
    }
  }

  // Get delivery coordinates based on user selection
  Map<String, double> getDeliveryCoordinates(BatteryBooking booking) {
    if (state.useCurrentLocation && state.currentPosition != null) {
      return {
        'latitude': state.currentPosition!.latitude,
        'longitude': state.currentPosition!.longitude,
      };
    } else if (state.selectedLocation != null) {
      return {
        'latitude': state.selectedLocation!.latitude,
        'longitude': state.selectedLocation!.longitude,
      };
    } else {
      return {
        'latitude': booking.deliveryLatitude,
        'longitude': booking.deliveryLongitude,
      };
    }
  }

  // Get delivery address based on user selection
  String getDeliveryAddress(BatteryBooking booking) {
    if (state.selectedLocation != null && state.selectedAddress.isNotEmpty) {
      return state.selectedAddress;
    } else {
      return booking.deliveryAddress;
    }
  }

  // Fetch pricing from backend
  Future<Map<String, dynamic>?> fetchPricing({
    required int productId,
    required int quantity,
  }) async {
    try {
      final token = _ref.read(loginProvider).user.token;
      
      final response = await http.post(
        Uri.parse(ApiConfig.calculatePricingUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'productId': productId,
          'quantity': quantity,
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          state = state.copyWith(pricingData: data['data']);
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to calculate pricing');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to calculate pricing: ${e.toString()}',
      );
      return null;
    }
  }

  // Create Razorpay order on backend
  Future<Map<String, dynamic>?> _createRazorpayOrder({
    required int stationId,
    required int productId,
    required int quantity,
    required Map<String, dynamic> notes,
  }) async {
    try {
      final token = _ref.read(loginProvider).user.token;
      
      final response = await http.post(
        Uri.parse(ApiConfig.createRazorpayOrderUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'stationId': stationId,
          'productId': productId,
          'quantity': quantity,
          'notes': notes,
        }),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to create payment order');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating Razorpay order: $e');
      throw Exception('Failed to create payment order: ${e.toString()}');
    }
  }

  // Verify payment on backend
  Future<bool> _verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final token = _ref.read(loginProvider).user.token;
      
      final response = await http.post(
        Uri.parse(ApiConfig.verifyRazorpayPaymentUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        }),
      ).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['verified'] == true;
      }
      
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  // Process payment and create order
  Future<Map<String, dynamic>?> processPayment({
    required Station station,
    required Battery battery,
    required BatteryBooking booking,
  }) async {
    state = state.copyWith(isProcessing: true, clearError: true);
    
    try {
      // Get delivery coordinates and address
      final coordinates = getDeliveryCoordinates(booking);
      final deliveryAddress = getDeliveryAddress(booking);

      if (state.selectedPaymentMethod == 'razorpay') {
        return await _processRazorpayPayment(
          station: station,
          battery: battery,
          booking: booking,
          coordinates: coordinates,
          deliveryAddress: deliveryAddress,
        );
      } else if (state.selectedPaymentMethod == 'cod') {
        return await _processCODOrder(
          station: station,
          battery: battery,
          booking: booking,
          coordinates: coordinates,
          deliveryAddress: deliveryAddress,
        );
      } else {
        throw Exception('Invalid payment method selected');
      }
    } catch (e) {
      print('Error processing payment: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Payment processing failed: ${e.toString()}',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _processRazorpayPayment({
    required Station station,
    required Battery battery,
    required BatteryBooking booking,
    required Map<String, double> coordinates,
    required String deliveryAddress,
  }) async {
    try {
      final user = _ref.read(loginProvider).user;
      
      // Reset payment state
      state = state.copyWith(
        isPaymentSuccessful: false,
        razorpayPaymentId: null,
        razorpayOrderId: null,
        razorpaySignature: null,
        clearError: true,
      );
      
      // Create Razorpay order
      final razorpayOrderData = await _createRazorpayOrder(
        stationId: station.id,
        productId: battery.id,
        quantity: booking.quantity,
        notes: {
          'delivery_address': deliveryAddress,
          'delivery_latitude': coordinates['latitude'].toString(),
          'delivery_longitude': coordinates['longitude'].toString(),
          'delivery_notes': booking.deliveryNotes,
        },
      );

      if (razorpayOrderData == null) {
        throw Exception('Failed to create payment order');
      }

      // Create new completer for this payment
      _paymentCompleter = Completer<void>();

      // Configure Razorpay options
      var options = {
        'key': ApiConfig.razorpayKeyId,
        'amount': razorpayOrderData['amount'],
        'name': 'BatteryWala',
        'description': '${battery.type} x${booking.quantity} from ${station.name}',
        'order_id': razorpayOrderData['id'],
        'prefill': {
          'contact': user.phoneNumber,
          'email': user.email,
          'name': user.name,
        },
        'theme': {
          'color': '#4CAF50',
        },
      };

      print('Opening Razorpay with options: $options');

      // Open Razorpay checkout
      _razorpay.open(options);

      // Wait for payment completion with timeout
      await _paymentCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          state = state.copyWith(
            isProcessing: false,
            errorMessage: 'Payment timeout - please try again',
          );
          throw Exception('Payment timeout');
        },
      );

      // Check if payment was successful
      if (!state.isPaymentSuccessful) {
        // Don't throw exception here, just return null to handle gracefully
        print('Payment was not successful');
        return null;
      }

      // Verify payment
      if (state.razorpayPaymentId != null && 
          state.razorpayOrderId != null && 
          state.razorpaySignature != null) {
        
        print('Verifying payment...');
        final verified = await _verifyPayment(
          razorpayOrderId: state.razorpayOrderId!,
          razorpayPaymentId: state.razorpayPaymentId!,
          razorpaySignature: state.razorpaySignature!,
        );

        if (!verified) {
          throw Exception('Payment verification failed');
        }

        print('Payment verified successfully, creating order...');
        // Create order after successful payment
        return await _createOrderInDatabase(
          station: station,
          battery: battery,
          booking: booking,
          coordinates: coordinates,
          deliveryAddress: deliveryAddress,
          paymentMethod: 'razorpay',
          paymentId: state.razorpayPaymentId!,
          razorpayOrderId: state.razorpayOrderId!,
          razorpaySignature: state.razorpaySignature!,
        );
      } else {
        throw Exception('Payment details are incomplete');
      }
    } catch (e) {
      print('Error in _processRazorpayPayment: $e');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _processCODOrder({
    required Station station,
    required Battery battery,
    required BatteryBooking booking,
    required Map<String, double> coordinates,
    required String deliveryAddress,
  }) async {
    try {
      // For COD, directly create the order
      return await _createOrderInDatabase(
        station: station,
        battery: battery,
        booking: booking,
        coordinates: coordinates,
        deliveryAddress: deliveryAddress,
        paymentMethod: 'cod',
        paymentId: 'COD-${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> _createOrderInDatabase({
    required Station station,
    required Battery battery,
    required BatteryBooking booking,
    required Map<String, double> coordinates,
    required String deliveryAddress,
    required String paymentMethod,
    required String paymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
  }) async {
    try {
      final token = _ref.read(loginProvider).user.token;
      
      // Prepare order data
      final orderData = {
        "stationId": station.id,
        "productId": battery.id,
        "batteryType": battery.type,
        "quantity": booking.quantity,
        "deliveryAddress": deliveryAddress,
        "deliveryLatitude": coordinates['latitude'],
        "deliveryLongitude": coordinates['longitude'],
        "deliveryNotes": booking.deliveryNotes,
        "paymentMethod": paymentMethod,
        "paymentId": paymentId,
      };

      // Add Razorpay specific fields if available
      if (razorpayOrderId != null) {
        orderData["razorpayOrderId"] = razorpayOrderId;
      }
      if (razorpaySignature != null) {
        orderData["razorpaySignature"] = razorpaySignature;
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      print('Creating order with data: $orderData');
      
      final response = await http.post(
        Uri.parse(ApiConfig.ordersUrl),
        headers: headers,
        body: json.encode(orderData),
      ).timeout(ApiConfig.requestTimeout);
      
      state = state.copyWith(isProcessing: false);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          print('Order created successfully: ${jsonData['data']}');
          return jsonData;
        } else {
          throw Exception(jsonData['error'] ?? 'Failed to create order');
        }
      } else {
        print('Server error: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when creating order: ${e.toString()}');
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Failed to create order: ${e.toString()}',
      );
      return null;
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    // Complete any pending payment completer
    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      _paymentCompleter!.complete();
    }
    super.dispose();
  }
}

// Define the payment provider
final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((ref) {
  return PaymentNotifier(ref);
});