import '../constants.dart';
import '../models/ferry.dart';
import '../models/schedule.dart';
import '../supabase_config.dart';

class ScheduleService {
  final _client = supabase;

  Future<Ferry> fetchFerry(String ferryId) async {
    final row = await _client
        .from('ferry')
        .select()
        .eq('ferry_id', ferryId)
        .single();
    return Ferry.fromMap(row);
  }

  Future<List<ScheduleSlot>> fetchSchedules({
    required String departure,
    required String destination,
    required DateTime date,
    required String ferryId,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final rows = await _client
        .from('schedule')
        .select()
        .eq('departure', departure)
        .eq('destination', destination)
        .eq('date', dateStr)
        .eq('ferry_id', ferryId)
        .order('time');

    return (rows as List)
        .map((row) => ScheduleSlot.fromMap(row as Map<String, dynamic>))
        .toList();
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
