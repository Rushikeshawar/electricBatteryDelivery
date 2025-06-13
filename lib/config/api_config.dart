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
  
  // Helper method to build full URLs
  static String buildUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return '$baseUrlWithoutApi$endpoint';
    }
    return '$baseUrl/$endpoint';
  }
  
  // Method to get API URL for specific endpoints
  static String getApiUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}