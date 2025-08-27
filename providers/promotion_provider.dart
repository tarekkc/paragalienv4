import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/produit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/models/promotion.dart';

final promotionsProvider = FutureProvider<List<Promotion>>((ref) async {
  final client = Supabase.instance.client;

  // Fetch promotions with their associated product data
  final response = await client
      .from('promotions')
      .select('*, produits(*)')
      .eq('is_active', true)
      .order('start_date', ascending: false);

  return response.map<Promotion>((promoJson) {
    final product = Produit.fromJson(promoJson['produits']);
    return Promotion.fromJson(promoJson, product);
  }).toList();
});
