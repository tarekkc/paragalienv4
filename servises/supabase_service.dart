import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/models/produit.dart';
import 'package:paragalien/models/commande.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch products
  Future<List<Produit>> fetchProduits() async {
    final res = await _supabase.from('produits').select();
    
    return res.map((p) => Produit.fromJson(p)).toList();
  }

  // Submit order
  Future<void> submitOrder(List<Produit> produits, String userId) async {
    final orderRes =
        await _supabase.from('commandes').insert({
          'user_id': userId,
          'status': 'en cours de validation',
        }).select();

    final orderId = orderRes.first['id'] as int;

    await _supabase
        .from('commande_items')
        .insert(
          produits
              .map((p) => {'commande_id': orderId, 'produit_id': p.id})
              .toList(),
        );
  }

  // Fetch user orders
  Future<List<Commande>> fetchUserOrders(String userId) async {
    final res = await _supabase
        .from('commandes')
        .select('*, commande_items(*, produits(*))')
        .eq('user_id', userId);
    return res.map((o) => Commande.fromJson(o)).toList();
  }
}
