// models/station_model.dart
class NearbyStation {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance; // in kilometers
  
  // Additional properties that might be available or can be populated with defaults
  final String status;
  final String managerName;
  final String email;
  final String phone;
  final int etaMinutes;
  final int availableBatteries;
  final double price;
  final String imageUrl;
  final List<NearbyBattery> availableBatteryTypes;
  
  NearbyStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    this.status = 'Available', // Default value
    this.managerName = '',
    this.email = '',
    this.phone = '',
    this.etaMinutes = 0,
    this.availableBatteries = 0,
    this.price = 0.0,
    this.imageUrl = '',
    this.availableBatteryTypes = const [],
  });
  
  // Factory constructor to create a NearbyStation from JSON
  factory NearbyStation.fromJson(Map<String, dynamic> json) {
    return NearbyStation(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      distance: json['distance']?.toDouble() ?? 0.0,
      status: json['status'] ?? 'Available',
      managerName: json['managerName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      etaMinutes: json['etaMinutes'] ?? 0,
      availableBatteries: json['availableBatteries'] ?? 0,
      price: json['price']?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] ?? '',
      // Parse battery types if available
      availableBatteryTypes: json['availableBatteryTypes'] != null
          ? (json['availableBatteryTypes'] as List)
              .map((e) => NearbyBattery.fromJson(e))
              .toList()
          : [],
    );
  }
}

class NearbyBattery {
  final int id;
  final String type;
  final String description;
  final double price;
  final int availableQuantity;
  final double voltage;
  final double capacity;
  final String imageUrl;
  
  NearbyBattery({
    required this.id,
    required this.type,
    required this.description,
    required this.price,
    required this.availableQuantity,
    required this.voltage,
    required this.capacity,
    this.imageUrl = '',
  });
  
  // Factory constructor to create a NearbyBattery from JSON
  factory NearbyBattery.fromJson(Map<String, dynamic> json) {
    return NearbyBattery(
      id: json['id'],
      type: json['type'],
      description: json['description'] ?? '',
      price: json['price']?.toDouble() ?? 0.0,
      availableQuantity: json['availableQuantity'] ?? 0,
      voltage: json['voltage']?.toDouble() ?? 0.0,
      capacity: json['capacity']?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class Station {
  final int id;
  final String name;
  final String address;
  final String managerName;
  final String email;
  final String phone;
  final double latitude;
  final double longitude;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  
  final String status;
  final int etaMinutes;
  final int availableBatteries;
  final String batteryCapacity;
  final double price;
  final String imageUrl;
  final Map<String, dynamic> features;
  final List<Battery> availableBatteryTypes;
  
  Station({
    required this.id,
    required this.name,
    required this.address,
    required this.managerName,
    required this.email,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.etaMinutes,
    required this.availableBatteries,
    required this.batteryCapacity,
    required this.price,
    this.imageUrl = '',
    this.features = const {},
    this.availableBatteryTypes = const [],
  });
}

class Battery {
  final int id;
  final String type;
  final String description;
  final double price;
  final int availableQuantity;
  final double voltage;
  final double capacity;
  final String imageUrl;
  
  Battery({
    required this.id,
    required this.type,
    required this.description,
    required this.price,
    required this.availableQuantity,
    required this.voltage,
    required this.capacity,
    required this.imageUrl,
  });
}