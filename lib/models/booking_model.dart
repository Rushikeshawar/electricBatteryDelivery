class Booking {
  final int id;
  final int providerId;
  final String providerName;
  final String providerAddress;
  final int slotId;
  final DateTime bookingDate;
  final String startTime;
  final String endTime;
  final String vehicleType;
  final String vehicleNumber;
  final String specialNotes;
  final String status;
  final double totalAmount;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasReview;

  Booking({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerAddress,
    required this.slotId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.specialNotes,
    required this.status,
    required this.totalAmount,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.hasReview,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? 0,
      providerId: json['providerId'] ?? 0,
      providerName: json['providerName'] ?? '',
      providerAddress: json['providerAddress'] ?? '',
      slotId: json['slotId'] ?? 0,
      bookingDate: DateTime.parse(json['bookingDate'] ?? DateTime.now().toIso8601String()),
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      specialNotes: json['specialNotes'] ?? '',
      status: json['status'] ?? '',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      hasReview: json['hasReview'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'providerId': providerId,
      'providerName': providerName,
      'providerAddress': providerAddress,
      'slotId': slotId,
      'bookingDate': bookingDate.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'specialNotes': specialNotes,
      'status': status,
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasReview': hasReview,
    };
  }

  Booking copyWith({
    int? id,
    int? providerId,
    String? providerName,
    String? providerAddress,
    int? slotId,
    DateTime? bookingDate,
    String? startTime,
    String? endTime,
    String? vehicleType,
    String? vehicleNumber,
    String? specialNotes,
    String? status,
    double? totalAmount,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? hasReview,
  }) {
    return Booking(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      providerAddress: providerAddress ?? this.providerAddress,
      slotId: slotId ?? this.slotId,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      specialNotes: specialNotes ?? this.specialNotes,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasReview: hasReview ?? this.hasReview,
    );
  }
}

class BookingRequest {
  final int providerId;
  final int slotId;
  final DateTime bookingDate;
  final String vehicleType;
  final String vehicleNumber;
  final String specialNotes;

  BookingRequest({
    required this.providerId,
    required this.slotId,
    required this.bookingDate,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.specialNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'slotId': slotId,
      'bookingDate': bookingDate.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber.isNotEmpty ? vehicleNumber : null,
      'specialNotes': specialNotes.isNotEmpty ? specialNotes : null,
    };
  }
}

class BookingResponse {
  final Booking data;

  BookingResponse({required this.data});

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      data: Booking.fromJson(json['data'] ?? {}),
    );
  }
}

class BookingsResponse {
  final List<Booking> data;
  final BasicPagination pagination;

  BookingsResponse({
    required this.data,
    required this.pagination,
  });

  factory BookingsResponse.fromJson(Map<String, dynamic> json) {
    return BookingsResponse(
      data: (json['data'] as List<dynamic>?)
          ?.map((booking) => Booking.fromJson(booking))
          .toList() ?? [],
      pagination: BasicPagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class BasicPagination {
  final int page;
  final int pages;
  final int perPage;
  final int total;

  BasicPagination({
    required this.page,
    required this.pages,
    required this.perPage,
    required this.total,
  });

  factory BasicPagination.fromJson(Map<String, dynamic> json) {
    return BasicPagination(
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