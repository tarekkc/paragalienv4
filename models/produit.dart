class Produit {
  final int id;
  final String name;
  final double price;
  final double ppa;
  final String description;
  final String? imageUrl;
  final double quantity;
  final DateTime? dateexp;
  final String? category;
  bool isInPromotion;
  final int packSize; 
  DateTime? lastArrival;

  Produit({
    required this.id,
    required this.ppa,
    required this.name,
    required this.price,
    required this.quantity,
    required this.description,
    required this.isInPromotion,
    this.category,
    this.dateexp,
    this.imageUrl,
    this.packSize = 1,
    this.lastArrival,
  });

  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      id: _parseInt(json['id']),
      name: _parseString(json['name']),
      price: _parseDouble(json['price']),
      ppa: _parseDouble(json['ppa']),
      description: _parseString(json['description']),
      imageUrl: _parseStringNullable(json['image_url']),
      quantity: _parseDouble(json['stock_unite'] ),
      dateexp: _parseDateTimeNullable(json['date_exp']),
      category: json['category'],
      isInPromotion: json['is_in_promotion'] ?? false,
      packSize: _parseInt(json['Colissage'] ?? 1),
      lastArrival: json['last_arrival'] != null
          ? DateTime.tryParse(json['last_arrival'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock_unite': quantity,
      'description': description,
      'image_url': imageUrl,
      'date_exp': dateexp?.toIso8601String(),
      'last_arrival': lastArrival?.toIso8601String(),
    };
  }

  // Helper methods for safe parsing
  static int _parseInt(dynamic value) {
    if (value == null) throw ArgumentError('ID cannot be null');
    return value is int ? value : int.tryParse(value.toString()) ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    return value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _parseStringNullable(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }

    final String dateString = value.toString();

    try {
      if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          // Try day-first format (dd/MM/yyyy)
          try {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          } catch (e) {
            // Try month-first format (MM/dd/yyyy)
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          }
        }
      }
      // Try standard ISO format
      return DateTime.parse(dateString);
    } catch (e) {
      print('Failed to parse date: $dateString. Error: $e');
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Produit && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Produit{id: $id, name: $name, price: $price, description: $description, imageUrl: $imageUrl, quantity: $quantity, dateexp: $dateexp}';
  }
}
