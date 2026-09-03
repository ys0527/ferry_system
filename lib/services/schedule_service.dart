import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../models/ferry.dart';
import '../models/schedule.dart';

class ScheduleService {
  final _client = Supabase.instance.client;

  Future<Ferry> fetchFerry(String ferryId) async {
    final row = await _client
        .from('ferry')
        .select()
        .eq('ferry_id', ferryId)
        .single();
    return Ferry.fromMap(row);
  }

  Future<ScheduleSlot> findOrCreateSchedule({
    required String departure,
    required String destination,
    required DateTime date,
    required String time,
    required String ferryId,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final existing = await _client
        .from('schedule')
        .select()
        .eq('departure', departure)
        .eq('destination', destination)
        .eq('date', dateStr)
        .eq('time', time)
        .eq('ferry_id', ferryId)
        .maybeSingle();

    if (existing != null) {
      return ScheduleSlot.fromMap(existing);
    }

    final created = await _client
        .from('schedule')
        .insert({
          'departure': departure,
          'destination': destination,
          'date': dateStr,
          'time': time,
          'delay_time': 0,
          'ferry_id': ferryId,
        })
        .select()
        .single();

    return ScheduleSlot.fromMap(created);
  }

  Future<Map<String, int>> fetchBookedCounts(String scheduleId) async {
    final rows = await _client
        .from('ticket')
        .select('type, quantity, booking!inner(schedule_id, status)')
        .eq('booking.schedule_id', scheduleId)
        .neq('booking.status', 'Cancelled');

    final counts = <String, int>{};
    for (final row in rows) {
      final type = row['type'] as String;
      final key = ticketTypeKeys[type] ?? type;
      final quantity = (row['quantity'] as num).toInt();
      counts[key] = (counts[key] ?? 0) + quantity;
    }
    return counts;
  }
}
