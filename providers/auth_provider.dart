import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user_model.dart';

// 1. Auth State Provider (Stream)
final authStateProvider = StreamProvider.autoDispose<supabase.Session?>((ref) {
  return supabase.Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session);
});

// 2. User Role Provider (Future)
final userRoleProvider = FutureProvider.autoDispose.family<String, String>((ref, userId) async {
  final res = await supabase.Supabase.instance.client
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .single();
  return res['role'] as String;
});

// 3. Auth Notifier (For login/logout)
final authProvider = Provider<AuthNotifier>((ref) => AuthNotifier());

class AuthNotifier {
  Future<void> login(String email, String password) async {
    await supabase.Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await supabase.Supabase.instance.client.auth.signOut();
  }
}

// Current User Provider
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final session = ref.watch(authStateProvider).value;
  if (session == null) return null;

  final response = await supabase.Supabase.instance.client
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .single();

  return AppUser.fromJson(response);
});

// Admin Check Provider
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  return user?.isAdmin ?? false;
});

// All Users Provider (for admin management)
final allUsersProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) throw Exception('Unauthorized');

  final response = await supabase.Supabase.instance.client
      .from('profiles')
      .select('*');
      
  return (response as List).map((user) => AppUser.fromJson(user)).toList();
});