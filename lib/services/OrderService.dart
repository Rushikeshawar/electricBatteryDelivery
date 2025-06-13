import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OrderService with ChangeNotifier {
  String? _authToken;
  String? _baseUrl;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Pagination data
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalOrders = 0;
  int _perPage = 10;
  
  // Filter settings
  String _statusFilter = 'All';
  
  // Getters
  List<Map<String, dynamic>> get orders => [..._orders];
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalOrders => _totalOrders;
  bool get hasMorePages => _currentPage < _totalPages;
  
  // Set auth token
  set authToken(String? token) {
    _authToken = token;
    _initializeBaseUrl();
    notifyListeners();
  }
  
  // Constructor
  OrderService() {
    _initializeBaseUrl();
  }
  
  // Initialize base URL from env
  void _initializeBaseUrl() {
    _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/api';
  }
  
  // Load orders with pagination and filtering
  Future<void> loadOrders({
    int page = 1, 
    int limit = 10,
    String status = 'All',
  }) async {
    if (_authToken == null) {
      _errorMessage = 'Not authenticated';
      return;
    }
    
    _isLoading = true;
    _currentPage = page;
    _perPage = limit;
    _statusFilter = status;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _authToken ?? prefs.getString('auth_token') ?? '';
      
      // Create URL with query parameters
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      // Add status filter if not 'All'
      if (status != 'All') {
        queryParams['status'] = status;
      }
      
      final uri = Uri.parse('$_baseUrl/users/orders').replace(
        queryParameters: queryParams,
      );
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] && data['data'] != null) {
          // If first page, replace orders; otherwise append
          if (page == 1) {
            _orders = List<Map<String, dynamic>>.from(data['data']);
          } else {
            _orders.addAll(List<Map<String, dynamic>>.from(data['data']));
          }
          
          // Update pagination info
          if (data['pagination'] != null) {
            _totalPages = data['pagination']['pages'] ?? 1;
            _totalOrders = data['pagination']['total'] ?? 0;
          }
          
          _errorMessage = '';
        } else {
          _errorMessage = data['error'] ?? 'Failed to load orders';
        }
      } else {
        _errorMessage = 'Error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      print('❌ Error loading orders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load next page of orders
  Future<void> loadMoreOrders() async {
    if (hasMorePages && !_isLoading) {
      await loadOrders(
        page: _currentPage + 1,
        limit: _perPage,
        status: _statusFilter,
      );
    }
  }
  
  // Refresh orders (reset to page 1)
  Future<void> refreshOrders({String status = 'All'}) async {
    await loadOrders(page: 1, limit: _perPage, status: status);
  }
  
  // Get a specific order by ID from cached orders
  Map<String, dynamic>? getOrderById(int orderId) {
    try {
      return _orders.firstWhere((order) => order['id'] == orderId);
    } catch (e) {
      return null;
    }
  }
  
  // Fetch a specific order by ID from API
  Future<Map<String, dynamic>?> fetchOrderById(int orderId) async {
    if (_authToken == null) {
      _errorMessage = 'Not authenticated';
      return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _authToken ?? prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/orders/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] && data['data'] != null) {
          final orderData = data['data'];
          
          // Update cached order if exists
          final index = _orders.indexWhere((order) => order['id'] == orderId);
          if (index >= 0) {
            _orders[index] = orderData;
          } else {
            _orders.add(orderData);
          }
          
          notifyListeners();
          return orderData;
        } else {
          _errorMessage = data['error'] ?? 'Failed to load order';
          return null;
        }
      } else {
        _errorMessage = 'Error: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      print('❌ Error fetching order: $e');
      return null;
    }
  }
  
  // Get order delivery OTP
  Future<Map<String, dynamic>?> getOrderOTP(int orderId) async {
    if (_authToken == null) {
      _errorMessage = 'Not authenticated';
      return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _authToken ?? prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/orders/$orderId/otp'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] && data['data'] != null) {
          return data['data'];
        } else {
          _errorMessage = data['error'] ?? 'Failed to get OTP';
          return null;
        }
      } else {
        _errorMessage = 'Error: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      print('❌ Error getting OTP: $e');
      return null;
    }
  }
  
  // Cancel an order
  Future<bool> cancelOrder(int orderId) async {
    if (_authToken == null) {
      _errorMessage = 'Not authenticated';
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _authToken ?? prefs.getString('auth_token') ?? '';
      
      final response = await http.put(
        Uri.parse('$_baseUrl/users/orders/$orderId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          // Update cached order status
          final index = _orders.indexWhere((order) => order['id'] == orderId);
          if (index >= 0) {
            _orders[index]['status'] = 'CANCELLED';
          }
          
          notifyListeners();
          return true;
        } else {
          _errorMessage = data['error'] ?? 'Failed to cancel order';
          return false;
        }
      } else {
        _errorMessage = 'Error: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      print('❌ Error cancelling order: $e');
      return false;
    }
  }
  
  // Get driver location status for an order
  Future<Map<String, dynamic>?> getDriverLocationStatus(int orderId) async {
    if (_authToken == null) {
      _errorMessage = 'Not authenticated';
      return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _authToken ?? prefs.getString('auth_token') ?? '';
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/orders/$orderId/location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] && data['data'] != null) {
          return data['data'];
        } else {
          _errorMessage = data['error'] ?? 'Failed to get location status';
          return null;
        }
      } else {
        _errorMessage = 'Error: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      print('❌ Error getting location status: $e');
      return null;
    }
  }
  
  // Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}