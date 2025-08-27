import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:pedantic/pedantic.dart';
import 'package:paragalien/models/app_user.dart';
import 'package:paragalien/models/profile.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  AppUser? get currentUser {
    final user = _supabase.auth.currentUser;
    return user != null ? AppUser.fromSupabaseUser(user) : null;
  }

  Future<AppUser> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed: User not found');
      }

      await getOrCreateProfile(response.user!.id, email);

      // Associate with OneSignal alias (fire-and-forget)
      unawaited(_handleOneSignalSetup(response.user!.id));

      return AppUser.fromSupabaseUser(response.user!);
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<Profile> getOrCreateProfile(String userId, String email) async {
    final existing =
        await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

    if (existing != null) {
      return Profile.fromJson(existing);
    }

    final newProfile = {
      'id': userId,
      'email': email,
      'role': 'client',
      'created_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('profiles').insert(newProfile);
    return Profile.fromJson(newProfile);
  }

  Future<void> _handleOneSignalSetup(String userId) async {
  try {
    // 1. Verify OneSignal is ready
    if (!OneSignal.Notifications.permission) {
      final status = await OneSignal.Notifications.requestPermission(true);
      if (!status) {
        debugPrint('User declined notification permissions');
        return;
      }
    }

    // 2. Add debug logs
    debugPrint('Starting OneSignal setup for user: $userId');

    // 3. Add user alias
    await OneSignal.User.addAlias('user_id', userId);
    debugPrint('Alias added for user: $userId');

    // 4. Small delay for OneSignal to stabilize
    await Future.delayed(const Duration(seconds: 1));

    // 5. Get device state
    final pushSubscription = OneSignal.User.pushSubscription;
    final playerId = pushSubscription.id;
    debugPrint('Retrieved PlayerID: $playerId');

    // 6. Store in Supabase if valid
    if (playerId != null && playerId.isNotEmpty) {
      try {
        final response = await _supabase
            .from('profiles')
            .update({
              'onesignal_alias': userId,
              'player_id': playerId,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);

        debugPrint('Supabase update response: $response');
      } catch (e) {
        debugPrint('Supabase update failed: $e');
      }
    } else {
      debugPrint('No PlayerID available');
    }
  } catch (e) {
    debugPrint('OneSignal setup error: $e');
  }
}

  Future<void> logout() async {
    try {
      await OneSignal.User.removeAlias('user_id');
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }

  Future<bool> userExists(String email) async {
    final result =
        await _supabase
            .from('profiles')
            .select()
            .eq('email', email.trim())
            .maybeSingle();
    return result != null;
  }
}
