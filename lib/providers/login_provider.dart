import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// Socket service for real-time notifications
class SocketNotificationService {
  static final SocketNotificationService _instance = SocketNotificationService._internal();
  
  factory SocketNotificationService() {
    return _instance;
  }
  
  SocketNotificationService._internal();
  
  // Init method will be implemented in socket_notification_service.dart
  void init() {}
  
  // Setup notification handling
  void setupNotificationHandling(BuildContext context) {}
  
  // Update socket auth with user ID
  void updateUserAuth(int userId) {
    // This will be implemented in socket_notification_service.dart
  }
  
  // Disconnect socket
  void disconnect() {
    // This will be implemented in socket_notification_service.dart
  }
}

// Provider for the socket service
final socketNotificationServiceProvider = Provider<SocketNotificationService>((ref) {
  final service = SocketNotificationService();
  service.init();
  return service;
});

// User model to store user data - Updated to match your requirements
class User {
  final String id;        // Changed to String to match your auth system
  final String name;
  final String email;
  final String phoneNumber;
  final String token;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber = '',
    required this.token,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'userId': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'token': token,
    };
  }

  // Create from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['userId']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      token: json['token'] ?? '',
    );
  }

  // Check if user is valid
  bool get isValid => id.isNotEmpty && token.isNotEmpty;
}

// Login state class to hold all the login-related state
class LoginState {
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;
  final String? errorMessage;
  final User user;
  final bool isInitialized;

