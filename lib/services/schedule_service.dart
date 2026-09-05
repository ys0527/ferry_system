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

  Future<Map<String, Ferry>> fetchFerries(Iterable<String> ferryIds) async {
    final ids = ferryIds.toSet().toList();
    if (ids.isEmpty) return {};

    final rows = await _client.from('ferry').select().inFilter('ferry_id', ids);

    return {
      for (final row in (rows as List))
        (row as Map<String, dynamic>)['ferry_id'] as String: Ferry.fromMap(row),
    };
  }

  Future<List<ScheduleSlot>> fetchSchedules({
    required String departure,
    required String destination,
    required DateTime date,
  }) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final rows = await _client
        .from('schedule')
        .select()
        .eq('departure', departure)
        .eq('destination', destination)
        .eq('date', dateStr)
        .order('time');

    return (rows as List)
        .map((row) => ScheduleSlot.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, int>> fetchBookedCounts(String scheduleId) async {
    final rows = await _client.rpc(
      'get_booked_counts',
      params: {'p_schedule_id': scheduleId},
    );

    final counts = <String, int>{};
    for (final row in (rows as List)) {
      final type = row['type'] as String;
      final key = ticketTypeKeys[type] ?? type;
      final total = (row['total_booked'] as num).toInt();
      counts[key] = total;
    }
    return counts;
  }
}