import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/produit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SelectedProduct {
  final Produit produit;
  final double quantity;

  SelectedProduct(this.produit, this.quantity);

  Map<String, dynamic> toMap() {
    return {'produit': produit.toMap(), 'quantity': quantity};
  }

  SelectedProduct copyWith({Produit? produit, double? quantity}) {
    return SelectedProduct(produit ?? this.produit, quantity ?? this.quantity);
  }

  // Add toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'produit': produit.toMap(),
      'quantity': quantity,
    };
  }

  // Add fromJson factory constructor for deserialization
  factory SelectedProduct.fromJson(Map<String, dynamic> json) {
    return SelectedProduct(
      Produit.fromJson(json['produit']),
      (json['quantity'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedProduct &&
          produit == other.produit &&
          quantity == other.quantity;

  @override
  int get hashCode => produit.hashCode ^ quantity.hashCode;
}

final produitsProvider = FutureProvider.autoDispose<List<Produit>>((ref) async {
  final res = await Supabase.instance.client
      .from(SupabaseConstants.productsTable)
      .select();

  final allProducts = (res as List).map((p) => Produit.fromJson(p)).toList();

  // Filter only valid products
  final uniqueProducts = <Produit>[];
  final seenNames = <String>{};

  for (final product in allProducts) {
    if (!seenNames.contains(product.name) && product.price > 0) {
      seenNames.add(product.name);
      uniqueProducts.add(product);
    }
  }

  // 🔥 Sort logic: new arrivals first (descending), then alphabetically
  uniqueProducts.sort((a, b) {
    final aHasArrival = a.lastArrival != null;
    final bHasArrival = b.lastArrival != null;

    if (aHasArrival && bHasArrival) {
      // Both have arrivals → sort by arrival date descending
      return b.lastArrival!.compareTo(a.lastArrival!);
    } else if (aHasArrival) {
      return -1; // a comes before b
    } else if (bHasArrival) {
      return 1; // b comes before a
    } else {
      // Neither has arrival → sort alphabetically
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  });

  return uniqueProducts;
});


final selectedProduitsProvider =
    StateNotifierProvider<SelectedProduitsNotifier, List<SelectedProduct>>(
      (ref) {
        final notifier = SelectedProduitsNotifier();
        // Load cart data when provider is created
        Future.microtask(() => notifier.loadCart());
        return notifier;
      },
    );

class SelectedProduitsNotifier extends StateNotifier<List<SelectedProduct>> {
  SelectedProduitsNotifier() : super([]);

  static const String _cartKey = 'selected_products_cart';

  // Load cart from SharedPreferences on initialization
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_cartKey);
      
      if (cartJson != null) {
        final List<dynamic> cartList = jsonDecode(cartJson);
        final List<SelectedProduct> loadedCart = cartList
            .map((item) => SelectedProduct.fromJson(item))
            .toList();
        state = loadedCart;
      }
    } catch (e) {
      print('Error loading cart: $e');
      // If there's an error, start with empty cart
      state = [];
    }
  }

  // Save cart to SharedPreferences
  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(state.map((item) => item.toJson()).toList());
      await prefs.setString(_cartKey, cartJson);
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  void updateProduct(SelectedProduct updatedProduct) {
    state = [
      for (final product in state)
        if (product.produit.id == updatedProduct.produit.id)
          updatedProduct
        else
          product,
    ];
    _saveCart();
  }

  void add(Produit produit, double quantity) {
    final existingIndex = state.indexWhere((sp) => sp.produit.id == produit.id);

    if (existingIndex >= 0) {
      state = [
        ...state.sublist(0, existingIndex),
        state[existingIndex].copyWith(
          quantity: state[existingIndex].quantity + quantity,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, SelectedProduct(produit, quantity)];
    }
    _saveCart();
  }

  void remove(Produit produit) {
    state = state.where((sp) => sp.produit.id != produit.id).toList();
    _saveCart();
  }

  void clear() {
    state = [];
    _saveCart();
  }

  double getTotalPrice() {
    return state.fold(0.0, (sum, sp) => sum + (sp.produit.price * sp.quantity));
  }

  bool containsProduct(Produit produit) {
    return state.any((sp) => sp.produit.id == produit.id);
  }
}
