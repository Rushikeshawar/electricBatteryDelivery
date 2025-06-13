import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/providers/signup_provider.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:electric_battery_delivery_frontend/signup_screen2.dart';

class SignupScreen1 extends ConsumerStatefulWidget {
  const SignupScreen1({super.key});

  @override
  ConsumerState<SignupScreen1> createState() => _SignupScreen1State();
}

class _SignupScreen1State extends ConsumerState<SignupScreen1> {
  // Keep a form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial state values if needed
    _nameController.text = ref.read(signupProvider).name;
    final phoneNumber = ref.read(signupProvider).phoneNumber;
    if (phoneNumber.isNotEmpty) {
      _phoneController.text = phoneNumber;
    }
  }

  void _continueToNextScreen() {
    final signupNotifier = ref.read(signupProvider.notifier);
    
    if (_formKey.currentState!.validate()) {
      // Update provider with form values
      signupNotifier.updateName(_nameController.text);
      
      // Navigate to the next screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SignupScreen2(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the signup state
    final signupState = ref.watch(signupProvider);
    final genderOptions = ref.watch(genderOptionsProvider);
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Account'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please provide your personal details',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => ref.read(signupProvider.notifier).updateName(value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone field
                    IntlPhoneField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter your phone number',
                        border: OutlineInputBorder(),
                      ),
                      initialCountryCode: 'IN',
                      onChanged: (phone) {
                        ref.read(signupProvider.notifier).updatePhoneNumber(phone.completeNumber);
                      },
                      validator: (phone) {
                        if (phone == null || phone.completeNumber.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Gender dropdown
                    DropdownButtonFormField<String>(
                      value: signupState.selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: genderOptions.map((gender) {
                        return DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(signupProvider.notifier).updateSelectedGender(value);
                        }
                      },
                    ),
                    
                    const Spacer(),
                    
                    // Continue button
                    ElevatedButton(
                      onPressed: _continueToNextScreen,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}