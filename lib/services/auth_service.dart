import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/services/socket_notification_service.dart';

// Define the socket notification service provider
final socketNotificationServiceProvider = Provider<SocketNotificationService>((ref) {
  final service = SocketNotificationService();
  service.init();
  return service;
});

// Define the auth service provider (now with ChangeNotifier)
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  final socketService = ref.read(socketNotificationServiceProvider);
  return AuthService(socketService);
});

class UserModel {
  final String id;
  final String name;
  final String email;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'name': name,
      'email': email,
      'token': token,
    };
  }
}

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  // Server URL - replace with your actual API URL
  final String _baseUrl = 'http://localhost:3000/api';
  
  // Socket notification service
  final SocketNotificationService _socketService;

  // Constructor loads user from storage
  AuthService(this._socketService) {
    _loadUserFromStorage();
  }

  // Load user from local storage
  Future<void> _loadUserFromStorage() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');

      if (userJson != null) {
        final userData = json.decode(userJson);
        _currentUser = UserModel.fromJson(userData);
        
        // Initialize WebSocket connection with stored user ID
        if (_currentUser != null) {
          _socketService.updateUserAuth(int.parse(_currentUser!.id));
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Save user to local storage
  Future<void> _saveUserToStorage(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(user.toJson()));
    } catch (e) {
      debugPrint('Error saving user: $e');
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Login user
  Future<bool> login(String email, String password) async {
    _setLoading(true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Create user model from response
          _currentUser = UserModel(
            id: data['userId'].toString(),
            name: data['name'] ?? '',
            email: email, // API doesn't return email, so we use the one from login
            token: data['token'],
          );
          
          await _saveUserToStorage(_currentUser!);
          
          // Initialize WebSocket connection with user ID
          _socketService.updateUserAuth(int.parse(_currentUser!.id));
          
          _setLoading(false);
          notifyListeners();
          return true;
        }
      }
      
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Register user
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    _setLoading(true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      _setLoading(false);
      
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Registration error: $e');
      _setLoading(false);
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    _setLoading(true);

    try {
      // Disconnect WebSocket
      _socketService.disconnect();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      _currentUser = null;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get auth token
  String? getToken() {
    return _currentUser?.token;
  }

  // Get auth headers for API requests
  Map<String, String> getAuthHeaders() {
    final token = getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  // Auto login (check if user is already logged in)
  Future<bool> autoLogin() async {
    if (_currentUser != null) {
      return true;
    }
    
    // Try to load user from storage
    await _loadUserFromStorage();
    return _currentUser != null;
  }

  // Update user data
  void updateUser(UserModel user) {
    _currentUser = user;
    _saveUserToStorage(user);
    notifyListeners();
  }

  // Check if token is valid (you can implement token expiry check here)
  bool isTokenValid() {
    if (_currentUser?.token == null) return false;
    
    // Add your token validation logic here
    // For now, just check if token exists
    return _currentUser!.token.isNotEmpty;
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (!isAuthenticated) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/profile'),
        headers: getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Update user with fresh data from server
          final updatedUser = UserModel(
            id: _currentUser!.id,
            name: data['data']['name'] ?? _currentUser!.name,
            email: data['data']['email'] ?? _currentUser!.email,
            token: _currentUser!.token,
          );
          
          updateUser(updatedUser);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }
}