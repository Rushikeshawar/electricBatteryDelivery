import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:electric_battery_delivery_frontend/models/order_model.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// State class for order history
class OrderHistoryState {
  final bool isLoading;
  final bool isLoadingMore;
  final List<Order> orders;
  final String searchQuery;
  final String selectedStatus;
  final TextEditingController searchController;
  final TabController? tabController;
  final PaginationInfo? pagination;
  final String? errorMessage;
  final int currentPage;
  final bool hasReachedEnd;

  const OrderHistoryState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.orders = const [],
    this.searchQuery = '',
    this.selectedStatus = 'ALL',
    required this.searchController,
    this.tabController,
    this.pagination,
    this.errorMessage,
    this.currentPage = 1,
    this.hasReachedEnd = false,
  });

  OrderHistoryState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<Order>? orders,
    String? searchQuery,
    String? selectedStatus,
    TextEditingController? searchController,
    TabController? tabController,
    PaginationInfo? pagination,
    String? errorMessage,
    bool clearError = false,
    int? currentPage,
    bool? hasReachedEnd,
  }) {
    return OrderHistoryState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      orders: orders ?? this.orders,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchController: searchController ?? this.searchController,
      tabController: tabController ?? this.tabController,
      pagination: pagination ?? this.pagination,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
    );
  }

  // Optimized filtered orders
  List<Order> get filteredOrders {
    if (searchQuery.isEmpty) {
      return orders;
    }
    
    final query = searchQuery.toLowerCase();
    return orders.where((order) {
      return order.orderNumber.toLowerCase().contains(query) ||
          order.batteryType.toLowerCase().contains(query) ||
          order.station.name.toLowerCase().contains(query) ||
          order.deliveryAddress.toLowerCase().contains(query);
    }).toList();
  }

  List<Order> get pendingOrders {
    return filteredOrders.where((o) => 
      o.status == 'PENDING' || 
      o.status == 'CONFIRMED' ||
      o.status == 'ASSIGNED'
    ).toList();
  }

  List<Order> get completedOrders {
    return filteredOrders.where((o) => 
      o.status == 'DELIVERED' || 
      o.status == 'CANCELLED'
    ).toList();
  }

  List<Order> get inProgressOrders {
    return filteredOrders.where((o) => 
      o.status == 'PICKED_UP' || 
      o.status == 'IN_TRANSIT'
    ).toList();
  }

  bool get hasMorePages {
    return pagination != null && currentPage < pagination!.pages && !hasReachedEnd;
  }

  @override
  String toString() {
    return 'OrderHistoryState(isLoading: $isLoading, orders: ${orders.length}, searchQuery: $searchQuery, selectedStatus: $selectedStatus, currentPage: $currentPage)';
  }
}

// Optimized notifier with better lifecycle management
class OrderHistoryNotifier extends StateNotifier<OrderHistoryState> {
  final Ref _ref;
  bool _disposed = false;
  Timer? _searchDebounce;
  
  OrderHistoryNotifier(this._ref) 
      : super(OrderHistoryState(
          searchController: TextEditingController(),
        ));

  // Safe state update that checks if widget is still mounted
  void _safeUpdateState(OrderHistoryState Function(OrderHistoryState) updater) {
    if (!_disposed && mounted) {
      try {
        state = updater(state);
      } catch (e) {
        debugPrint('Error updating state: $e');
      }
    }
  }

  void setTabController(TabController controller) {
    _safeUpdateState((state) => state.copyWith(tabController: controller));
  }

