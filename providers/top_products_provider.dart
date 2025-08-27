import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class TopProduct {
  final int id;
  final int rank; // 1, 2, 3, etc.
  final String productId;
  final String productName;
  final Color color;

  TopProduct({
    required this.id,
    required this.rank,
    required this.productId,
    required this.productName,
    required this.color,
  });

  // Helper to get color based on rank
  static Color getColorByRank(int rank) {
    const colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    return colors[(rank - 1) % colors.length];
  }
}

class TopProductsNotifier extends StateNotifier<List<TopProduct>> {
  final SupabaseClient _supabase;

  TopProductsNotifier(this._supabase) : super([]) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    final response = await _supabase
        .from('top_products')
        .select()
        .order('rank', ascending: true);

    state = response.map((product) => TopProduct(
      id: product['id'],
      rank: product['rank'],
      productId: product['product_id'],
      productName: product['product_name'],
      color: TopProduct.getColorByRank(product['rank']),
    )).toList();
  }

  Future<void> saveProduct(int rank, String productId, String productName) async {
    // Upsert - update if rank exists, otherwise insert
    await _supabase.from('top_products').upsert({
      'rank': rank,
      'product_id': productId,
      'product_name': productName,
    }, onConflict: 'rank');

    await loadProducts(); // Refresh the list
  }

  Future<void> removeProduct(int rank) async {
    await _supabase
        .from('top_products')
        .delete()
        .eq('rank', rank);

    await loadProducts(); // Refresh the list
  }
}

final topProductsProvider = StateNotifierProvider<TopProductsNotifier, List<TopProduct>>((ref) {
  final supabase = Supabase.instance.client;
  return TopProductsNotifier(supabase);
});