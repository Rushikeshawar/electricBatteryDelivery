import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/providers/signup_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignupScreen2 extends ConsumerStatefulWidget {
  const SignupScreen2({super.key});

  @override
  ConsumerState<SignupScreen2> createState() => _SignupScreen2State();
}

class _SignupScreen2State extends ConsumerState<SignupScreen2> {
  // Keep a form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Google Maps API Key
  final String _googleApiKey = 'AIzaSyBr_r8bq7m1A5aIh9-rkEIUB7chNfbwimM';
  
  // Location variables
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isGettingLocation = false;
  bool _isGeocodingAddress = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial state values
    _emailController.text = ref.read(signupProvider).email;
    _addressController.text = ref.read(signupProvider).address;
    _passwordController.text = ref.read(signupProvider).password;
    _confirmPasswordController.text = ref.read(signupProvider).confirmPassword;
  }

  // Get coordinates from address using Google Geocoding API
  Future<void> _getCoordinatesFromAddress() async {
    if (_addressController.text.isEmpty) {
      _showSnackBar('Please enter an address first', Colors.orange);
      return;
    }

    setState(() {
      _isGeocodingAddress = true;
      _locationError = null;
    });

    try {
      String fullAddress = _addressController.text;
      
      // Add country, state, and pincode if provided
      if (_countryController.text.isNotEmpty) {
        fullAddress += ', ${_countryController.text}';
      }
      if (_stateController.text.isNotEmpty) {
        fullAddress += ', ${_stateController.text}';
      }
      if (_pincodeController.text.isNotEmpty) {
        fullAddress += ', ${_pincodeController.text}';
      }

      final String url = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(fullAddress)}&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final addressComponents = data['results'][0]['address_components'];
          final formattedAddress = data['results'][0]['formatted_address'];
          
          setState(() {
            _latitude = location['lat'];
            _longitude = location['lng'];
          });

          // Update address field with formatted address
          _addressController.text = formattedAddress;
          
          // Extract and fill country, state, and pincode from address components
          _extractAddressComponents(addressComponents);
          
          _showSnackBar('Location found successfully!', Colors.green);
        } else {
          setState(() {
            _locationError = 'Address not found. Please check your address.';
          });
          _showSnackBar('Address not found. Please check your address.', Colors.red);
        }
      } else {
        throw Exception('Failed to fetch location data');
      }
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: ${e.toString()}';
      });
      _showSnackBar('Error getting location: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isGeocodingAddress = false;
      });
    }
  }

  // Extract address components (country, state, pincode)
  void _extractAddressComponents(List<dynamic> components) {
    for (var component in components) {
      List<String> types = List<String>.from(component['types']);
      
      if (types.contains('country')) {
        _countryController.text = component['long_name'];
      } else if (types.contains('administrative_area_level_1')) {
        _stateController.text = component['long_name'];
      } else if (types.contains('postal_code')) {
        _pincodeController.text = component['long_name'];
      }
    }
  }

  // Get current location using GPS
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Get address from coordinates using reverse geocoding
      await _getAddressFromCoordinates(position.latitude, position.longitude);
      
      _showSnackBar('Current location detected successfully!', Colors.green);
    } catch (e) {
      setState(() {
        _locationError = 'Error getting current location: ${e.toString()}';
      });
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // Get address from coordinates using Google Reverse Geocoding API
  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final addressComponents = data['results'][0]['address_components'];
          final formattedAddress = data['results'][0]['formatted_address'];
          
          // Update address field
          _addressController.text = formattedAddress;
          
          // Extract and fill address components
          _extractAddressComponents(addressComponents);
        }
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final signupNotifier = ref.read(signupProvider.notifier);
    
    // Update provider with form values
    signupNotifier.updateEmail(_emailController.text);
    signupNotifier.updateAddress(_addressController.text);
    signupNotifier.updatePassword(_passwordController.text);
    signupNotifier.updateConfirmPassword(_confirmPasswordController.text);
    
    final success = await signupNotifier.signup(_formKey);

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please login with your credentials.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Wait for the snackbar to be visible before navigating
      Future.delayed(const Duration(milliseconds: 1500), () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } else if (mounted) {
      final errorMessage = ref.read(signupProvider).errorMessage;
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the signup state
    final signupState = ref.watch(signupProvider);
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contact & Security'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Contact Information Section
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => ref.read(signupProvider.notifier).updateEmail(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Location Section
                      const Text(
                        'Location Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Country field
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          hintText: 'Enter your country',
                          prefixIcon: Icon(Icons.public),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),

                      // State field
                      TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          hintText: 'Enter your state',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),

                      // Pincode field
                      TextFormField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pincode',
                          hintText: 'Enter your pincode',
                          prefixIcon: Icon(Icons.pin_drop),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      
                      // Address field
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Full Address',
                          hintText: 'Enter your complete address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => ref.read(signupProvider.notifier).updateAddress(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Location Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGeocodingAddress ? null : _getCoordinatesFromAddress,
                              icon: _isGeocodingAddress 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(_isGeocodingAddress 
                                  ? 'Finding...' 
                                  : 'Find Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGettingLocation ? null : _getCurrentLocation,
                              icon: _isGettingLocation 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.my_location),
                              label: Text(_isGettingLocation 
                                  ? 'Detecting...' 
                                  : 'Current Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Display coordinates
                      if (_latitude != 0 && _longitude != 0)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location Found:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Latitude: ${_latitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Longitude: ${_longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                      // Display location error
                      if (_locationError != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _locationError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Security Section
                      const Text(
                        'Security',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: signupState.obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              signupState.obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              ref.read(signupProvider.notifier).togglePasswordVisibility();
                            },
                          ),
                        ),
                        onChanged: (value) => ref.read(signupProvider.notifier).updatePassword(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: signupState.obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              signupState.obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              ref.read(signupProvider.notifier).toggleConfirmPasswordVisibility();
                            },
                          ),
                        ),
                        onChanged: (value) => ref.read(signupProvider.notifier).updateConfirmPassword(value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Terms and Conditions
                      Row(
                        children: [
                          Checkbox(
                            value: signupState.agreeToTerms,
                            onChanged: (value) {
                              ref.read(signupProvider.notifier).toggleAgreeToTerms();
                            },
                          ),
                          Expanded(
                            child: Text(
                              'I agree to the Terms of Service and Privacy Policy',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Error message
                      if (signupState.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            signupState.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                      
                      // Create Account button
                      ElevatedButton(
                        onPressed: signupState.isLoading ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: signupState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }
}