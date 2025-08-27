class Profile {
  final String id;
  final String email;
  final String? name;
  final String role; // 'admin' or 'client'
  final List<String> locations; // Add this field for location

  Profile({
    required this.id,
    required this.email,
    this.name,
    required this.role,
    required this.locations, // Add to constructor
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'],
      locations:
          json['locations'] is String
              ? [json['locations']] // Handle string case
              : List<String>.from(json['locations'] ?? []), // Handle array case
    );
  }

  bool get isAdmin => role == 'admin';
}
