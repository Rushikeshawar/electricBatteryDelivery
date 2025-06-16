class ChargingProvider {
  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final double rating;
  final int reviewCount;
  final double hourlyRate;
  final String imageUrl;
  final String description;
  final String contactNumber;
  final String email;
  final List<String> amenities;
  final List<ChargerType> chargerTypes;
  final List<VehicleType> supportedVehicles;
  final List<ChargingSlot> slots;
  final bool isActive;
  final String operatingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChargingProvider({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.rating,
    required this.reviewCount,
    required this.hourlyRate,
    this.imageUrl = '',
    this.description = '',
    this.contactNumber = '',
    this.email = '',
    this.amenities = const [],
    this.chargerTypes = const [],
    this.supportedVehicles = const [],
    this.slots = const [],
    this.isActive = true,
    this.operatingHours = '24/7',
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChargingProvider.fromJson(Map<String, dynamic> json) {
    return ChargingProvider(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      distance: (json['distance'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      email: json['email'] ?? '',
      amenities: List<String>.from(json['amenities'] ?? []),
      chargerTypes: (json['chargerTypes'] as List<dynamic>?)
          ?.map((x) => ChargerType.fromJson(x))
          .toList() ?? [],
      supportedVehicles: (json['supportedVehicles'] as List<dynamic>?)
          ?.map((x) => VehicleType.fromJson(x))
          .toList() ?? [],
      slots: (json['slots'] as List<dynamic>?)
          ?.map((x) => ChargingSlot.fromJson(x))
          .toList() ?? [],
      isActive: json['isActive'] ?? true,
      operatingHours: json['operatingHours'] ?? '24/7',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'rating': rating,
      'reviewCount': reviewCount,
      'hourlyRate': hourlyRate,
      'imageUrl': imageUrl,
      'description': description,
      'contactNumber': contactNumber,
      'email': email,
      'amenities': amenities,
      'chargerTypes': chargerTypes.map((x) => x.toJson()).toList(),
      'supportedVehicles': supportedVehicles.map((x) => x.toJson()).toList(),
      'slots': slots.map((x) => x.toJson()).toList(),
      'isActive': isActive,
      'operatingHours': operatingHours,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ChargerType {
  final int id;
  final String name;
  final String description;
  final double maxPower;
  final String connectorType;

  ChargerType({
    required this.id,
    required this.name,
    required this.description,
    required this.maxPower,
    required this.connectorType,
  });

  factory ChargerType.fromJson(Map<String, dynamic> json) {
    return ChargerType(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      maxPower: (json['maxPower'] ?? 0).toDouble(),
      connectorType: json['connectorType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'maxPower': maxPower,
      'connectorType': connectorType,
    };
  }
}

class VehicleType {
  final int id;
  final String name;
  final String category;

  VehicleType({
    required this.id,
    required this.name,
    required this.category,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
    };
  }
}

class ChargingSlot {
  final int id;
  final String name;
  final int chargerTypeId;
  final ChargerType? chargerType;
  final bool isAvailable;
  final String status;
  final double hourlyRate;

  ChargingSlot({
    required this.id,
    required this.name,
    required this.chargerTypeId,
    this.chargerType,
    required this.isAvailable,
    required this.status,
    required this.hourlyRate,
  });

  factory ChargingSlot.fromJson(Map<String, dynamic> json) {
    return ChargingSlot(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      chargerTypeId: json['chargerTypeId'] ?? 0,
      chargerType: json['chargerType'] != null 
          ? ChargerType.fromJson(json['chargerType']) 
          : null,
      isAvailable: json['isAvailable'] ?? false,
      status: json['status'] ?? 'UNAVAILABLE',
      hourlyRate: (json['hourlyRate'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chargerTypeId': chargerTypeId,
      'chargerType': chargerType?.toJson(),
      'isAvailable': isAvailable,
      'status': status,
      'hourlyRate': hourlyRate,
    };
  }
}

class Booking {
  final int id;
  final int providerId;
  final ChargingProvider? provider;
  final int slotId;
  final ChargingSlot? slot;
  final String bookingDate;
  final String status;
  final String vehicleType;
  final String? vehicleNumber;
  final String? specialNotes;
  final double totalAmount;
  final String? reason;
  final DateTime createdAt;
  final DateTime updatedAt;

  Booking({
    required this.id,
    required this.providerId,
    this.provider,
    required this.slotId,
    this.slot,
    required this.bookingDate,
    required this.status,
    required this.vehicleType,
    this.vehicleNumber,
    this.specialNotes,
    required this.totalAmount,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? 0,
      providerId: json['providerId'] ?? 0,
      provider: json['provider'] != null 
          ? ChargingProvider.fromJson(json['provider']) 
          : null,
      slotId: json['slotId'] ?? 0,
      slot: json['slot'] != null 
          ? ChargingSlot.fromJson(json['slot']) 
          : null,
      bookingDate: json['bookingDate'] ?? '',
      status: json['status'] ?? 'PENDING',
      vehicleType: json['vehicleType'] ?? '',
      vehicleNumber: json['vehicleNumber'],
      specialNotes: json['specialNotes'],
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      reason: json['reason'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'provider': provider?.toJson(),
      'slotId': slotId,
      'slot': slot?.toJson(),
      'bookingDate': bookingDate,
      'status': status,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'specialNotes': specialNotes,
      'totalAmount': totalAmount,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Booking copyWith({
    int? id,
    int? providerId,
    ChargingProvider? provider,
    int? slotId,
    ChargingSlot? slot,
    String? bookingDate,
    String? status,
    String? vehicleType,
    String? vehicleNumber,
    String? specialNotes,
    double? totalAmount,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      provider: provider ?? this.provider,
      slotId: slotId ?? this.slotId,
      slot: slot ?? this.slot,
      bookingDate: bookingDate ?? this.bookingDate,
      status: status ?? this.status,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      specialNotes: specialNotes ?? this.specialNotes,
      totalAmount: totalAmount ?? this.totalAmount,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Review {
  final int id;
  final int providerId;
  final int? bookingId;
  final String userName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.providerId,
    this.bookingId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? 0,
      providerId: json['providerId'] ?? 0,
      bookingId: json['bookingId'],
      userName: json['userName'] ?? 'Anonymous',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'bookingId': bookingId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

// Response classes
class ProvidersResponse {
  final List<ChargingProvider> data;
  final PaginationInfo? pagination;

  ProvidersResponse({
    required this.data,
    this.pagination,
  });

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) {
    return ProvidersResponse(
      data: (json['data'] as List<dynamic>)
          .map((x) => ChargingProvider.fromJson(x))
          .toList(),
      pagination: json['pagination'] != null 
          ? PaginationInfo.fromJson(json['pagination']) 
          : null,
    );
  }
}

class ProviderResponse {
  final ChargingProvider data;

  ProviderResponse({required this.data});

  factory ProviderResponse.fromJson(Map<String, dynamic> json) {
    return ProviderResponse(
      data: ChargingProvider.fromJson(json['data']),
    );
  }
}

class BookingsResponse {
  final List<Booking> data;
  final PaginationInfo? pagination;

  BookingsResponse({
    required this.data,
    this.pagination,
  });

  factory BookingsResponse.fromJson(Map<String, dynamic> json) {
    return BookingsResponse(
      data: (json['data'] as List<dynamic>)
          .map((x) => Booking.fromJson(x))
          .toList(),
      pagination: json['pagination'] != null 
          ? PaginationInfo.fromJson(json['pagination']) 
          : null,
    );
  }
}

class BookingResponse {
  final Booking data;

  BookingResponse({required this.data});

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      data: Booking.fromJson(json['data']),
    );
  }
}

class PaginationInfo {
  final int page;
  final int limit;
  final int total;
  final int pages;

  PaginationInfo({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 1,
    );
  }
}