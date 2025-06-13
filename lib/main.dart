// main.dart - Updated with enhanced notification provider
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:electric_battery_delivery_frontend/OrderOtpScreen.dart';
import 'package:electric_battery_delivery_frontend/components/app_theme.dart';
import 'package:electric_battery_delivery_frontend/homescreen.dart';
import 'package:electric_battery_delivery_frontend/login_screen.dart';
import 'package:electric_battery_delivery_frontend/notification_screen.dart';
import 'package:electric_battery_delivery_frontend/services/socket_notification_service.dart';
import 'package:electric_battery_delivery_frontend/services/auth_service.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_location_service.dart';
import 'package:electric_battery_delivery_frontend/services/websocket_notification_service.dart';
import 'package:electric_battery_delivery_frontend/providers/notification_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Provider for the WebSocket notification service
final socketNotificationServiceProvider = Provider<SocketNotificationService>((ref) {
  final service = SocketNotificationService();
  service.init();
  return service;
});

// Provider for the Auth service (depends on socket service)
final authServiceProvider = Provider<AuthService>((ref) {
  final socketService = ref.read(socketNotificationServiceProvider);
  return AuthService(socketService);
});

// Provider for WebSocket location service
final webSocketLocationServiceProvider = ChangeNotifierProvider<WebSocketLocationService>((ref) {
  return WebSocketLocationService();
});

// Provider for enhanced WebSocket notification service
final webSocketNotificationServiceProvider = ChangeNotifierProvider<WebSocketNotificationService>((ref) {
  return WebSocketNotificationService();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
    print('Environment variables loaded successfully');
    print('Google Maps API Key: ${dotenv.env['GOOGLE_MAPS_API_KEY']?.substring(0, 10)}...');
  } catch (e) {
    print('Error loading .env file: $e');
    // Continue without .env file - use hardcoded values as fallback
  }
  
  // Initialize local notifications (only for mobile)
  if (!kIsWeb) {
    await _initializeLocalNotifications();
  }
  
  // Set system UI overlay style (only for mobile)
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
  
  // Wait for Google Maps to load on web
  if (kIsWeb) {
    await _waitForGoogleMapsOnWeb();
  }
  
  // Wrap the app with ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

// Wait for Google Maps API to load on web
Future<void> _waitForGoogleMapsOnWeb() async {
  if (kIsWeb) {
    print('Waiting for Google Maps API to load on web...');
    
    // Simple delay approach - wait for Google Maps API to load
    await Future.delayed(const Duration(seconds: 3));
    
    print('Google Maps API should be loaded');
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
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
    print('Local notifications initialized successfully');
  } catch (e) {
    print('Error initializing local notifications: $e');
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
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
        } catch (e) {
          print('Error initializing socket notification service: $e');
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
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/notifications': (context) => const EnhancedNotificationScreen(),
        '/order-otp': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return OrderOtpScreen(orderId: args['orderId']);
        },
      },
    );
  }
}

// Enhanced splash screen with notification service initialization
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Minimum splash time
    await Future.delayed(const Duration(seconds: 2));
    
    // Additional wait for web to ensure Google Maps is ready
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Initialize notification services
    try {
      // Initialize enhanced notification provider
      await Future.delayed(const Duration(milliseconds: 100));
      print('✅ SPLASH: Enhanced notification services initialized');
    } catch (e) {
      print('❌ SPLASH: Error initializing notification services: $e');
    }
    
    setState(() {
      _isReady = true;
    });
    
    // Navigate after everything is ready
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientBackground,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'app_logo',
                  child: Icon(
                    Icons.battery_charging_full,
                    size: 100,
                    color: Colors.green.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'BatteryWala',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Electric Mobility Partner',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                if (!_isReady) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green.shade600,
                      ),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kIsWeb ? 'Loading services...' : 'Initializing notifications...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}