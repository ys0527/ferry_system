class Booking {
  const Booking({
    required this.bookingId,
    required this.status,
    required this.total,
    required this.userId,
    required this.scheduleId,
    this.reference,
    this.qrCode,
  });

  final String bookingId;
  final String status;
  final double total;
  final String userId;
  final String scheduleId;
  final String? reference;
  final String? qrCode;

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      bookingId: map['booking_id'] as String,
      status: map['status'] as String,
      total: (map['total'] as num).toDouble(),
      userId: map['user_id'] as String,
      scheduleId: map['schedule_id'] as String,
      reference: map['reference'] as String?,
      qrCode: map['qr_code'] as String?,
    );
  }
}
