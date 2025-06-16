// lib/config/api_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Private constructor to prevent instantiation
  ApiConfig._();
  
  // Get the base API URL from environment variables
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      // Fallback to localhost if env variable is not set
      return 'http://localhost:3000/api';
    }
    return url;
  }
  
  // Get the base URL without /api suffix (for cases where you need just the base)
  static String get baseUrlWithoutApi {
    final url = baseUrl;
    if (url.endsWith('/api')) {
      return url.substring(0, url.length - 4);
    }
    return url;
  }
  
  // Specific endpoint URLs
  static String get authUrl => '$baseUrl/users';
  static String get ordersUrl => '$baseUrl/users/orders';
  static String get stationsUrl => '$baseUrl/users/stations';
  static String get productsUrl => '$baseUrl/users/products';
  static String get notificationsUrl => '$baseUrl/notifications';
  static String get profileUrl => '$baseUrl/users/profile';
  static String get providersUrl => '$baseUrl/providers';
  
  // Provider specific endpoints
  static String get providerProfileUrl => '$baseUrl/providers/provider-profile';
  static String get providerSlotsUrl => '$baseUrl/providers/provider-slots';
  static String get providerBookingsUrl => '$baseUrl/providers/provider-bookings';
  static String get providerAnalyticsUrl => '$baseUrl/providers/provider-analytics';
  static String get providerRequestStatusUrl => '$baseUrl/providers/provider-request-status';
  static String get submitProviderRequestUrl => '$baseUrl/providers/submit-request';
  static String get updateProviderRequestUrl => '$baseUrl/providers/update-request';
  static String get cancelProviderRequestUrl => '$baseUrl/providers/cancel-request';
  
  // Helper method to build full URLs
  static String buildUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return '$baseUrlWithoutApi$endpoint';
    }
    return '$baseUrl/$endpoint';
  }
  
  // Method to get API URL for specific endpoints
  static String getApiUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return '$baseUrl$endpoint';
    }
    return '$baseUrl/$endpoint';
  }
  
  // Helper method to build provider endpoint URLs
  static String buildProviderUrl(String endpoint) {
    return '$providersUrl/$endpoint';
  }
  
  // Common headers for API requests
  static Map<String, String> getHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Method to validate if API URL is properly configured
  static bool isConfigured() {
    final url = dotenv.env['API_BASE_URL'];
    return url != null && url.isNotEmpty && url != 'YOUR_API_BASE_URL';
  }
  
  // Method to get configuration status for debugging
  static Map<String, dynamic> getConfigStatus() {
    return {
      'isConfigured': isConfigured(),
      'baseUrl': baseUrl,
      'hasEnvFile': dotenv.env.isNotEmpty,
      'envApiUrl': dotenv.env['API_BASE_URL'] ?? 'Not set',
    };
  }
}