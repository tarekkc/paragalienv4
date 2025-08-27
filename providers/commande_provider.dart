import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paragalien/models/commande.dart';
import 'package:paragalien/providers/produit_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paragalien/core/constants.dart';
import 'package:paragalien/models/profile.dart';
import 'package:flutter/foundation.dart';

// Helper function to ensure integer conversion
int _ensureInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  throw ArgumentError('Cannot convert $value to int');
}

// 1. Orders Provider (User-specific)
final userCommandesProvider = FutureProvider.autoDispose
    .family<List<Commande>, String>((ref, userId) async {
      final res = await Supabase.instance.client
          .from(SupabaseConstants.ordersTable)
          .select('*, commande_items(*, produits(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (res as List).map((o) => Commande.fromJson(o)).toList();
    });

// 2. All Orders Provider (Admin)
final allCommandesProvider = FutureProvider.autoDispose<List<Commande>>((
  ref,
) async {
  final res = await Supabase.instance.client
      .from(SupabaseConstants.ordersTable)
      .select('''
        *, 
        commande_items(*, produits(*)),
        profiles:profiles(*)
      ''')
      .order('created_at', ascending: false);

  return (res as List).map((o) {
    final commande = Commande.fromJson(o);
    if (o['profiles'] != null) {
      commande.userProfile = Profile.fromJson(o['profiles']);
    }
    return commande;
  }).toList();
});

// 3. Order Notifier Provider
final commandeNotifierProvider = Provider<CommandeNotifier>(
  (ref) => CommandeNotifier(),
);

class CommandeNotifier {
  final client = Supabase.instance.client;

  Future<void> submitOrder(
    List<SelectedProduct> products,
    String userId,
  ) async {
    final orderRes =
        await client
            .from('commandes')
            .insert({'user_id': userId, 'is_approved': false})
            .select()
            .single();

    final orderId = _ensureInt(orderRes['id']); // Ensure integer

    await client
        .from('commande_items')
        .insert(
          products
              .map(
                (p) => {
                  'commande_id': orderId,
                  'produit_id': p.produit.id,
                  'quantity': p.quantity,
                  'price_at_order': p.produit.price,
                },
              )
              .toList(),
        );
  }

  Future<void> submitOrderWithNotes(
    List<SelectedProduct> products,
    String userId,
    String? note,
  ) async {
    final orderRes =
        await client
            .from('commandes')
            .insert({
              'user_id': userId,
              'is_approved': false,
              'client_notes': note?.isNotEmpty == true ? note : null,
            })
            .select()
            .single();

    final orderId = _ensureInt(orderRes['id']); // Ensure integer

    await client
        .from('commande_items')
        .insert(
          products
              .map(
                (p) => {
                  'commande_id': orderId,
                  'produit_id': p.produit.id,
                  'quantity': p.quantity,
                  'price_at_order': p.produit.price,
                },
              )
              .toList(),
        );
  }

  Future<void> approveOrder(int orderId) async {
    try {
      // Get full order details
      final order = await getOrderById(orderId);

      // Update product quantities
      for (final item in order.items) {
        // Get current stock first
        final product =
            await client
                .from('produits')
                .select('stock_unite')
                .eq('id', item.produit.id)
                .single();

        final currentStock =
            (product['stock_unite'] as num).toInt(); // Convert to int
        final newStock =
            currentStock - item.quantity.toInt(); // Ensure integer subtraction

        debugPrint(
          'Updating stock for product ${item.produit.id} '
          'from $currentStock to $newStock',
        );

        await client
            .from('produits')
            .update({
              'stock_unite': newStock, // Now sending integer
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', item.produit.id);
      }

      // Mark order as approved
      await client
          .from('commandes')
          .update({
            'is_approved': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);
    } catch (e) {
      debugPrint('Error in approveOrder: $e');
      rethrow;
    }
  }

  Future<Commande> getOrderById(int orderId) async {
    final safeOrderId = _ensureInt(orderId);
    final res =
        await client
            .from('commandes')
            .select('*, commande_items(*, produits(*))')
            .eq('id', safeOrderId)
            .single();
    return Commande.fromJson(res);
  }

  Future<void> deleteOrdersOlderThan(DateTime cutoffDate) async {
    await client
        .from('commandes')
        .delete()
        .lt('created_at', cutoffDate.toIso8601String());
  }
  
  


}
