// lib/models/provider_models.dart - Enhanced with better error handling and null safety
import 'dart:convert';

// Provider Registration Request Model
class ProviderRegistrationRequest {
  final String? businessName;
  final String chargerType;
  final List<String> vehicleTypes;
  final String address;
  final double latitude;
  final double longitude;
  final double hourlyRate;
  final String description;
  final List<String>? amenities;
  final List<String>? images;
  final String contactNumber;

  ProviderRegistrationRequest({
    this.businessName,
    required this.chargerType,
    required this.vehicleTypes,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.hourlyRate,
    required this.description,
    this.amenities,
    this.images,
    required this.contactNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'chargerType': chargerType,
      'vehicleTypes': vehicleTypes,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'hourlyRate': hourlyRate,
      'description': description,
      'amenities': amenities,
      'images': images,
      'contactNumber': contactNumber,
    };
  }
}

// Provider Request Status Model
class ProviderRequestStatus {
  final String id;
  final String status; // PENDING, APPROVED, REJECTED
  final String? businessName;
  final String chargerType;
  final List<String> vehicleTypes;
  final String address;
  final double hourlyRate;
  final String description;
  final List<String>? amenities;
  final String contactNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;

  ProviderRequestStatus({
    required this.id,
    required this.status,
    this.businessName,
    required this.chargerType,
    required this.vehicleTypes,
    required this.address,
    required this.hourlyRate,
    required this.description,
    this.amenities,
    required this.contactNumber,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
  });

