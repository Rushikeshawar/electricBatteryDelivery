// providers/product_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/components/models.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// Create a Product model to match the API response
class Product {
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
  final Station? station;
  final String? imageUrl;

  Product({
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
    this.station,
    this.imageUrl,
  });

  // Factory constructor to create a Product from JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Product',
      description: json['description'] ?? 'No description',
      batteryType: json['batteryType'] ?? 'Unknown Type',
      capacity: json['capacity'] ?? '0Ah',
      voltage: json['voltage'] ?? '0V',
      price: json['price']?.toDouble() ?? 0.0,
      stockQuantity: json['stockQuantity'] ?? 0,
      specifications: json['specifications'] ?? {},
      isActive: json['isActive'] ?? false,
      stationId: json['stationId'] ?? 0,
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toString(),
      station: json['station'] != null ? Station(
        id: json['station']['id'] ?? 0,
        name: json['station']['name'] ?? 'Unknown Station',
        address: json['station']['address'] ?? 'No address',
        latitude: json['station']['latitude']?.toDouble() ?? 0.0,
        longitude: json['station']['longitude']?.toDouble() ?? 0.0,
        managerName: '',
        email: '',
        phone: '',
        isActive: true,
        createdAt: '',
        updatedAt: '',
        status: 'Available',
        etaMinutes: 0,
        availableBatteries: 0,
        batteryCapacity: '',
        price: 0,
      ) : null,
      imageUrl: json['imageUrl'],
    );
  }

  // Convert the product to a Battery object (for compatibility)
  Battery toBattery() {
    return Battery(
      id: id,
      type: batteryType,
      description: description,
      price: price,
      availableQuantity: stockQuantity,
      voltage: double.tryParse(voltage.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
      capacity: double.tryParse(capacity.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
      imageUrl: imageUrl ?? '',
    );
  }
}

// Product list state
class ProductListState {
  final bool isLoading;
  final List<Product> products;
  final String? error;
  final Station? station;

  ProductListState({
    required this.isLoading,
    required this.products,
    this.error,
    this.station,
  });

  // Create a copy of the current state with some values changed
  ProductListState copyWith({
    bool? isLoading,
    List<Product>? products,
    String? error,
    bool clearError = false,
    Station? station,
  }) {
    return ProductListState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      error: clearError ? null : (error ?? this.error),
      station: station ?? this.station,
    );
  }
}

// Product detail state
class ProductDetailState {
  final bool isLoading;
  final Product? product;
  final String? error;
  final int quantity;

  ProductDetailState({
    required this.isLoading,
    this.product,
    this.error,
    this.quantity = 1,
  });

  // Create a copy of the current state with some values changed
  ProductDetailState copyWith({
    bool? isLoading,
    Product? product,
    String? error,
    bool clearError = false,
    int? quantity,
  }) {
    return ProductDetailState(
      isLoading: isLoading ?? this.isLoading,
      product: product ?? this.product,
      error: clearError ? null : (error ?? this.error),
      quantity: quantity ?? this.quantity,
    );
  }

  // Calculate total price
  double get totalPrice => (product?.price ?? 0) * quantity;

  // Check if booking is available
  bool get canBook => product != null && product!.isActive && product!.stockQuantity >= quantity;
}

// Product list notifier to handle station products
class ProductListNotifier extends StateNotifier<ProductListState> {
  final Ref _ref;

  ProductListNotifier(this._ref)
      : super(ProductListState(
          isLoading: true,
          products: [],
        ));

