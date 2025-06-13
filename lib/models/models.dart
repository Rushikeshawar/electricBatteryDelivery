import 'package:flutter/material.dart';

// User Model
class User {
  final int id;
  final String name;
  final String email;
  final String token;
  final String? phone;
  final String? profilePicture;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.phone,
    this.profilePicture,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      token: json['token'],
      phone: json['phone'],
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
      'phone': phone,
      'profilePicture': profilePicture,
    };
  }
}

// Battery Model
class Battery {
  final int id;
  final String type;
  final double voltage;
  final double capacity;
  final double price;
  final int availableQuantity;
  final String description;
  final Station station;

  Battery({
    required this.id,
    required this.type,
    required this.voltage,
    required this.capacity,
    required this.price,
    required this.availableQuantity,
    required this.description,
    required this.station,
  });

  factory Battery.fromJson(Map<String, dynamic> json) {
    return Battery(
      id: json['id'],
      type: json['type'],
      voltage: json['voltage'].toDouble(),
      capacity: json['capacity'].toDouble(),
      price: json['price'].toDouble(),
      availableQuantity: json['availableQuantity'],
      description: json['description'],
      station: Station.fromJson(json['station']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'voltage': voltage,
      'capacity': capacity,
      'price': price,
      'availableQuantity': availableQuantity,
      'description': description,
      'station': station.toJson(),
    };
  }
}

// Station Model
// lib/components/models.dart - Add these properties to your Station class

// Updated Station Model with required properties
class Station {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final bool isActive;
  final String status;  // Add status
  final int availableBatteries;  // Add availableBatteries
  final double price;  // Add price
  final int etaMinutes;  // Add etaMinutes
  final String imageUrl;  // Add imageUrl
  final double rating;  // Add rating
  final bool isFavorite;  // Add isFavorite

  Station({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.isActive = true,
    this.status = 'Available',
    this.availableBatteries = 0,
    this.price = 0.0,
    this.etaMinutes = 0,
    this.imageUrl = '',
    this.rating = 0.0,
    this.isFavorite = false,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      phone: json['phone'],
      isActive: json['isActive'] ?? true,
      status: json['status'] ?? 'Available',
      availableBatteries: json['availableBatteries'] ?? 0,
      price: json['price']?.toDouble() ?? 0.0,
      etaMinutes: json['etaMinutes'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
      rating: json['rating']?.toDouble() ?? 0.0,
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'isActive': isActive,
      'status': status,
      'availableBatteries': availableBatteries,
      'price': price,
      'etaMinutes': etaMinutes,
      'imageUrl': imageUrl,
      'rating': rating,
      'isFavorite': isFavorite,
    };
  }
}
// Driver Model
class Driver {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? profilePicture;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.profilePicture,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      profilePicture: json['profilePicture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'profilePicture': profilePicture,
    };
  }
}

// Order Model
class Order {
  final int id;
  final String orderNumber;
  final String status;
  final String batteryType;
  final int quantity;
  final double totalPrice;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? deliveryNotes;
  final int userId;
  final int stationId;
  final int? driverId;
  final String createdAt;
  final String updatedAt;
  final Station station;
  final Driver? driver;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.batteryType,
    required this.quantity,
    required this.totalPrice,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.deliveryNotes,
    required this.userId,
    required this.stationId,
    this.driverId,
    required this.createdAt,
    required this.updatedAt,
    required this.station,
    this.driver,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['orderNumber'],
      status: json['status'],
      batteryType: json['batteryType'],
      quantity: json['quantity'],
      totalPrice: json['totalPrice'].toDouble(),
      deliveryAddress: json['deliveryAddress'],
      deliveryLatitude: json['deliveryLatitude'].toDouble(),
      deliveryLongitude: json['deliveryLongitude'].toDouble(),
      deliveryNotes: json['deliveryNotes'],
      userId: json['userId'],
      stationId: json['stationId'],
      driverId: json['driverId'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      station: Station.fromJson(json['station']),
      driver: json['driver'] != null ? Driver.fromJson(json['driver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'status': status,
      'batteryType': batteryType,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'deliveryNotes': deliveryNotes,
      'userId': userId,
      'stationId': stationId,
      'driverId': driverId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'station': station.toJson(),
      'driver': driver?.toJson(),
    };
  }

  String get formattedStatus {
    return status.substring(0, 1) + status.substring(1).toLowerCase();
  }

  String get formattedDate {
    final date = DateTime.parse(createdAt);
    return "${date.day}/${date.month}/${date.year}";
  }

  Map<String, dynamic> get details {
    return {
      'Battery Type': batteryType,
      'Quantity': quantity.toString(),
      'Station': station.name,
      'Address': station.address,
      'Station Phone': station.phone ?? 'N/A',
      'Driver': driver?.name ?? 'Not Assigned',
      'Driver Phone': driver?.phone ?? 'N/A',
      'Delivery Address': deliveryAddress,
      'Delivery Notes': deliveryNotes ?? 'None',
    };
  }

  Color get statusColor {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'ASSIGNED':
        return Colors.purple;
      case 'PICKED_UP':
        return Colors.indigo;
      case 'IN_TRANSIT':
        return Colors.teal;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// Battery Booking Model
class BatteryBooking {
  final int? id;
  final int stationId;
  final String batteryType;
  final int quantity;
  final double totalPrice;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? deliveryNotes;

  BatteryBooking({
    this.id,
    required this.stationId,
    required this.batteryType,
    required this.quantity,
    required this.totalPrice,
    required this.deliveryAddress,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.deliveryNotes,
  });

  factory BatteryBooking.fromJson(Map<String, dynamic> json) {
    return BatteryBooking(
      id: json['id'],
      stationId: json['stationId'],
      batteryType: json['batteryType'],
      quantity: json['quantity'],
      totalPrice: json['totalPrice'].toDouble(),
      deliveryAddress: json['deliveryAddress'],
      deliveryLatitude: json['deliveryLatitude'].toDouble(),
      deliveryLongitude: json['deliveryLongitude'].toDouble(),
      deliveryNotes: json['deliveryNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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

// Pagination Model
class PaginationInfo {
  final int total;
  final int page;
  final int pages;
  final int limit;

  PaginationInfo({
    required this.total,
    required this.page,
    required this.pages,
    required this.limit,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'],
      page: json['page'],
      pages: json['pages'],
      limit: json['limit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'page': page,
      'pages': pages,
      'limit': limit,
    };
  }
}

// Response Models
class OrdersResponse {
  final bool success;
  final List<Order> data;
  final PaginationInfo pagination;

  OrdersResponse({
    required this.success,
    required this.data,
    required this.pagination,
  });

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    final ordersList = (json['data'] as List)
        .map((orderJson) => Order.fromJson(orderJson))
        .toList();
        
    return OrdersResponse(
      success: json['success'],
      data: ordersList,
      pagination: PaginationInfo.fromJson(json['pagination']),
    );
  }
}

class OrderResponse {
  final bool success;
  final Order data;

  OrderResponse({
    required this.success,
    required this.data,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      success: json['success'],
      data: Order.fromJson(json['data']),
    );
  }
}

// Price Summary Model
class PriceSummary {
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double total;

  PriceSummary({
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
  });
}