  factory ProviderRequestStatus.fromJson(Map<String, dynamic> json) {
    try {
      return ProviderRequestStatus(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'UNKNOWN',
        businessName: json['businessName']?.toString(),
        chargerType: json['chargerType']?.toString() ?? 'Type 2 AC',
        vehicleTypes: _parseStringList(json['vehicleTypes']),
        address: json['address']?.toString() ?? '',
        hourlyRate: _parseDouble(json['hourlyRate']) ?? 0.0,
        description: json['description']?.toString() ?? '',
        amenities: _parseStringList(json['amenities']),
        contactNumber: json['contactNumber']?.toString() ?? '',
        createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
        rejectionReason: json['rejectionReason']?.toString(),
      );
    } catch (e) {
      print('Error parsing ProviderRequestStatus: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

// Provider Profile Model (for approved providers)
class ProviderProfile {
  final String id;
  final String? businessName;
  final String chargerType;
  final List<String> vehicleTypes;
  final String address;
  final double latitude;
  final double longitude;
  final double hourlyRate;
  final String description;
  final List<String>? amenities;
  final List<String>? images;
  final String contactNumber;
  final bool isActive;
  final double rating;
  final int totalBookings;
  final DateTime createdAt;

  ProviderProfile({
    required this.id,
    this.businessName,
    required this.chargerType,
    required this.vehicleTypes,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.hourlyRate,
    required this.description,
    this.amenities,
    this.images,
    required this.contactNumber,
    required this.isActive,
    required this.rating,
    required this.totalBookings,
    required this.createdAt,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    try {
      return ProviderProfile(
        id: json['id']?.toString() ?? '',
        businessName: json['businessName']?.toString(),
        chargerType: json['chargerType']?.toString() ?? 'Type 2 AC',
        vehicleTypes: _parseStringList(json['vehicleTypes']),
        address: json['address']?.toString() ?? '',
        latitude: _parseDouble(json['latitude']) ?? 0.0,
        longitude: _parseDouble(json['longitude']) ?? 0.0,
        hourlyRate: _parseDouble(json['hourlyRate']) ?? 0.0,
        description: json['description']?.toString() ?? '',
        amenities: _parseStringList(json['amenities']),
        images: _parseStringList(json['images']),
        contactNumber: json['contactNumber']?.toString() ?? '',
        isActive: json['isActive'] == true,
        rating: _parseDouble(json['rating']) ?? 0.0,
        totalBookings: _parseInt(json['totalBookings']) ?? 0,
        createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing ProviderProfile: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

// Provider Slot Model
class ProviderSlot {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isAvailable;

  ProviderSlot({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
  });

  factory ProviderSlot.fromJson(Map<String, dynamic> json) {
    try {
      return ProviderSlot(
        id: json['id']?.toString() ?? '',
        dayOfWeek: json['dayOfWeek']?.toString() ?? 'MONDAY',
        startTime: json['startTime']?.toString() ?? '09:00',
        endTime: json['endTime']?.toString() ?? '10:00',
        isAvailable: json['isAvailable'] == true,
      );
    } catch (e) {
      print('Error parsing ProviderSlot: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
    };
  }
}

// Provider Booking Model
class ProviderBooking {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String vehicleType;
  final DateTime bookingDate;
  final String timeSlot;
  final String status; // PENDING, CONFIRMED, CANCELLED, COMPLETED, NO_SHOW
  final double estimatedAmount;
  final double? actualAmount;
  final DateTime createdAt;

  ProviderBooking({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.vehicleType,
    required this.bookingDate,
    required this.timeSlot,
    required this.status,
    required this.estimatedAmount,
    this.actualAmount,
    required this.createdAt,
  });

  factory ProviderBooking.fromJson(Map<String, dynamic> json) {
    try {
      return ProviderBooking(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? 'Unknown User',
        userPhone: json['userPhone']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString() ?? 'Unknown Vehicle',
        bookingDate: _parseDateTime(json['bookingDate']) ?? DateTime.now(),
        timeSlot: json['timeSlot']?.toString() ?? '09:00 - 10:00',
        status: json['status']?.toString() ?? 'PENDING',
        estimatedAmount: _parseDouble(json['estimatedAmount']) ?? 0.0,
        actualAmount: _parseDouble(json['actualAmount']),
        createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing ProviderBooking: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

// Provider Analytics Model
class ProviderAnalytics {
  final int totalBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double totalEarnings;
  final double averageRating;
  final Map<String, int> bookingsByMonth;
  final Map<String, double> earningsByMonth;

  ProviderAnalytics({
    required this.totalBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.totalEarnings,
    required this.averageRating,
    required this.bookingsByMonth,
    required this.earningsByMonth,
  });

  factory ProviderAnalytics.fromJson(Map<String, dynamic> json) {
    try {
      return ProviderAnalytics(
        totalBookings: _parseInt(json['totalBookings']) ?? 0,
        completedBookings: _parseInt(json['completedBookings']) ?? 0,
        cancelledBookings: _parseInt(json['cancelledBookings']) ?? 0,
        totalEarnings: _parseDouble(json['totalEarnings']) ?? 0.0,
        averageRating: _parseDouble(json['averageRating']) ?? 0.0,
        bookingsByMonth: _parseIntMap(json['bookingsByMonth']),
        earningsByMonth: _parseDoubleMap(json['earningsByMonth']),
      );
    } catch (e) {
      print('Error parsing ProviderAnalytics: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

// Helper functions for parsing with error handling
List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  if (value is String) {
    try {
      final decoded = json.decode(value);
      if (decoded is List) {
        return decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
    } catch (e) {
      // If it's not valid JSON, treat as single string
      return [value];
    }
  }
  return [];
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      print('Error parsing DateTime: $value');
      return null;
    }
  }
  return null;
}

Map<String, int> _parseIntMap(dynamic value) {
  if (value == null) return {};
  if (value is Map) {
    final result = <String, int>{};
    value.forEach((key, val) {
      final parsedValue = _parseInt(val);
      if (parsedValue != null) {
        result[key.toString()] = parsedValue;
      }
    });
    return result;
  }
  return {};
}

Map<String, double> _parseDoubleMap(dynamic value) {
  if (value == null) return {};
  if (value is Map) {
    final result = <String, double>{};
    value.forEach((key, val) {
      final parsedValue = _parseDouble(val);
      if (parsedValue != null) {
        result[key.toString()] = parsedValue;
      }
    });
    return result;
  }
  return {};
}