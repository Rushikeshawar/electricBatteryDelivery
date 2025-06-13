import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:electric_battery_delivery_frontend/components/dummy.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// Profile state class to hold all profile-related state
class ProfileState {
  final String userName;
  final String userEmail;
  final String phoneNumber;
  final String address;
  final double latitude;
  final double longitude;
  final bool isActive;
  final int orderCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool notificationsEnabled;
  final bool locationEnabled;
  final bool darkModeEnabled;
  final String selectedLanguage;
  final List<String> languages;
  final List<String> vehicles;
  final bool isLoading;
  final String? errorMessage;

  ProfileState({
    required this.userName,
    required this.userEmail,
    required this.phoneNumber,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.orderCount,
    required this.createdAt,
    required this.updatedAt,
    this.notificationsEnabled = true,
    this.locationEnabled = true,
    this.darkModeEnabled = false,
    this.selectedLanguage = 'English',
    this.languages = const ['English', 'Hindi', 'Kannada', 'Telugu'],
    required this.vehicles,
    this.isLoading = false,
    this.errorMessage,
  });

  // Create a copy of the current state with some values changed
  ProfileState copyWith({
    String? userName,
    String? userEmail,
    String? phoneNumber,
    String? address,
    double? latitude,
    double? longitude,
    bool? isActive,
    int? orderCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? notificationsEnabled,
    bool? locationEnabled,
    bool? darkModeEnabled,
    String? selectedLanguage,
    List<String>? languages,
    List<String>? vehicles,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      orderCount: orderCount ?? this.orderCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      languages: languages ?? this.languages,
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  // Create from API response
  factory ProfileState.fromJson(Map<String, dynamic> json) {
    return ProfileState(
      userName: json['name'] ?? '',
      userEmail: json['email'] ?? '',
      phoneNumber: json['phone'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      isActive: json['isActive'] ?? true,
      orderCount: json['_count']?['orders'] ?? json['orderCount'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      vehicles: DummyData.dummyUser.vehicles, // Using dummy data for now
    );
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'name': userName,
      'email': userEmail,
      'phone': phoneNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// Stats class to hold quick statistics data
class ProfileStats {
  final int totalSwaps;
  final double totalSpent;
  final int activeBookings;

  ProfileStats({
    required this.totalSwaps,
    required this.totalSpent,
    required this.activeBookings,
  });

  // Format the values for display
  String get formattedTotalSwaps => totalSwaps.toString();
  String get formattedTotalSpent => '₹${totalSpent.toStringAsFixed(0)}';
  String get formattedActiveBookings => activeBookings.toString();
}

// Profile notifier to handle state changes
class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref _ref;
  
  ProfileNotifier(this._ref, {
    required String userName,
    required String userEmail,
    required String phoneNumber,
  }) : super(
          ProfileState(
            userName: userName,
            userEmail: userEmail,
            phoneNumber: phoneNumber,
            address: '',
            latitude: 0.0,
            longitude: 0.0,
            isActive: true,
            orderCount: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            vehicles: DummyData.dummyUser.vehicles,
          ),
        ) {
    // Load profile data when initialized
    fetchProfileData();
  }

  // Fetch profile data from API
  Future<void> fetchProfileData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      // Get auth token if user is logged in
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        throw Exception('User not authenticated');
      }
      
      // Set up headers
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Make API request
      final response = await http.get(
        Uri.parse(ApiConfig.profileUrl),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          // Update state with profile data from API
          final profileData = ProfileState.fromJson(jsonData['data']);
          state = state.copyWith(
            userName: profileData.userName,
            userEmail: profileData.userEmail,
            phoneNumber: profileData.phoneNumber,
            address: profileData.address,
            latitude: profileData.latitude,
            longitude: profileData.longitude,
            isActive: profileData.isActive,
            orderCount: profileData.orderCount,
            createdAt: profileData.createdAt,
            updatedAt: profileData.updatedAt,
            isLoading: false,
          );
        } else {
          throw Exception('Invalid data format from API');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load profile');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error loading profile: ${e.toString()}',
      );
    }
  }

  // Update profile through API
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
    double? latitude,
    double? longitude,
    String? oldPassword,
    String? newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Get auth token if user is logged in
      String? token;
      try {
        token = _ref.read(loginProvider).user.token;
      } catch (e) {
        throw Exception('User not authenticated');
      }
      
      // Set up headers
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Prepare request body
      final requestBody = {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'latitude': latitude ?? state.latitude,
        'longitude': longitude ?? state.longitude,
      };
      
      // Add password fields if provided
      if (oldPassword != null && oldPassword.isNotEmpty && 
          newPassword != null && newPassword.isNotEmpty) {
        requestBody['oldPassword'] = oldPassword;
        requestBody['newPassword'] = newPassword;
      }
      
      // Make API request
      final response = await http.put(
        Uri.parse(ApiConfig.profileUrl),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData['success'] == true && jsonData['data'] != null) {
          // Update state with updated profile data
          final profileData = ProfileState.fromJson(jsonData['data']);
          state = state.copyWith(
            userName: profileData.userName,
            userEmail: profileData.userEmail,
            phoneNumber: profileData.phoneNumber,
            address: profileData.address,
            latitude: profileData.latitude,
            longitude: profileData.longitude,
            isActive: profileData.isActive,
            orderCount: profileData.orderCount,
            updatedAt: profileData.updatedAt,
            isLoading: false,
          );
          return true;
        } else {
          throw Exception('Invalid data format from API');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error updating profile: ${e.toString()}',
      );
      return false;
    }
  }

