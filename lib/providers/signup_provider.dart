import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:electric_battery_delivery_frontend/config/api_config.dart';

// SignupState to handle all form state
class SignupState {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final String address;
  final String phoneNumber;
  final String selectedGender;
  final double latitude;
  final double longitude;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isLoading;
  final bool agreeToTerms;
  final int currentStep;
  final String? errorMessage;
  final bool isGettingLocation;

  const SignupState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.address = '',
    this.phoneNumber = '',
    this.selectedGender = 'Male',
    this.latitude = 18.5204,  // Default Pune coordinates
    this.longitude = 73.8567, // Default Pune coordinates
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.isLoading = false,
    this.agreeToTerms = false,
    this.currentStep = 0,
    this.errorMessage,
    this.isGettingLocation = false,
  });

  // Create a copy of the state with updated fields
  SignupState copyWith({
    String? name,
    String? email,
    String? password,
    String? confirmPassword,
    String? address,
    String? phoneNumber,
    String? selectedGender,
    double? latitude,
    double? longitude,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    bool? isLoading,
    bool? agreeToTerms,
    int? currentStep,
    String? errorMessage,
    bool? isGettingLocation,
    bool clearError = false,
  }) {
    return SignupState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      selectedGender: selectedGender ?? this.selectedGender,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword: obscureConfirmPassword ?? this.obscureConfirmPassword,
      isLoading: isLoading ?? this.isLoading,
      agreeToTerms: agreeToTerms ?? this.agreeToTerms,
      currentStep: currentStep ?? this.currentStep,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isGettingLocation: isGettingLocation ?? this.isGettingLocation,
    );
  }

  // Method to validate the current step
  bool validateStep(int step, GlobalKey<FormState> formKey) {
    if (!formKey.currentState!.validate()) {
      return false;
    }

    switch (step) {
      case 0: // Personal Info
        return name.isNotEmpty && phoneNumber.isNotEmpty;
      case 1: // Contact Info & Security
        return email.isNotEmpty && 
               RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email) && 
               address.isNotEmpty &&
               password.isNotEmpty && 
               password.length >= 6 && 
               confirmPassword == password && 
               agreeToTerms;
      default:
        return false;
    }
  }

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phoneNumber,
      'password': password,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// SignupNotifier to manage signup state
class SignupNotifier extends StateNotifier<SignupState> {
  SignupNotifier() : super(const SignupState());

  // Update form field values
  void updateName(String value) => state = state.copyWith(name: value);
  void updateEmail(String value) => state = state.copyWith(email: value);
  void updatePassword(String value) => state = state.copyWith(password: value);
  void updateConfirmPassword(String value) => state = state.copyWith(confirmPassword: value);
  void updateAddress(String value) => state = state.copyWith(address: value);
  void updatePhoneNumber(String value) => state = state.copyWith(phoneNumber: value);
  void updateSelectedGender(String value) => state = state.copyWith(selectedGender: value);

  // Toggle state values
  void togglePasswordVisibility() => 
      state = state.copyWith(obscurePassword: !state.obscurePassword);
  
  void toggleConfirmPasswordVisibility() => 
      state = state.copyWith(obscureConfirmPassword: !state.obscureConfirmPassword);
  
  void toggleAgreeToTerms() => 
      state = state.copyWith(agreeToTerms: !state.agreeToTerms);

  // Get current location
  Future<void> getCurrentLocation(BuildContext context) async {
    state = state.copyWith(isGettingLocation: true, clearError: true);

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            errorMessage: 'Location permissions are denied',
            isGettingLocation: false,
          );
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          errorMessage: 'Location permissions are permanently denied, please enable in settings',
          isGettingLocation: false,
        );
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        isGettingLocation: false,
        clearError: true,
      );
      
      // Show success message via SnackBar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location detected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Could not get current location: ${e.toString()}',
        isGettingLocation: false,
      );
    } 
  }

  // Get coordinates from address
  Future<void> getCoordinatesFromAddress() async {
    if (state.address.isEmpty) return;
    
    state = state.copyWith(isGettingLocation: true);
    
    try {
      List<Location> locations = await locationFromAddress(state.address);
      if (locations.isNotEmpty) {
        state = state.copyWith(
          latitude: locations.first.latitude,
          longitude: locations.first.longitude,
          isGettingLocation: false,
        );
      }
    } catch (e) {
      // Fallback to default coordinates if geocoding fails
      // We don't set an error message to avoid confusion in the UI
      state = state.copyWith(isGettingLocation: false);
    }
  }

  // Handle stepper navigation
  void nextStep(GlobalKey<FormState> formKey) {
    if (state.validateStep(state.currentStep, formKey)) {
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        clearError: true,
      );
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        clearError: true,
      );
    }
  }

  // Handle signup submission
  Future<bool> signup(GlobalKey<FormState> formKey) async {
    // Validate the form
    if (!formKey.currentState!.validate()) {
      return false;
    }

    // Check if terms are accepted
    if (!state.agreeToTerms) {
      state = state.copyWith(
        errorMessage: 'Please accept the terms and conditions',
      );
      return false;
    }

    // Set loading state
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Make API call to register endpoint
      final response = await http.post(
        Uri.parse('${ApiConfig.getApiUrl('/users/register')}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(state.toJson()),
      );
      
      // Debug print
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Registration successful
        return true;
      } else {
        // Get error message from API response
        Map<String, dynamic> errorData = {};
        try {
          errorData = jsonDecode(response.body);
        } catch (e) {
          // If response body can't be parsed as JSON
          errorData = {'message': 'Registration failed: Invalid server response'};
        }
        
        state = state.copyWith(
          errorMessage: errorData['message'] ?? 'Registration failed',
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      // Handle network or other errors
      print('Registration error: $e');
      state = state.copyWith(
        errorMessage: 'Network error: Check your internet connection',
        isLoading: false,
      );
      return false;
    } finally {
      // Reset loading state
      state = state.copyWith(isLoading: false);
    }
  }
}

// Provider for signup state
final signupProvider = StateNotifierProvider<SignupNotifier, SignupState>((ref) {
  return SignupNotifier();
});

// List of gender options
final genderOptionsProvider = Provider<List<String>>((ref) {
  return ['Male', 'Female', 'Other'];
});