  // Fetch products from a specific station
  Future<void> fetchStationProducts(int stationId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get auth token
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
          isLoading: false,
        );
        return;
      }

      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Build URL for station products
      final url = Uri.parse('${ApiConfig.stationsUrl}/$stationId/products');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          // Parse products
          final List<Product> products = (jsonData['data'] as List)
              .map((productData) => Product.fromJson(productData))
              .toList();

          // Parse station data if available
          Station? station;
          if (jsonData['station'] != null) {
            station = Station(
              id: jsonData['station']['id'] ?? 0,
              name: jsonData['station']['name'] ?? 'Unknown Station',
              address: jsonData['station']['address'] ?? 'No address',
              latitude: jsonData['station']['latitude']?.toDouble() ?? 0.0,
              longitude: jsonData['station']['longitude']?.toDouble() ?? 0.0,
              managerName: '',
              email: '',
              phone: '',
              isActive: true,
              createdAt: '',
              updatedAt: '',
              status: 'Available',
              etaMinutes: 0,
              availableBatteries: products.length,
              batteryCapacity: '',
              price: 0,
            );
          }

          state = state.copyWith(
            products: products,
            isLoading: false,
            clearError: true,
            station: station,
          );
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load products');
        }
      } else if (response.statusCode == 401) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
          isLoading: false,
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load products');
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error loading products: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  // Fetch all available products
  Future<void> fetchAllProducts() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get auth token
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
          isLoading: false,
        );
        return;
      }

      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Build URL for all products
      final url = Uri.parse('http://localhost:3000/api/users/products');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          // Parse products
          final List<Product> products = (jsonData['data'] as List)
              .map((productData) => Product.fromJson(productData))
              .toList();

          state = state.copyWith(
            products: products,
            isLoading: false,
            clearError: true,
          );
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load products');
        }
      } else if (response.statusCode == 401) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
          isLoading: false,
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load products');
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error loading products: ${e.toString()}',
        isLoading: false,
      );
    }
  }
}

// Product detail notifier to handle single product
class ProductDetailNotifier extends StateNotifier<ProductDetailState> {
  final Ref _ref;

  ProductDetailNotifier(this._ref)
      : super(ProductDetailState(
          isLoading: true,
        ));

  // Initialize with a product
  void initWithProduct(Product product) {
    state = state.copyWith(
      product: product,
      isLoading: false,
      clearError: true,
      quantity: 1,
    );
  }

  // Fetch product details by ID
  Future<void> fetchProductDetails(int productId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get auth token
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
          isLoading: false,
        );
        return;
      }

      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Build URL for product details
      final url = Uri.parse('http://localhost:3000/api/users/products/$productId');

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true && jsonData['data'] != null) {
          // Parse product
          final product = Product.fromJson(jsonData['data']);

          state = state.copyWith(
            product: product,
            isLoading: false,
            clearError: true,
          );
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to load product details');
        }
      } else if (response.statusCode == 401) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
          isLoading: false,
        );
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load product details');
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error loading product details: ${e.toString()}',
        isLoading: false,
      );
    }
  }

  // Update quantity
  void updateQuantity(int quantity) {
    if (quantity > 0 && quantity <= (state.product?.stockQuantity ?? 0)) {
      state = state.copyWith(quantity: quantity);
    }
  }

  // Increment quantity
  void incrementQuantity() {
    if (state.quantity < (state.product?.stockQuantity ?? 0)) {
      state = state.copyWith(quantity: state.quantity + 1);
    }
  }

  // Decrement quantity
  void decrementQuantity() {
    if (state.quantity > 1) {
      state = state.copyWith(quantity: state.quantity - 1);
    }
  }

  // Book the product (create an order)
  Future<bool> bookProduct() async {
    if (!state.canBook) return false;

    try {
      // Get auth token
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
        );
        return false;
      }

      // Set up headers with authorization
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Build URL for creating an order
      final url = Uri.parse('http://localhost:3000/api/users/orders');

      // Prepare request body
      final requestBody = json.encode({
        'productId': state.product!.id,
        'quantity': state.quantity,
        'stationId': state.product!.stationId,
      });

      final response = await http.post(url, headers: headers, body: requestBody);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          // Successfully booked
          return true;
        } else {
          throw Exception(jsonData['message'] ?? 'Failed to book product');
        }
      } else if (response.statusCode == 401) {
        state = state.copyWith(
          error: 'Authentication required. Please log in.',
        );
        return false;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to book product');
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Error booking product: ${e.toString()}',
      );
      return false;
    }
  }
}

// Providers
final productListProvider = StateNotifierProvider<ProductListNotifier, ProductListState>((ref) {
  return ProductListNotifier(ref);
});

final productDetailProvider = StateNotifierProvider<ProductDetailNotifier, ProductDetailState>((ref) {
  return ProductDetailNotifier(ref);
});