  const LoginState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.rememberMe = false,
    this.errorMessage,
    this.user = const User(id: '', name: '', email: '', token: ''),
    this.isInitialized = false,
  });

  // Create a copy of the current state with some fields changed
  LoginState copyWith({
    bool? isLoading,
    bool? obscurePassword,
    bool? rememberMe,
    String? errorMessage,
    User? user,
    bool? isInitialized,
    bool clearError = false,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      rememberMe: rememberMe ?? this.rememberMe,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: user ?? this.user,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  // Check if user is logged in
  bool get isLoggedIn => user.isValid;
}

// Controller / Notifier class for login functionality
class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier(this.ref) : super(const LoginState()) {
    _initializeFromStorage();
  }
  
  final Ref ref;

  // Initialize user from stored data
  Future<void> _initializeFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        final user = User.fromJson(userData);
        
        if (user.isValid) {
          state = state.copyWith(user: user, isInitialized: true);
          
          // Initialize WebSocket connection with stored user ID
          final socketService = ref.read(socketNotificationServiceProvider);
          socketService.updateUserAuth(int.parse(user.id));
          
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading user from storage: $e');
    }
    
    state = state.copyWith(isInitialized: true);
  }

  // Save user data to storage
  Future<void> _saveUserToStorage(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(user.toJson()));
    } catch (e) {
      debugPrint('Error saving user to storage: $e');
    }
  }

  // Clear user data from storage
  Future<void> _clearUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
    } catch (e) {
      debugPrint('Error clearing user from storage: $e');
    }
  }

  // Toggle password visibility
  void togglePasswordVisibility() {
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  // Toggle remember me
  void toggleRememberMe() {
    state = state.copyWith(rememberMe: !state.rememberMe);
  }

  // Handle login
  Future<bool> login(String email, String password, BuildContext context) async {
    // Validate inputs
    if (email.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your email');
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      state = state.copyWith(errorMessage: 'Please enter a valid email');
      return false;
    }

    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter your password');
      return false;
    }

    if (password.length < 6) {
      state = state.copyWith(errorMessage: 'Password must be at least 6 characters');
      return false;
    }

    // Clear any previous errors and set loading state
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Make API call to login
      final response = await http.post(
        Uri.parse('${ApiConfig.getApiUrl('/users/login')}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      debugPrint('Login response status: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

      // Parse response
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Create user object from response
        final user = User(
          id: data['userId'].toString(), // Convert to string
          name: data['name'] ?? '',
          email: email,
          token: data['token'] ?? '',
          phoneNumber: data['phone'] ?? '', // Get phone if available
        );

        // Validate that we got required data
        if (user.id.isEmpty || user.token.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Invalid response from server. Please try again.',
          );
          return false;
        }

        // Update state with user
        state = state.copyWith(user: user, isLoading: false);
        
        // Save to storage if remember me is checked
        if (state.rememberMe) {
          await _saveUserToStorage(user);
        }
        
        // Initialize WebSocket connection with user ID
        try {
          final socketService = ref.read(socketNotificationServiceProvider);
          socketService.updateUserAuth(int.parse(user.id));
        } catch (e) {
          debugPrint('Error initializing WebSocket: $e');
          // Don't fail login for WebSocket issues
        }
        
        debugPrint('Login successful for user: ${user.name} (ID: ${user.id})');
        return true;
      } else {
        // Handle error
        state = state.copyWith(
          isLoading: false,
          errorMessage: data['error'] ?? data['message'] ?? 'Login failed. Please try again.',
        );
        return false;
      }
    } catch (e) {
      // Handle exception
      debugPrint('Login error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Please check your connection and try again.',
      );
      return false;
    }
  }

  // Handle registration
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    // Clear any previous errors and set loading state
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Make API call to register
      final response = await http.post(
        Uri.parse('${ApiConfig.getApiUrl('/users/register')}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          if (address != null) 'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      );

      debugPrint('Register response status: ${response.statusCode}');
      debugPrint('Register response body: ${response.body}');

      if (response.statusCode == 201) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        final Map<String, dynamic> data = jsonDecode(response.body);
        state = state.copyWith(
          isLoading: false,
          errorMessage: data['error'] ?? data['message'] ?? 'Registration failed. Please try again.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Please check your connection and try again.',
      );
      return false;
    }
  }

  // Handle forgot password
  void forgotPassword() {
    // Implement forgot password functionality
    state = state.copyWith(
      errorMessage: 'Forgot password functionality coming soon!'
    );
  }

  // Get the token for API authorization
  String getToken() {
    return state.user.token;
  }

  // Check if user is logged in
  bool isLoggedIn() {
    return state.user.isValid;
  }

  // Update user data
  void updateUser(User user) {
    state = state.copyWith(user: user);
    if (state.rememberMe) {
      _saveUserToStorage(user);
    }
  }

  // Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Auto login check (for app startup)
  Future<bool> autoLogin() async {
    if (!state.isInitialized) {
      await _initializeFromStorage();
    }
    return state.isLoggedIn;
  }

  // Clear user data for logout
  Future<void> logout() async {
    try {
      // Disconnect WebSocket
      final socketService = ref.read(socketNotificationServiceProvider);
      socketService.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting WebSocket: $e');
    }
    
    // Clear stored data
    await _clearUserFromStorage();
    
    // Reset login state
    state = const LoginState(isInitialized: true);
  }

  // Refresh user token (if your API supports token refresh)
  Future<bool> refreshToken() async {
    if (!state.isLoggedIn) return false;

    try {
      // Implement token refresh logic here if your API supports it
      // For now, just return true if user has a valid token
      return state.user.token.isNotEmpty;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
}

// Provider for the login state
final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref);
});

// Provider for current user data
final userProvider = Provider<User>((ref) {
  final loginState = ref.watch(loginProvider);
  return loginState.user;
});

// Provider for authorization headers
final authHeadersProvider = Provider<Map<String, String>>((ref) {
  final token = ref.watch(loginProvider).user.token;
  return {
    'Content-Type': 'application/json',
    'Authorization': token.isNotEmpty ? 'Bearer $token' : '',
  };
});

// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(loginProvider).isLoggedIn;
});

// Provider for user ID as int (for WebSocket compatibility)
final userIdProvider = Provider<int?>((ref) {
  final userId = ref.watch(loginProvider).user.id;
  return userId.isNotEmpty ? int.tryParse(userId) : null;
});