  // Toggle notifications
  void toggleNotifications(bool value) {
    state = state.copyWith(notificationsEnabled: value);
  }

  // Toggle location services
  void toggleLocation(bool value) {
    state = state.copyWith(locationEnabled: value);
  }

  // Toggle dark mode
  void toggleDarkMode(bool value) {
    state = state.copyWith(darkModeEnabled: value);
  }

  // Set selected language
  void setLanguage(String language) {
    state = state.copyWith(selectedLanguage: language);
  }

  // Add a new vehicle
  void addVehicle(String vehicle) {
    final updatedVehicles = [...state.vehicles, vehicle];
    state = state.copyWith(vehicles: updatedVehicles);
  }

  // Edit a vehicle
  void editVehicle(int index, String newVehicle) {
    final updatedVehicles = [...state.vehicles];
    updatedVehicles[index] = newVehicle;
    state = state.copyWith(vehicles: updatedVehicles);
  }

  // Remove a vehicle
  void removeVehicle(int index) {
    final updatedVehicles = [...state.vehicles];
    updatedVehicles.removeAt(index);
    state = state.copyWith(vehicles: updatedVehicles);
  }
}

// Provider for profile state
final profileProvider = StateNotifierProvider.family<ProfileNotifier, ProfileState, (String, String, String)>(
  (ref, params) => ProfileNotifier(
    ref,
    userName: params.$1,
    userEmail: params.$2,
    phoneNumber: params.$3,
  ),
);

// Provider for profile stats - using orderCount from profile
final profileStatsProvider = Provider<ProfileStats>((ref) {
  // In a real app, these values would come from an API
  // For now, we'll use the orderCount from the profile as totalSwaps
  final userInfo = ref.watch(userInfoProvider);
  final params = (userInfo['userName'] ?? '', userInfo['userEmail'] ?? '', userInfo['phoneNumber'] ?? '');
  final profileState = ref.watch(profileProvider(params));
  
  return ProfileStats(
    totalSwaps: profileState.orderCount,
    totalSpent: profileState.orderCount * 200.0, // Assuming average cost of 200 per swap
    activeBookings: 1, // Placeholder for now
  );
});

// Provider for the current user info
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