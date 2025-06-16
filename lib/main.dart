// main.dart - Cleaned version keeping login->homescreen flow intact
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Core screens (keep existing)
import 'package:electric_battery_delivery_frontend/OrderOtpScreen.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/homescreen.dart'; // Keep this
import 'package:electric_battery_delivery_frontend/login_screen.dart'; // Keep this
import 'package:electric_battery_delivery_frontend/notification_screen.dart';

// Services (keep existing)
import 'package:electric_battery_delivery_frontend/services/socket_notification_service.dart';
import 'package:electric_battery_delivery_frontend/services/auth_service.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_location_service.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_notification_service.dart';
import 'package:electric_battery_delivery_frontend/providers/notification_provider.dart';

// PowerPoint Customer functionality (consolidated)
import 'package:electric_battery_delivery_frontend/screens/charging_providers_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_details_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/slot_booking_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/booking_confirmation_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/booking_details_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/my_bookings_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/write_review_screen.dart';

// Service Provider functionality
import 'package:electric_battery_delivery_frontend/screens/become_provider_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_status_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_dashboard_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_bookings_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_slots_screen.dart';
import 'package:electric_battery_delivery_frontend/screens/provider_profile_screen.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Service providers (keep existing)
final socketNotificationServiceProvider = Provider<SocketNotificationService>((ref) {
  final service = SocketNotificationService();
  service.init();
  return service;
});

final authServiceProvider = Provider<AuthService>((ref) {
  final socketService = ref.read(socketNotificationServiceProvider);
  return AuthService(socketService);
});

final webSocketLocationServiceProvider = ChangeNotifierProvider<WebSocketLocationService>((ref) {
  return WebSocketLocationService();
});

final webSocketNotificationServiceProvider = ChangeNotifierProvider<WebSocketNotificationService>((ref) {
  return WebSocketNotificationService();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded successfully');
    print('📍 Google Maps API Key: ${dotenv.env['GOOGLE_MAPS_API_KEY']?.substring(0, 10)}...');
  } catch (e) {
    print('⚠️ Error loading .env file: $e');
    print('🔄 Continuing with fallback configuration...');
  }
  
  // Initialize local notifications (only for mobile)
  if (!kIsWeb) {
    await _initializeLocalNotifications();
    _setSystemUIStyle();
  }
  
  // Wait for Google Maps to load on web
  if (kIsWeb) {
    await _waitForGoogleMapsOnWeb();
  }
  
  // Wrap the app with ProviderScope
  runApp(const ProviderScope(child: BatteryWalaApp()));
}

// Wait for Google Maps API to load on web
Future<void> _waitForGoogleMapsOnWeb() async {
  if (kIsWeb) {
    print('🌐 Waiting for Google Maps API to load on web...');
    await Future.delayed(const Duration(seconds: 3));
    print('✅ Google Maps API should be loaded');
  }
}

// Initialize local notifications (mobile only)
Future<void> _initializeLocalNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
      
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
  try {
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('📱 Notification tapped: ${response.payload}');
      },
    );
    print('✅ Local notifications initialized successfully');
  } catch (e) {
    print('❌ Error initializing local notifications: $e');
  }
}

// Set system UI overlay style (mobile only)
void _setSystemUIStyle() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

class BatteryWalaApp extends ConsumerStatefulWidget {
  const BatteryWalaApp({super.key});

  @override
  ConsumerState<BatteryWalaApp> createState() => _BatteryWalaAppState();
}

