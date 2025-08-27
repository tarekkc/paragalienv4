import 'package:paragalien/models/commande_item.dart';
import 'profile.dart';

class Commande {
  final int id;
  final String userId;
  final List<CommandeItem> items;
  final DateTime createdAt;
  final bool isApproved;
  final String? clientNotes;
  final String? adminNotes;
  Profile? userProfile;

  Commande({
    required this.id,
    required this.userId,
    required this.items,
    required this.createdAt,
    this.clientNotes,
    this.adminNotes,
    this.isApproved = false,
    this.userProfile,
  });

  factory Commande.fromJson(Map<String, dynamic> json) {
    return Commande(
      id: (json['id'] as num).toInt(), // ✅ Safe conversion
      userId: json['user_id'],
      items: (json['commande_items'] as List)
          .map((item) => CommandeItem.fromJson(item))
          .toList(),
      clientNotes: json['client_notes'],
      adminNotes: json['admin_notes'],
      createdAt: DateTime.parse(json['created_at']),
      isApproved: json['is_approved'] ?? false,
      userProfile: json['user_profile'] != null
          ? Profile.fromJson(json['user_profile'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_notes': clientNotes,
      'admin_notes': adminNotes,
    };
  }

  Commande copyWith({
    int? id,
    String? userId,
    List<CommandeItem>? items,
    DateTime? createdAt,
    bool? isApproved,
    String? clientNotes,
    String? adminNotes,
    Profile? userProfile,
  }) {
    return Commande(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      clientNotes: clientNotes ?? this.clientNotes,
      adminNotes: adminNotes ?? this.adminNotes,
      isApproved: isApproved ?? this.isApproved,
      userProfile: userProfile ?? this.userProfile,
    );
  }
}
