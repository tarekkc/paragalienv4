
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AppUser {
  final String id;
  final String email;
  final String name;
  final String phone;
  final Map<String, dynamic>? metadata;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    this.metadata,
  });

  factory AppUser.fromSupabaseUser(supabase.User user) {
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['name'] ?? '',
      phone: user.userMetadata?['phone'] ?? '',
      metadata: user.userMetadata,
    );
  }
}