class _BatteryWalaAppState extends ConsumerState<BatteryWalaApp> {
  @override
  void initState() {
    super.initState();
    
    // Initialize services when app starts (mobile only)
    if (!kIsWeb) {
      Future.microtask(() {
        try {
          // Initialize the socket notification service
          final notificationService = ref.read(socketNotificationServiceProvider);
          
          // Set up notification handling after the app is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notificationService.setupNotificationHandling(context);
          });
          print('✅ Socket notification service initialized');
        } catch (e) {
          print('❌ Error initializing socket notification service: $e');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BatteryWala',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: _buildAppRoutes(),
      onUnknownRoute: _handleUnknownRoute,
    );
  }

  // Organized route structure
  Map<String, WidgetBuilder> _buildAppRoutes() {
    return {
      // === CORE APP ROUTES ===
      '/login': (context) => const LoginScreen(),
      '/dashboard': (context) => const DashboardScreen(), // Your homescreen.dart
      '/notifications': (context) => const EnhancedNotificationScreen(),
      '/order-otp': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return OrderOtpScreen(orderId: args['orderId']);
      },
      
      // === CHARGING STATIONS (PowerPoint) ===
      '/find-stations': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
        return ChargingProvidersScreen(
          userName: args?['userName'] ?? 'User',
          userEmail: args?['userEmail'] ?? '',
        );
      },
      '/station-details': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return ProviderDetailsScreen(
          providerId: args['providerId'],
          userName: args['userName'] ?? 'User',
          userEmail: args['userEmail'] ?? '',
        );
      },
      '/book-slot': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return SlotBookingScreen(
          provider: args['provider'],
          userName: args['userName'] ?? 'User',
          userEmail: args['userEmail'] ?? '',
        );
      },
      '/booking-confirmation': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return BookingConfirmationScreen(
          booking: args['booking'],
          provider: args['provider'],
          userName: args['userName'] ?? 'User',
          userEmail: args['userEmail'] ?? '',
        );
      },
      '/booking-details': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return BookingDetailsScreen(
          bookingId: args['bookingId'],
          userName: args['userName'] ?? 'User',
          userEmail: args['userEmail'] ?? '',
        );
      },
      '/my-bookings': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
        return MyBookingsScreen(
          userName: args?['userName'] ?? 'User',
          userEmail: args?['userEmail'] ?? '',
        );
      },
      '/write-review': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return WriteReviewScreen(
          booking: args['booking'],
          userName: args['userName'] ?? 'User',
          userEmail: args['userEmail'] ?? '',
        );
      },
      
      // === PROVIDER ROUTES ===
      '/become-provider': (context) => const BecomeProviderScreen(),
      '/provider-status': (context) => const ProviderStatusScreen(),
      '/provider-dashboard': (context) => const ProviderDashboardScreen(),
      '/provider-bookings': (context) => const ProviderBookingsScreen(),
      '/provider-slots': (context) => const ProviderSlotsScreen(),
      '/provider-profile': (context) => const ProviderProfileScreen(),
    };
  }

  // Handle unknown routes gracefully
  Route<dynamic> _handleUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops! Page Not Found',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The page "${settings.name}" doesn\'t exist.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red.shade500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard', // Goes to your homescreen.dart
                    (route) => false,
                  ),
                  icon: const Icon(Icons.home),
                  label: const Text('Go Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced splash screen with better animations
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;
  
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
    _pulseController.repeat(reverse: true);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Minimum splash time for branding
    await Future.delayed(const Duration(milliseconds: 2500));
    
    // Additional wait for web to ensure Google Maps is ready
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 800));
    }
    
    // Initialize notification services
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      print('✅ SPLASH: Enhanced notification services initialized');
      print('⚡ SPLASH: PowerPoint provider functionality ready');
      print('🏢 SPLASH: Service provider functionality ready');
      print('🚀 SPLASH: App ready to launch');
    } catch (e) {
      print('❌ SPLASH: Error initializing notification services: $e');
    }
    
    if (mounted) {
      setState(() => _isReady = true);
      
      // Wait a moment to show "Ready" state
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Navigate to login screen (keeping your existing flow)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  )),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Hero(
                      tag: 'app_logo',
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              spreadRadius: 0,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ScaleTransition(
                          scale: _pulseAnimation,
                          child: Icon(
                            Icons.battery_charging_full,
                            size: 60,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // App title with slide animation
                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Column(
                      children: [
                        Text(
                          'BatteryWala',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your Electric Mobility Partner',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.ev_station,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PowerPoint Charging Network',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Status indicator
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: _isReady
                        ? Container(
                            key: const ValueKey('ready'),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Ready to power up!',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            key: const ValueKey('loading'),
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                kIsWeb 
                                    ? '🌐 Loading PowerPoint services...' 
                                    : '⚡ Initializing your experience...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}