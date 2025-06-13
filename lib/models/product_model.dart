// models/product_model.dart

class BatteryProduct {
  final int id;
  final String name;
  final String description;
  final String batteryType;
  final String capacity;
  final String voltage;
  final double price;
  final int stockQuantity;
  final Map<String, dynamic>? specifications;
  final bool isActive;
  final int? stationId;
  final String createdAt;
  final String updatedAt;
  final ProductStation? station;

  BatteryProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.batteryType,
    required this.capacity,
    required this.voltage,
    required this.price,
    required this.stockQuantity,
    this.specifications,
    required this.isActive,
    this.stationId,
    required this.createdAt,
    required this.updatedAt,
    this.station,
  });

  // Factory constructor to create a Product from JSON
  factory BatteryProduct.fromJson(Map<String, dynamic> json) {
    return BatteryProduct(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      batteryType: json['batteryType'] ?? '',
      capacity: json['capacity'] ?? '',
      voltage: json['voltage'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stockQuantity: json['stockQuantity'] ?? 0,
      specifications: json['specifications'],
      isActive: json['isActive'] ?? true,
      stationId: json['stationId'],
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toString(),
      station: json['station'] != null 
          ? ProductStation.fromJson(json['station']) 
          : null,
    );
  }
}

class ProductStation {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  ProductStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  // Factory constructor to create a ProductStation from JSON
  factory ProductStation.fromJson(Map<String, dynamic> json) {
    return ProductStation(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
    );
  }
}