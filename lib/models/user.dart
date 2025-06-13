class User {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? address;
  final double? latitude;
  final double? longitude;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.address,
    this.latitude,
    this.longitude,
  });

  // Create a User from JSON data
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone'] ?? '',
      address: json['address'],
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
    );
  }

  // Convert User to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phoneNumber,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create an empty user
  factory User.empty() {
    return User(
      id: '',
      name: '',
      email: '',
      phoneNumber: '',
    );
  }

  // Create a copy of this user with updated fields
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}