import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/providers/signup_provider.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial state values
    _emailController.text = ref.read(signupProvider).email;
    _addressController.text = ref.read(signupProvider).address;
    _passwordController.text = ref.read(signupProvider).password;
    _confirmPasswordController.text = ref.read(signupProvider).confirmPassword;
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
        // Navigate back to login screen by popping all routes until login
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
                      
                      // Address field
                      TextFormField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Enter your address',
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
                      
                      // Location Button
                      ElevatedButton.icon(
                        onPressed: signupState.isGettingLocation 
                            ? null 
                            : () => ref.read(signupProvider.notifier).getCurrentLocation(context),
                        icon: const Icon(Icons.my_location),
                        label: Text(signupState.isGettingLocation 
                            ? 'Detecting Location...' 
                            : 'Use Current Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                      
                      // Display latitude and longitude
                      if (signupState.latitude != 0 && signupState.longitude != 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                          child: Text(
                            'Location: ${signupState.latitude.toStringAsFixed(6)}, ${signupState.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
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
    super.dispose();
  }
}