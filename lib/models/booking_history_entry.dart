import '../constants.dart';

class BookingHistoryEntry {
  const BookingHistoryEntry({
    required this.bookingId,
    required this.reference,
    required this.route,
    required this.departurePort,
    required this.sailingAt,
    required this.ferryNum,
    required this.ticketSummary,
    required this.total,
  });

  final String bookingId;
  final String reference;
  final String route;
  final String departurePort;
  final DateTime sailingAt;
  final String ferryNum;
  final String ticketSummary;
  final double total;

  bool get isPast => sailingAt.isBefore(DateTime.now());

  int get pointsEarned => rewardPointsFor(total);

  factory BookingHistoryEntry.fromMap(Map<String, dynamic> map) {
    final schedule = map['schedule'] as Map<String, dynamic>;
    final ferry = schedule['ferry'] as Map<String, dynamic>?;
    final tickets = (map['ticket'] as List).cast<Map<String, dynamic>>();

    final summary = tickets
        .map((t) => '${(t['quantity'] as num).toInt()} ${t['type']}')
        .join(', ');

    return BookingHistoryEntry(
      bookingId: map['booking_id'] as String,
      reference: map['reference'] as String,
      route: '${schedule['departure']} → ${schedule['destination']}',
      departurePort: schedule['departure'] as String,
      sailingAt: DateTime.parse('${schedule['date']} ${schedule['time']}'),
      ferryNum: ferry?['ferry_num'] as String? ?? '—',
      ticketSummary: summary.isEmpty ? 'No tickets' : summary,
      total: (map['total'] as num).toDouble(),
    );
  }
}
