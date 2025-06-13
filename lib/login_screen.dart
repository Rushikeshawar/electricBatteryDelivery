import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/components/layout.dart';
import 'package:electric_battery_delivery_frontend/providers/login_provider.dart';
import 'package:electric_battery_delivery_frontend/signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _navigateToHome() {
    final user = ref.read(userProvider);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Layout(
          userName: user.name,
          userEmail: user.email,
          phoneNumber: user.phoneNumber,
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final loginNotifier = ref.read(loginProvider.notifier);
      final success = await loginNotifier.login(
        _emailController.text,
        _passwordController.text,
        context,
      );

      if (success && mounted) {
        _navigateToHome();
      } else if (mounted) {
        final errorMessage = ref.read(loginProvider).errorMessage;
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
  }

  @override
  Widget build(BuildContext context) {
    // Watch the login state
    final loginState = ref.watch(loginProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.gradientBackground,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and Headers
                    _buildHeader(),
                    const SizedBox(height: 40),

                    // Login Form Card
                    Container(
                      decoration: AppTheme.cardDecoration,
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome Back',
                              style: AppTheme.titleStyle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue',
                              style: AppTheme.subheadingStyle,
                            ),
                            const SizedBox(height: 24),

                            // Email Field
                            _buildEmailField(),
                            const SizedBox(height: 16),

                            // Password Field
                            _buildPasswordField(loginState),
                            const SizedBox(height: 16),

                            // Remember Me & Forgot Password
                            _buildRememberMeAndForgotPassword(loginState),
                            const SizedBox(height: 24),

                            // Login Button
                            _buildLoginButton(loginState),
                            const SizedBox(height: 24),

                            // Signup Link
                            _buildSignupLink(),
                          ],
                        ),
                      ),
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

  Widget _buildHeader() {
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Icon(
            Icons.battery_charging_full,
            size: 64,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'BatteryWala',
          style: AppTheme.headingStyle,
        ),
        const SizedBox(height: 8),
        Text(
          'Your Electric Mobility Partner',
          style: AppTheme.subheadingStyle,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildPasswordField(LoginState loginState) {
    return TextFormField(
      controller: _passwordController,
      obscureText: loginState.obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            loginState.obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            ref.read(loginProvider.notifier).togglePasswordVisibility();
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildRememberMeAndForgotPassword(LoginState loginState) {
    return Row(
      children: [
        // Remember Me
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: loginState.rememberMe,
                onChanged: (value) {
                  ref.read(loginProvider.notifier).toggleRememberMe();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Remember me',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Forgot Password
        TextButton(
          onPressed: () {
            ref.read(loginProvider.notifier).forgotPassword();
          },
          child: const Text('Forgot Password?'),
        ),
      ],
    );
  }

  Widget _buildLoginButton(LoginState loginState) {
    return ElevatedButton(
      onPressed: loginState.isLoading ? null : _handleLogin,
      child: loginState.isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.green.shade50,
                ),
              ),
            )
          : const Text('Login'),
    );
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SignupScreen1(),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Sign up'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}