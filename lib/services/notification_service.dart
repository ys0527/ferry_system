import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../models/notification_item.dart';
import 'current_user_service.dart';
import 'local_notification_service.dart';

class NotificationService {
  final _client = supabase;

  RealtimeChannel? _channel;

  Future<void> startListening() async {
    if (_channel != null) return;

    final userId = await currentUserId();
    // ignore: avoid_print
    print('Starting notification listener for user $userId');
    await LocalNotificationService.instance.init();

    _channel = _client
        .channel('notifications-$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        // ignore: avoid_print
        print('Realtime insert received: ${payload.newRecord}');
        final row = payload.newRecord;
        LocalNotificationService.instance.show(
          title: row['title'] as String? ?? 'Notification',
          body: row['description'] as String?,
        );
      },
    )
        .subscribe((status, error) {
      // ignore: avoid_print
      print('Realtime channel status: $status, error: $error');
    });
  }

  void stopListening() {
    final channel = _channel;
    if (channel != null) {
      _client.removeChannel(channel);
      _channel = null;
    }
  }

  Future<List<NotificationItem>> fetchNotifications() async {
    final userId = await currentUserId();
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => NotificationItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('notification_id', notificationId);
  }

  Future<void> _send({
    required String userId,
    required String type,
    required String title,
    required String body,
  }) async {
    await _client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'description': body,
    });
  }

  Future<void> notifyBookingConfirmed({
    required String userId,
    required String reference,
  }) {
    return _send(
      userId: userId,
      type: 'Booking',
      title: 'Booking Confirmed',
      body: 'Your booking (Ref: $reference) has been confirmed.',
    );
  }

  Future<void> notifyPointsEarned({
    required String userId,
    required int points,
  }) {
    return _send(
      userId: userId,
      type: 'Rewards',
      title: 'Reward Points Earned',
      body: 'You earned $points loyalty points from your recent booking.',
    );
  }

  Future<void> notifyWeatherAdvisoryIfNew({
    required String title,
    required String body,
  }) async {
    final userId = await currentUserId();
    final now = DateTime.now().toUtc();
    final startOfToday = DateTime.utc(now.year, now.month, now.day);

    final existing = await _client
        .from('notifications')
        .select('notification_id')
        .eq('user_id', userId)
        .eq('type', 'Weather')
        .eq('title', title)
        .gte('created_at', startOfToday.toIso8601String())
        .maybeSingle();

    if (existing != null) return;

    await _send(userId: userId, type: 'Weather', title: title, body: body);
  }
}