// maps_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // For pi constant
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsService {
  static const String _baseUrl = "https://maps.googleapis.com/maps/api";
  // Use your provided API key
  static const String _apiKey = "AIzaSyCNzv5dm49jPvCNrgaf0G8SUbQVodDJh0w";
  
  // Get directions between two points
  static Future<Map<String, dynamic>> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    final String url = 
        "$_baseUrl/directions/json?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving"
        "&key=$_apiKey";
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        
        // Check if the API returned a valid route
        if (decodedData['status'] == 'OK') {
          // Get route
          final route = decodedData['routes'][0];
          final leg = route['legs'][0];
          
          // Get distance and duration text
          final distance = leg['distance']['text'];
          final duration = leg['duration']['text'];
          
          // Decode polyline points
          final points = route['overview_polyline']['points'];
          final polylinePoints = PolylinePoints().decodePolyline(points);
          final polylineCoordinates = polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          return {
            'distance': distance,
            'duration': duration,
            'polyline_coordinates': polylineCoordinates,
            'start_address': leg['start_address'],
            'end_address': leg['end_address'],
            'steps': leg['steps'],
          };
        } else {
          throw Exception('Failed to get directions: ${decodedData['status']}');
        }
      } else {
        throw Exception('Failed to connect to the directions API');
      }
    } catch (e) {
      debugPrint('Error getting directions: $e');
      throw Exception('Error getting directions: $e');
    }
  }
  
  // Get place details by place_id
  static Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final String url = 
        "$_baseUrl/place/details/json?place_id=$placeId"
        "&fields=name,formatted_address,geometry,type"
        "&key=$_apiKey";
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        
        if (decodedData['status'] == 'OK') {
          return decodedData['result'];
        } else {
          throw Exception('Failed to get place details: ${decodedData['status']}');
        }
      } else {
        throw Exception('Failed to connect to the places API');
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      throw Exception('Error getting place details: $e');
    }
  }
  
  // Search for places nearby
  static Future<List<Map<String, dynamic>>> searchNearbyPlaces(
    LatLng location,
    String keyword,
    int radius,
  ) async {
    final String url = 
        "$_baseUrl/place/nearbysearch/json?location=${location.latitude},${location.longitude}"
        "&radius=$radius"
        "&keyword=$keyword"
        "&key=$_apiKey";
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        
        if (decodedData['status'] == 'OK' || decodedData['status'] == 'ZERO_RESULTS') {
          return List<Map<String, dynamic>>.from(decodedData['results'] ?? []);
        } else {
          throw Exception('Failed to search places: ${decodedData['status']}');
        }
      } else {
        throw Exception('Failed to connect to the places API');
      }
    } catch (e) {
      debugPrint('Error searching places: $e');
      throw Exception('Error searching places: $e');
    }
  }
  
  // Geocode address to coordinates
  static Future<LatLng> geocodeAddress(String address) async {
    final String url = 
        "$_baseUrl/geocode/json?address=${Uri.encodeComponent(address)}"
        "&key=$_apiKey";
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        
        if (decodedData['status'] == 'OK') {
          final location = decodedData['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          throw Exception('Failed to geocode address: ${decodedData['status']}');
        }
      } else {
        throw Exception('Failed to connect to the geocoding API');
      }
    } catch (e) {
      debugPrint('Error geocoding address: $e');
      throw Exception('Error geocoding address: $e');
    }
  }
  
  // Calculate ETA between two points in minutes
  static Future<int> calculateETA(LatLng origin, LatLng destination) async {
    try {
      final directions = await getDirections(origin, destination);
      // Extract the duration text (e.g., "15 mins" or "1 hour 20 mins")
      final durationText = directions['duration'];
      
      // Parse the duration text to extract minutes
      int minutes = 0;
      
      if (durationText.contains('hour') || durationText.contains('hours')) {
        // Handle hours and minutes format
        final parts = durationText.split(' ');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i] == 'hour' || parts[i] == 'hours') {
            minutes += int.parse(parts[i - 1]) * 60;
          } else if (parts[i] == 'min' || parts[i] == 'mins') {
            minutes += int.parse(parts[i - 1]);
          }
        }
      } else {
        // Handle only minutes format
        minutes = int.parse(durationText.split(' ')[0]);
      }
      
      return minutes;
    } catch (e) {
      // If API call fails, calculate a rough estimate
      // using straight-line distance (1 km ≈ 2 mins)
      final double distanceInKm = calculateDistance(origin, destination);
      return (distanceInKm * 2).round();
    }
  }
  
  // Calculate straight-line distance between two points in kilometers
  static double calculateDistance(LatLng origin, LatLng destination) {
    const double earthRadius = 6371; // in kilometers
    
    // Convert latitudes and longitudes from degrees to radians
    final double lat1 = origin.latitude * (pi / 180);
    final double lon1 = origin.longitude * (pi / 180);
    final double lat2 = destination.latitude * (pi / 180);
    final double lon2 = destination.longitude * (pi / 180);
    
    // Haversine formula
    final double dlon = lon2 - lon1;
    final double dlat = lat2 - lat1;
    
    final double a = pow(sin(dlat / 2), 2) + 
                   cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    // Distance in kilometers
    final double distance = earthRadius * c;
    
    return distance;
  }
}