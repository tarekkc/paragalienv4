import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class OneSignalService {
  static const String oneSignalAppId = 'f80cbfd0-124d-4dca-bc2e-e4f021b8a872';
  static const String restApiKey = 'os_v2_app_7agl7uasjvg4vpbo4tycdofiolyvnekd33gudpvp4irp66n72dap23yuzsf32m3vvqzrv2p4wzlf2ehi2svlhv2dqzpanr2byezm33q'; // You need to add your actual REST API key here

  static Future<void> sendPushToAdmins({
    required List<String> playerIds,
    required String title,
    required String content,
    Map<String, dynamic>? data,
  }) async {
    if (playerIds.isEmpty) {
      debugPrint('No player IDs provided for notification');
      return;
    }

    final url = Uri.parse('https://onesignal.com/api/v1/notifications');

    final body = {
      'app_id': oneSignalAppId,
      'include_player_ids': playerIds,
      'headings': {'en': title, 'fr': title},
      'contents': {'en': content, 'fr': content},
      'android_channel_id': 'admin_notifications',
      'priority': 10,
      'ttl': 3600, // 1 hour
      if (data != null) 'data': data,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restApiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Notification sent successfully');
        final responseData = jsonDecode(response.body);
        debugPrint('OneSignal response: $responseData');
      } else {
        debugPrint('Failed to send notification: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('OneSignal Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      rethrow;
    }
  }

  static Future<void> sendOrderNotification({
    required String userId,
    required List<dynamic> orderItems,
    required double totalPrice,
    required int totalItems,
    String? clientNote,
  }) async {
    try {
      // Fetch admin player IDs from Supabase
      final response = await supabase.Supabase.instance.client
          .from('profiles')
          .select('player_id, name')
          .eq('role', 'admin')
          .not('player_id', 'is', null);

      final List<String> adminPlayerIds = (response as List)
          .map((row) => row['player_id'] as String)
          .where((id) => id.isNotEmpty)
          .toList();

      if (adminPlayerIds.isEmpty) {
        debugPrint('No admin player IDs found for notifications');
        return;
      }

      // Get user info for notification
      final userResponse = await supabase.Supabase.instance.client
          .from('profiles')
          .select('name, email')
          .eq('id', userId)
          .single();

      final userName = userResponse['name'] ?? userResponse['email'] ?? 'Client';

      // Create notification content
      final notificationTitle = 'Nouvelle commande reçue';
      final notificationBody = '$userName a passé une commande de $totalItems articles (${totalPrice.toStringAsFixed(2)} DA)';

      // Prepare notification data
      final notificationData = {
        'type': 'new_order',
        'user_id': userId,
        'user_name': userName,
        'total_price': totalPrice,
        'total_items': totalItems,
        'timestamp': DateTime.now().toIso8601String(),
        if (clientNote != null && clientNote.isNotEmpty) 'client_note': clientNote,
      };

      // Store notification in database
      await supabase.Supabase.instance.client
          .from('notifications')
          .insert({
            'title': notificationTitle,
            'body': notificationBody,
            'user_id': userId,
            'data': notificationData,
            'created_at': DateTime.now().toIso8601String(),
          });

      // Send push notification
      await sendPushToAdmins(
        playerIds: adminPlayerIds,
        title: notificationTitle,
        content: notificationBody,
        data: notificationData,
      );

      debugPrint('Order notification sent successfully to ${adminPlayerIds.length} admins');
    } catch (e) {
      debugPrint('Error sending order notification: $e');
      rethrow;
    }
  }
}

// Legacy function for backward compatibility
Future<void> sendPushToAdmins({
  required List<String> playerIds,
  required String title,
  required String content,
  Map<String, dynamic>? data,
}) async {
  return OneSignalService.sendPushToAdmins(
    playerIds: playerIds,
    title: title,
    content: content,
    data: data,
  );
}