  // Optimized load orders with better error handling and performance
  Future<void> loadOrders({
    int page = 1, 
    int limit = 20,
    bool refresh = false
  }) async {
    if (_disposed) return;

    // Prevent multiple simultaneous loads
    if (state.isLoading && !refresh) return;
    if (state.isLoadingMore && page > 1) return;

    try {
      if (refresh || page == 1) {
        _safeUpdateState((state) => state.copyWith(
          isLoading: true, 
          orders: refresh ? [] : state.orders, 
          clearError: true,
          hasReachedEnd: false,
        ));
      } else {
        _safeUpdateState((state) => state.copyWith(
          isLoadingMore: true, 
          clearError: true
        ));
      }

      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      // Construct URL properly
      String baseUrl = ApiConfig.ordersUrl;
      if (!baseUrl.endsWith('/')) {
        baseUrl += '/';
      }
      
      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      // Only add status filter if it's not 'ALL'
      if (state.selectedStatus != 'ALL') {
        queryParams['status'] = state.selectedStatus;
      }
      
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      
      debugPrint('Loading orders from: $uri');

      final response = await http.get(uri, headers: headers).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );

      if (_disposed) return;

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrdersResponse.fromJson(jsonData);
        
        if (refresh || page == 1) {
          _safeUpdateState((state) => state.copyWith(
            orders: orderResponse.data,
            pagination: orderResponse.pagination,
            isLoading: false,
            isLoadingMore: false,
            currentPage: page,
            hasReachedEnd: orderResponse.data.length < limit,
          ));
        } else {
          // Check for duplicates before appending
          final existingIds = state.orders.map((o) => o.id).toSet();
          final newOrders = orderResponse.data.where((o) => !existingIds.contains(o.id)).toList();
          
          _safeUpdateState((state) => state.copyWith(
            orders: [...state.orders, ...newOrders],
            pagination: orderResponse.pagination,
            isLoading: false,
            isLoadingMore: false,
            currentPage: page,
            hasReachedEnd: newOrders.length < limit,
          ));
        }
      } else {
        String errorMessage = 'Failed to load orders';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }
        
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: errorMessage,
        ));
      }
    } catch (e) {
      if (!_disposed) {
        debugPrint('Error loading orders: $e');
        _safeUpdateState((state) => state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          errorMessage: 'Error: ${e.toString()}',
        ));
      }
    }
  }

  // Load more orders for pagination
  Future<void> loadMoreOrders() async {
    if (_disposed || !state.hasMorePages || state.isLoadingMore) {
      return;
    }
    
    await loadOrders(page: state.currentPage + 1);
  }

  // Fetch order details
  Future<Order?> getOrderDetails(int orderId) async {
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

      // Construct URL properly
      String baseUrl = ApiConfig.ordersUrl;
      if (!baseUrl.endsWith('/')) {
        baseUrl += '/';
      }
      final url = '$baseUrl$orderId';
      
      debugPrint('Fetching order details from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      debugPrint('Order details response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final orderResponse = OrderResponse.fromJson(jsonData);
        return orderResponse.data;
      } else {
        String errorMessage = 'Failed to load order details';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      throw Exception('Error fetching order details: ${e.toString()}');
    }
  }

  // Cancel order with optimistic update
  Future<bool> cancelOrder(int orderId) async {
    if (_disposed) return false;
    
    try {
      // Optimistic update using your existing copyWith method
      final List<Order> optimisticOrders = state.orders.map((order) {
        if (order.id == orderId) {
          return order.copyWith(
            status: 'CANCELLED',
            updatedAt: DateTime.now().toIso8601String(),
          );
        }
        return order;
      }).toList();
      
      _safeUpdateState((state) => state.copyWith(orders: optimisticOrders));

      final loginState = _ref.read(loginProvider);
      if (loginState.user.token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${loginState.user.token}',
      };

      // Construct URL properly
      String baseUrl = ApiConfig.ordersUrl;
      if (!baseUrl.endsWith('/')) {
        baseUrl += '/';
      }
      final url = '$baseUrl$orderId/cancel';
      
      debugPrint('Cancelling order at: $url');

      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      debugPrint('Cancel order response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return true;
      } else {
        // Revert optimistic update on failure
        await loadOrders(refresh: true);
        
        String errorMessage = 'Failed to cancel order';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        }
        
        _safeUpdateState((state) => state.copyWith(
          errorMessage: errorMessage,
        ));
        return false;
      }
    } catch (e) {
      // Revert optimistic update on error
      await loadOrders(refresh: true);
      
      debugPrint('Error cancelling order: $e');
      _safeUpdateState((state) => state.copyWith(
        errorMessage: 'Error: ${e.toString()}',
      ));
      return false;
    }
  }

  // Debounced search
  void updateSearchQuery(String query) {
    if (_disposed) return;
    
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!_disposed) {
        _safeUpdateState((state) => state.copyWith(searchQuery: query));
      }
    });
  }

  void clearSearch() {
    if (_disposed) return;
    
    _searchDebounce?.cancel();
    state.searchController.clear();
    _safeUpdateState((state) => state.copyWith(searchQuery: ''));
  }

  void updateSelectedStatus(String status) {
    if (_disposed || status == state.selectedStatus) return;
    
    _safeUpdateState((state) => state.copyWith(selectedStatus: status));
    loadOrders(refresh: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _searchDebounce?.cancel();
    state.searchController.dispose();
    super.dispose();
  }
}

// Provider for order history notifier
final orderHistoryProvider = StateNotifierProvider<OrderHistoryNotifier, OrderHistoryState>((ref) {
  return OrderHistoryNotifier(ref);
});

// Provider for available status filters
final orderStatusFiltersProvider = Provider<List<Map<String, String>>>((ref) {
  return [
    {'value': 'ALL', 'label': 'All Orders'},
    {'value': 'PENDING', 'label': 'Pending'},
    {'value': 'CONFIRMED', 'label': 'Confirmed'},
    {'value': 'ASSIGNED', 'label': 'Assigned'},
    {'value': 'PICKED_UP', 'label': 'Picked Up'},
    {'value': 'IN_TRANSIT', 'label': 'In Transit'},
    {'value': 'DELIVERED', 'label': 'Delivered'},
    {'value': 'CANCELLED', 'label': 'Cancelled'},
  ];
});

// Provider for formatters
final formattersProvider = Provider<Map<String, dynamic>>((ref) {
  return {
    'date': DateFormat('MMM dd, yyyy'),
    'time': DateFormat('hh:mm a'),
    'dateTime': DateFormat('MMM dd, yyyy hh:mm a'),
    'currency': NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
    ),
  };
});