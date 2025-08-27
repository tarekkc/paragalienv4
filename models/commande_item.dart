import 'package:paragalien/models/produit.dart';

class CommandeItem {
  final int id;
  final Produit produit;
  int quantity;

  CommandeItem({
    required this.id,
    required this.produit,
     required this.quantity, 
  });

  factory CommandeItem.fromJson(Map<String, dynamic> json) {
    return CommandeItem(
      id: json['id'],
      produit: Produit.fromJson(json['produits'] ?? {}),
       quantity: (json['quantity'] as num).toInt(), // Ensure double conversion
    );
  }

  // Add copyWith method for immutable updates
  CommandeItem copyWith({
    int? id,
    Produit? produit,
    int? quantity,
  }) {
    return CommandeItem(
      id: id ?? this.id,
      produit: produit ?? this.produit,
      quantity: quantity ?? this.quantity,
    );
  }

  // Add toJson for API communications
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'produit_id': produit.id,
      'quantity': quantity,
     
    };
  }

  // Helper method to calculate item total
  double get itemTotal => produit.price * quantity;

  // Method to validate quantity against available stock
  bool hasSufficientStock() {
    return quantity <= produit.quantity;
  }

  // Method to increment/decrement quantity
  CommandeItem updateQuantity(int change) {
    final newQuantity = quantity + change;
    return copyWith(
      quantity: newQuantity > 0 ? newQuantity : 1, // Never go below 1
    );
  }

  @override
  String toString() {
    return 'CommandeItem(id: $id, product: ${produit.name}, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommandeItem &&
        other.id == id &&
        other.produit == produit &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => id.hashCode ^ produit.hashCode ^ quantity.hashCode;
}