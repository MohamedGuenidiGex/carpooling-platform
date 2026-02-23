/// User Model
///
/// Represents a user/employee with profile information,
/// vehicle details, and ride statistics.
class User {
  final int? id;
  final String email;
  final String? name;
  final String role;
  final String status;
  final String? phoneNumber;
  final String? carModel;
  final String? carPlate;
  final String? carColor;
  final int ridesOfferedCount;
  final int bookingsCount;
  final String? profilePictureUrl;
  final String? department;

  User({
    this.id,
    required this.email,
    this.name,
    this.role = 'employee',
    this.status = 'active',
    this.phoneNumber,
    this.carModel,
    this.carPlate,
    this.carColor,
    this.ridesOfferedCount = 0,
    this.bookingsCount = 0,
    this.profilePictureUrl,
    this.department,
  });

  /// Create User from JSON response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int?,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? json['full_name'] as String?,
      role: json['role'] as String? ?? 'employee',
      status: json['status'] as String? ?? 'active',
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String?,
      carModel: json['car_model'] as String?,
      carPlate: json['car_plate'] as String? ?? json['plate_number'] as String?,
      carColor: json['car_color'] as String?,
      ridesOfferedCount:
          json['rides_offered_count'] as int? ??
          json['rides_offered'] as int? ??
          0,
      bookingsCount:
          json['bookings_count'] as int? ?? json['bookings'] as int? ?? 0,
      profilePictureUrl:
          json['profile_picture'] as String? ?? json['avatar'] as String?,
      department: json['department'] as String?,
    );
  }

  /// Convert User to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'email': email,
      if (name != null) 'name': name,
      'role': role,
      'status': status,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (carModel != null) 'car_model': carModel,
      if (carPlate != null) 'car_plate': carPlate,
      if (carColor != null) 'car_color': carColor,
      if (profilePictureUrl != null) 'profile_picture': profilePictureUrl,
      if (department != null) 'department': department,
    };
  }

  /// Create a copy of User with updated fields
  User copyWith({
    int? id,
    String? email,
    String? name,
    String? role,
    String? status,
    String? phoneNumber,
    String? carModel,
    String? carPlate,
    String? carColor,
    int? ridesOfferedCount,
    int? bookingsCount,
    String? profilePictureUrl,
    String? department,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      carModel: carModel ?? this.carModel,
      carPlate: carPlate ?? this.carPlate,
      carColor: carColor ?? this.carColor,
      ridesOfferedCount: ridesOfferedCount ?? this.ridesOfferedCount,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      department: department ?? this.department,
    );
  }

  /// Get display name (name or email prefix)
  String get displayName => name ?? email.split('@').first;

  /// Check if user has vehicle info
  bool get hasVehicle => carModel != null && carModel!.isNotEmpty;

  /// Get formatted vehicle info
  String? get vehicleInfo {
    if (!hasVehicle) return null;
    final parts = <String>[carModel!];
    if (carPlate != null && carPlate!.isNotEmpty) parts.add(carPlate!);
    if (carColor != null && carColor!.isNotEmpty) parts.add(carColor!);
    return parts.join(' • ');
  }
}
