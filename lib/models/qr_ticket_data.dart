class QrTicketData {
  const QrTicketData({
    required this.reference,
    required this.route,
    required this.date,
    required this.time,
    required this.ticketSummary,
    required this.fare,
    required this.sailingAt,
  });

  final String reference;
  final String route;
  final String date;
  final String time;
  final String ticketSummary;
  final double fare;
  final DateTime sailingAt;
}
