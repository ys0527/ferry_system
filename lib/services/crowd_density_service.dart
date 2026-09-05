import '../supabase_config.dart';

class CrowdDensityService {
  final _client = supabase;

  Future<Map<String, int>> fetchBookedTotals(List<String> scheduleIds) async {
    if (scheduleIds.isEmpty) return {};

    final rows = await _client.rpc(
      'get_crowd_totals',
      params: {'schedule_ids': scheduleIds},
    );

    final totals = <String, int>{};
    for (final row in (rows as List)) {
      final scheduleId = row['schedule_id'] as String;
      final total = (row['total_booked'] as num).toInt();
      totals[scheduleId] = total;
    }
    return totals;
  }

  String levelFor(int booked, int capacity) {
    if (capacity <= 0) return 'Low';
    if (booked >= capacity) return 'Full';
    final ratio = booked / capacity;
    if (ratio < 0.4) return 'Low';
    if (ratio < 0.75) return 'Moderate';
    return 'High';
  }
}