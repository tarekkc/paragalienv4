import '../models/orderhistory.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final orderHistoryProvider = FutureProvider.autoDispose
    .family<List<OrderHistory>, String>((ref, userId) async {
  try {
    return await _fetchOrdersWithSeparateQueries(userId);
  } catch (e) {
    print('Error fetching orders: $e');
    rethrow;
  }
});



Future<List<OrderHistory>> _fetchOrdersWithSeparateQueries(String userId) async {
  // 1. Fetch basic order data
  final ordersResponse = await Supabase.instance.client
      .from('commandes')
      .select('id, created_at, is_approved, total, user_id, approved_by')
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  // 2. Fetch related data for each order in parallel
  final ordersWithDetails = await Future.wait(
    (ordersResponse as List).map((order) async {
      try {
        // Get user details (customer who placed order)
        final userResponse = await Supabase.instance.client
            .from('profiles')
            .select('name, email')
            .eq('id', order['user_id'])
            .single();

        // Get approver details (admin who approved)
        Map<String, dynamic>? approverResponse;
        if (order['is_approved'] == true && order['approved_by'] != null) {
          approverResponse = await Supabase.instance.client
              .from('profiles')
              .select('name')
              .eq('id', order['approved_by'])
              .maybeSingle();
        }

        // Get order items with product details
        final itemsResponse = await Supabase.instance.client
            .from('commande_items')
            .select('''
              id, 
              quantity, 
              produit:produits(name, price)
            ''')
            .eq('commande_id', order['id']);

        return OrderHistory.fromJson({
          ...order,
          'user': userResponse,
          'approver': approverResponse,
          'items': itemsResponse,
        });
      } catch (e) {
        print('Error processing order ${order['id']}: $e');
        return OrderHistory(
          id: order['id']?.toString() ?? '',
          date: DateTime.now(),
          isApproved: false,
          total: 0.0,
          userId: order['user_id']?.toString() ?? '',
          items: [],
        );
      }
    }),
  );

  return ordersWithDetails.where((order) => order.id.isNotEmpty).toList();
}

final orderModificationProvider = StateNotifierProvider.autoDispose
    .family<OrderModificationNotifier, OrderHistory, OrderParams>((ref, params) {
  return OrderModificationNotifier(
    ref: ref,
    orderId: params.orderId,
    userId: params.userId,
  );
});

class OrderParams {
  final String orderId;
  final String userId;

  OrderParams({required this.orderId, required this.userId});
}

class OrderModificationNotifier extends StateNotifier<OrderHistory> {
  final String orderId;
  final String userId;
  final Ref ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isDisposed = false;

  OrderModificationNotifier({
    required this.ref,
    required this.orderId,
    required this.userId,
  }) : super(OrderHistory.empty()) {
    _loadOrder();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadOrder() async {
    if (_isDisposed) return;

    try {
      // 1. Fetch order basics
      final orderResponse = await _supabase
          .from('commandes')
          .select('id, created_at, is_approved, total, user_id, approved_by')
          .eq('id', orderId)
          .single();

      // 2. Fetch user details
      final userResponse = await _supabase
          .from('profiles')
          .select('name, email')
          .eq('id', orderResponse['user_id'])
          .single();

      // 3. Fetch approver details if approved
      Map<String, dynamic>? approverResponse;
      if (orderResponse['is_approved'] == true && 
          orderResponse['approved_by'] != null) {
        approverResponse = await _supabase
            .from('profiles')
            .select('name')
            .eq('id', orderResponse['approved_by'])
            .maybeSingle();
      }

      // 4. Fetch items
      final itemsResponse = await _supabase
          .from('commande_items')
          .select('''
            id, 
            quantity, 
            produit:produits(name, price)
          ''')
          .eq('commande_id', orderId);

      if (_isDisposed) return;

      state = OrderHistory.fromJson({
        ...orderResponse,
        'user': userResponse,
        'approver': approverResponse,
        'items': itemsResponse,
      });
    } catch (e) {
      print('Error loading order: $e');
      if (!_isDisposed) {
        state = OrderHistory(
          id: orderId,
          date: DateTime.now(),
          isApproved: false,
          total: 0.0,
          userId: userId,
          items: [],
        );
      }
    }
  }

  Future<void> approveOrder() async {
    if (_isDisposed || state.isApproved) return;

    try {
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

      await _loadOrder();
      ref.invalidate(orderHistoryProvider(userId));
    } catch (e) {
      print('Error approving order: $e');
      rethrow;
    }
  }

  Future<void> updateItemQuantity(String itemId, double newQuantity) async {
    if (_isDisposed || state.isApproved) return;

    try {
      if (newQuantity <= 0) {
        await removeItem(itemId);
        return;
      }

      await _supabase
          .from('commande_items')
          .update({'quantity': newQuantity})
          .eq('id', itemId);

      await _loadOrder();
      ref.invalidate(orderHistoryProvider(userId));
    } catch (e) {
      print('Error updating quantity: $e');
      rethrow;
    }
  }

  Future<void> removeItem(String itemId) async {
    if (_isDisposed || state.isApproved) return;

    try {
      await _supabase
          .from('commande_items')
          .delete()
          .eq('id', itemId);

      await _loadOrder();
      ref.invalidate(orderHistoryProvider(userId));
    } catch (e) {
      print('Error removing item: $e');
      rethrow;
    }
  }

  Future<void> recalculateOrderTotal() async {
    if (_isDisposed || state.isApproved) return;

    try {
      final newTotal = state.items.fold(
        0.0,
        (sum, item) => sum + (item.price * item.quantity),
      );

      await _supabase
          .from('commandes')
          .update({'total': newTotal})
          .eq('id', orderId);

      await _loadOrder();
    } catch (e) {
      print('Error recalculating total: $e');
      rethrow;
    }
  }
}