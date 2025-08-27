import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

final userManagementProvider = Provider<UserManagement>(
  (ref) => UserManagement(),
);

class UserManagement {
  final _supabase = Supabase.instance.client;

  String _generateRandomPassword({int length = 12}) {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const special = '@#%^*+\$';

    final allChars = letters + numbers + special;
    final random = Random.secure();

    final passwordChars = [
      letters[random.nextInt(letters.length)],
      numbers[random.nextInt(numbers.length)],
      special[random.nextInt(special.length)],
    ];

    for (var i = 3; i < length; i++) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    passwordChars.shuffle(random);
    return passwordChars.join();
  }

  Future<List<AppUser>> getAllUsers() async {
    final response = await _supabase
        .from('profiles')
        .select('*')
        .order('created_at', ascending: false);

    return (response as List).map((user) => AppUser.fromJson(user)).toList();
  }

  Future<({String userId, String generatedPassword})> addUserWithGeneratedPassword({
    required String email,
    required String fullName,
    required String phone,
    required String role,
    required List<String> locations,
  }) async {
    final generatedPassword = _generateRandomPassword();

    try {
      // Sign up the user normally
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: generatedPassword,
        data: {
          'name': fullName,
          'role': role,
        },
      );

      final userId = authResponse.user?.id ??
          (throw Exception('User creation failed - no user ID returned'));

      // Create profile record
      await _supabase.from('profiles').upsert({
        'id': userId,
        'email': email,
        'name': fullName,
        'phone': phone,
        'role': role,
        'initial_password': generatedPassword,
        'locations': locations,
      });

      return (userId: userId, generatedPassword: generatedPassword);
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  Future<void> updateUser({
    required String userId,
    String? fullName,
    String? phone,
    String? role,
    List<String>? locations,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (role != null) updates['role'] = role;
    if (locations != null) updates['locations'] = locations;

    if (updates.isNotEmpty) {
      await _supabase.from('profiles').update(updates).eq('id', userId);
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // Delete profile first
      await _supabase.from('profiles').delete().eq('id', userId);

      // Then delete auth user (requires proper RLS policies)
      await _supabase.from('auth.users').delete().eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete user: ${e.toString()}');
    }
  }

  Future<String> resetUserPassword(String userId) async {
    final generatedPassword = _generateRandomPassword();

    // Update password in auth table (requires proper RLS policies)
    await _supabase
        .from('auth.users')
        .update({'encrypted_password': _hashPassword(generatedPassword)})
        .eq('id', userId);

    // Update initial password in profiles table
    await _supabase
        .from('profiles')
        .update({'initial_password': generatedPassword})
        .eq('id', userId);

    return generatedPassword;
  }

  String _hashPassword(String password) {
    // This is a simplified example - in production use proper hashing
    return password; // Replace with actual hashing logic
  }

  Future<String?> getUserInitialPassword(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('initial_password')
        .eq('id', userId)
        .single();

    return response['initial_password'] as String?;
  }

  Future<List<String>> getAvailableLocations() async {
    final response = await _supabase
        .from('locations')
        .select('name')
        .order('name', ascending: true);

    return (response as List).map((loc) => loc['name'] as String).toList();
  }
}