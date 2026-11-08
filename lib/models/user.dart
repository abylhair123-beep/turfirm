class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.isActive = true,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role; // 'client', 'agency', 'admin'
  final bool isActive;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  bool get isAgency => role == 'agency';
  bool get isAdmin => role == 'admin';
  bool get isClient => role == 'client';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['user_id'] as String? ?? json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'client',
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      isEmailVerified: json['is_email_verified'] as bool? ?? json['isEmailVerified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? json['isPhoneVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? role,
    bool? isActive,
    bool? isEmailVerified,
    bool? isPhoneVerified,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
    );
  }
}
