import 'package:paragalien/models/produit.dart';

class Promotion {
  final String id;
  final Produit product;
  final double originalPrice;
  final double promotionPrice;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  Promotion({
    required this.id,
    required this.product,
    required this.originalPrice,
    required this.promotionPrice,
    this.description,
    required this.startDate,
    this.endDate,
    required this.isActive,
  });

  factory Promotion.fromJson(Map<String, dynamic> json, Produit product) {
    return Promotion(
      id: json['id'].toString(),
      product: product,
      originalPrice: (json['original_price'] as num).toDouble(),
      promotionPrice: (json['promotion_price'] as num).toDouble(),
      description: json['description'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      isActive: json['is_active'],
    );
  }
}