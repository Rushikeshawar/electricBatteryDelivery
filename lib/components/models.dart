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
  final String batteryCapacity; // As per second version
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
  
  // Add fromJson factory constructor
  factory Station.fromJson(Map<String, dynamic> json) {
    // Handle the availableBatteryTypes list
    List<Battery> batteries = [];
    if (json['availableBatteryTypes'] != null) {
      batteries = (json['availableBatteryTypes'] as List)
          .map((item) => Battery.fromJson(item))
          .toList();
    }
    
    return Station(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      managerName: json['managerName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toIso8601String(),
      status: json['status'] ?? 'OPEN',
      etaMinutes: json['etaMinutes'] ?? 0,
      availableBatteries: json['availableBatteries'] ?? 0,
      batteryCapacity: json['batteryCapacity'] ?? '0',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      features: json['features'] ?? {},
      availableBatteryTypes: batteries,
    );
  }
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
  
  // Add fromJson factory constructor
  factory Battery.fromJson(Map<String, dynamic> json) {
    return Battery(
      id: json['id'],
      type: json['type'],
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      availableQuantity: json['availableQuantity'] ?? 0,
      voltage: (json['voltage'] ?? 0).toDouble(),
      capacity: (json['capacity'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class BatteryBooking {
  final int stationId;
  final String batteryType;
  final int quantity;
  final double totalPrice;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String deliveryNotes;

  BatteryBooking({
    required this.stationId,
    required this.batteryType,
    required this.quantity,
    required this.totalPrice,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.deliveryNotes,
  });
  
  // Add toJson method for API requests
  Map<String, dynamic> toJson() {
    return {
      'stationId': stationId,
      'batteryType': batteryType,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryNotes': deliveryNotes,
    };
  }
}

class Building {
  final String id;
  final String name;
  final String address;
  final int totalSlots;
  final int availableSlots;
  final double distance;
  final String status;
  final double price;
  final List<String> amenities;
  final Map<String, dynamic> features;
  final String imageUrl;

  Building({
    required this.id,
    required this.name,
    required this.address,
    required this.totalSlots,
    required this.availableSlots,
    required this.distance,
    required this.status,
    required this.price,
    required this.amenities,
    this.features = const {},
    this.imageUrl = '',
  });
  
  // Add fromJson factory constructor
  factory Building.fromJson(Map<String, dynamic> json) {
    List<String> amenitiesList = [];
    if (json['amenities'] != null) {
      amenitiesList = List<String>.from(json['amenities']);
    }
    
    return Building(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      totalSlots: json['totalSlots'] ?? 0,
      availableSlots: json['availableSlots'] ?? 0,
      distance: (json['distance'] ?? 0).toDouble(),
      status: json['status'] ?? 'OPEN',
      price: (json['price'] ?? 0).toDouble(),
      amenities: amenitiesList,
      features: json['features'] ?? {},
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class Order {
  final String id;
  final String type; // 'building' or 'station'
  final String locationName;
  final String date;
  final String status;
  final double amount;
  final Map<String, dynamic> details;

  Order({
    required this.id,
    required this.type,
    required this.locationName,
    required this.date,
    required this.status,
    required this.amount,
    this.details = const {},
  });
  
  // Add fromJson factory constructor
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      type: json['type'],
      locationName: json['locationName'],
      date: json['date'],
      status: json['status'],
      amount: (json['amount'] ?? 0).toDouble(),
      details: json['details'] ?? {},
    );
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String address;
  final String gender;
  final List<String> vehicles;
  final Map<String, dynamic> preferences;
  final String token;  // Add token field for authentication

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.gender,
    this.vehicles = const [],
    this.preferences = const {},
    this.token = '',  // Default empty token
  });
  
  // Add fromJson factory constructor
  factory User.fromJson(Map<String, dynamic> json) {
    List<String> vehiclesList = [];
    if (json['vehicles'] != null) {
      vehiclesList = List<String>.from(json['vehicles']);
    }
    
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      gender: json['gender'] ?? '',
      vehicles: vehiclesList,
      preferences: json['preferences'] ?? {},
      token: json['token'] ?? '',
    );
  }
}