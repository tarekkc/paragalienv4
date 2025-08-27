import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter/foundation.dart';

class AppUser {
  final String id;
  final String email;
  final String role;
  final String? name;
  final String? phone;
  final List<String> locations;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    List<String>? locations,
  }) : locations = locations ?? const [];

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'user', // Default role
      locations: _parseLocations(json['locations']),
    );
  }

  static List<String> _parseLocations(dynamic locationsData) {
    if (locationsData == null) return [];
    if (locationsData is List) {
      return locationsData.map((e) => e?.toString()).whereType<String>().toList();
    }
    if (locationsData is String) {
      return locationsData.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  factory AppUser.fromAuthUser(supabase.User user) {
    final metadata = user.userMetadata ?? {};
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      role: metadata['role']?.toString() ?? 'user',
      name: metadata['name']?.toString(),
      phone: metadata['phone']?.toString(),
      locations: _parseLocations(metadata['locations']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'phone': phone,
    'role': role,
    'locations': locations,
  };

  bool get isAdmin => role.toLowerCase() == 'admin';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          role == other.role &&
          name == other.name &&
          phone == other.phone &&
          listEquals(locations, other.locations);

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      role.hashCode ^
      name.hashCode ^
      phone.hashCode ^
      Object.hashAll(locations);

  AppUser copyWith({
    String? id,
    String? email,
    String? role,
    String? name,
    String? phone,
    List<String>? locations,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        role: role ?? this.role,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        locations: locations ?? this.locations,
      );

  @override
  String toString() =>
      'AppUser(id: $id, email: $email, role: $role, name: $name, '
      'phone: $phone, locations: $locations)';
}