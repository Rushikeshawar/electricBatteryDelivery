class ChargingProvider {
  final int id;
  final String businessName;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final double rating;
  final int totalSlots;
  final int availableSlots;
  final double ratePerHour;
  final bool fastCharging;
  final bool isOpen;
  final String description;
  final List<String> images;
  final List<String> amenities;
  final List<Review> reviews;
  final String phoneNumber;
  final Map<String, String> operatingHours;

  ChargingProvider({
    required this.id,
    required this.businessName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.rating,
    required this.totalSlots,
    required this.availableSlots,
    required this.ratePerHour,
    required this.fastCharging,
    required this.isOpen,
    required this.description,
    required this.images,
    required this.amenities,
    required this.reviews,
    required this.phoneNumber,
    required this.operatingHours,
  });

  factory ChargingProvider.fromJson(Map<String, dynamic> json) {
    return ChargingProvider(
      id: json['id'] ?? 0,
      businessName: json['businessName'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      distance: (json['distance'] ?? 0.0).toDouble(),
      rating: (json['rating'] ?? 0.0).toDouble(),
      totalSlots: json['totalSlots'] ?? 0,
      availableSlots: json['availableSlots'] ?? 0,
      ratePerHour: (json['ratePerHour'] ?? 0.0).toDouble(),
      fastCharging: json['fastCharging'] ?? false,
      isOpen: json['isOpen'] ?? false,
      description: json['description'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      amenities: List<String>.from(json['amenities'] ?? []),
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((review) => Review.fromJson(review))
          .toList() ?? [],
      phoneNumber: json['phoneNumber'] ?? '',
      operatingHours: Map<String, String>.from(json['operatingHours'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessName': businessName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'rating': rating,
      'totalSlots': totalSlots,
      'availableSlots': availableSlots,
      'ratePerHour': ratePerHour,
      'fastCharging': fastCharging,
      'isOpen': isOpen,
      'description': description,
      'images': images,
      'amenities': amenities,
      'reviews': reviews.map((review) => review.toJson()).toList(),
      'phoneNumber': phoneNumber,
      'operatingHours': operatingHours,
    };
  }
}

class Review {
  final int id;
  final String userName;
  final int rating;
  final String comment;
  final String createdAt;
  final List<String> tags;

  Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.tags,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? 0,
      userName: json['userName'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
      'tags': tags,
    };
  }
}

class TimeSlot {
  final int id;
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final double price;
  final String chargerType;

  TimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    required this.price,
    required this.chargerType,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: json['id'] ?? 0,
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      isAvailable: json['isAvailable'] ?? false,
      price: (json['price'] ?? 0.0).toDouble(),
      chargerType: json['chargerType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
      'price': price,
      'chargerType': chargerType,
    };
  }
}

class ProvidersResponse {
  final List<ChargingProvider> data;
  final PaginationInfo pagination;

  ProvidersResponse({
    required this.data,
    required this.pagination,
  });

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) {
    return ProvidersResponse(
      data: (json['data'] as List<dynamic>?)
          ?.map((provider) => ChargingProvider.fromJson(provider))
          .toList() ?? [],
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }
}

class ProviderResponse {
  final ChargingProvider data;

  ProviderResponse({required this.data});

  factory ProviderResponse.fromJson(Map<String, dynamic> json) {
    return ProviderResponse(
      data: ChargingProvider.fromJson(json['data'] ?? {}),
    );
  }
}

class PaginationInfo {
  final int page;
  final int pages;
  final int perPage;
  final int total;

  PaginationInfo({
    required this.page,
    required this.pages,
    required this.perPage,
    required this.total,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      page: json['page'] ?? 1,
      pages: json['pages'] ?? 1,
      perPage: json['perPage'] ?? 10,
      total: json['total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'pages': pages,
      'perPage': perPage,
      'total': total,
    };
  }
}