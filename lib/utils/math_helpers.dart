import 'dart:math' as math;

class Math {
  // Calculate the cosine of an angle in radians
  static double cos(double value) {
    return math.cos(value);
  }
  
  // Calculate the sine of an angle in radians
  static double sin(double value) {
    return math.sin(value);
  }
  
  // Calculate the square root of a value
  static double sqrt(double value) {
    return math.sqrt(value);
  }
  
  // Calculate the arc sine (inverse sine) of a value
  static double asin(double value) {
    return math.asin(value);
  }
  
  // Calculate the arc cosine (inverse cosine) of a value
  static double acos(double value) {
    return math.acos(value);
  }
  
  // Calculate the arc tangent (inverse tangent) of a value
  static double atan(double value) {
    return math.atan(value);
  }
  
  // Calculate the arc tangent of y/x
  static double atan2(double y, double x) {
    return math.atan2(y, x);
  }
  
  // Convert degrees to radians
  static double degToRad(double degrees) {
    return degrees * math.pi / 180.0;
  }
  
  // Convert radians to degrees
  static double radToDeg(double radians) {
    return radians * 180.0 / math.pi;
  }
  
  // Calculate distance between two coordinates using the Haversine formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    
    // Convert degrees to radians
    final double lat1Rad = degToRad(lat1);
    final double lon1Rad = degToRad(lon1);
    final double lat2Rad = degToRad(lat2);
    final double lon2Rad = degToRad(lon2);
    
    // Haversine formula
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;
    final double a = sin(dLat / 2) * sin(dLat / 2) +
                     cos(lat1Rad) * cos(lat2Rad) * 
                     sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distance in kilometers
  }
  
  // Calculate estimated travel time in minutes (rough approximation)
  static int calculateETA(double distanceInKm, {double avgSpeedKmh = 30.0}) {
    // Assume average speed of 30 km/h in urban areas unless specified
    final double hoursTaken = distanceInKm / avgSpeedKmh;
    final int minutesTaken = (hoursTaken * 60).round();
    
    // Minimum ETA is 1 minute
    return math.max(1, minutesTaken);
  }
}