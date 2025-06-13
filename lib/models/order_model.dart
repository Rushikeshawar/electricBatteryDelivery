import 'package:flutter/material.dart';

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

  // Create a copy of the order with updated fields
  Order copyWith({
    int? id,
    String? orderNumber,
    String? status,
    String? batteryType,
    int? quantity,
    double? totalPrice,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryNotes,
    int? userId,
    int? stationId,
    int? driverId,
    String? createdAt,
    String? updatedAt,
    Station? station,
    Driver? driver,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      batteryType: batteryType ?? this.batteryType,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      userId: userId ?? this.userId,
      stationId: stationId ?? this.stationId,
      driverId: driverId ?? this.driverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      station: station ?? this.station,
      driver: driver ?? this.driver,
    );
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

class Station {
  final int id;
  final String name;
  final String address;
  final String? phone;

  Station({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
    );
  }
}

class Driver {
  final int id;
  final String name;
  final String phone;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
    );
  }
}

// Pagination model
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
}

// Response model for orders list
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

// Response model for single order
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