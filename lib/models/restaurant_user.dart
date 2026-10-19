import 'package:supabase_flutter/supabase_flutter.dart';

/// Strongly-typed User Model for Bocardo Restaurant
class RestaurantUser {
  const RestaurantUser({
    required this.id,
    required this.email,
    required this.restaurantName,
    required this.ownerName,
    required this.phone,
    this.role = 'restaurant_owner',
    this.isEmailVerified = false,
    this.createdAt,
    this.rawMetadata = const {},
  });

  final String id;
  final String email;
  final String restaurantName;
  final String ownerName;
  final String phone;
  final String role;
  final bool isEmailVerified;
  final DateTime? createdAt;
  final Map<String, dynamic> rawMetadata;

  /// Factory constructor to map from Supabase [User] instance
  factory RestaurantUser.fromSupabaseUser(User user) {
    final meta = user.userMetadata ?? {};
    final restaurantName = meta['restaurant_name']?.toString() ??
        meta['restaurantName']?.toString() ??
        'Bocardo Restaurant';
    final ownerName = meta['owner_name']?.toString() ??
        meta['ownerName']?.toString() ??
        meta['full_name']?.toString() ??
        'Owner';
    final phone = meta['phone']?.toString() ??
        meta['phone_number']?.toString() ??
        user.phone ??
        '';

    DateTime? created;
    if (user.createdAt.isNotEmpty) {
      created = DateTime.tryParse(user.createdAt);
    }

    return RestaurantUser(
      id: user.id,
      email: user.email ?? '',
      restaurantName: restaurantName,
      ownerName: ownerName,
      phone: phone,
      role: user.role ?? 'authenticated',
      isEmailVerified: user.emailConfirmedAt != null,
      createdAt: created,
      rawMetadata: meta,
    );
  }

  RestaurantUser copyWith({
    String? restaurantName,
    String? ownerName,
    String? phone,
    String? role,
    bool? isEmailVerified,
  }) {
    return RestaurantUser(
      id: id,
      email: email,
      restaurantName: restaurantName ?? this.restaurantName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      rawMetadata: rawMetadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'restaurant_name': restaurantName,
      'owner_name': ownerName,
      'phone': phone,
      'role': role,
      'is_email_verified': isEmailVerified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'RestaurantUser(id: $id, email: $email, restaurant: $restaurantName)';
}
