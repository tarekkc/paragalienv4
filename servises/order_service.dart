import 'package:supabase_flutter/supabase_flutter.dart';

class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> approveOrder(String orderId) async {
    final adminId = _supabase.auth.currentUser?.id;
    if (adminId == null) throw Exception('Admin not authenticated');

    await _supabase
      .from('commandes')
      .update({
        'is_approved': true,
        'approved_by': adminId,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', orderId);
  }

  // Add other order-related methods here
  Future<void> rejectOrder(String orderId) async {
    /* ... */
  }
}