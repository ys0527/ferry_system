import '../constants.dart';

class TicketLine {
  const TicketLine({
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String type;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory TicketLine.fromMap(Map<String, dynamic> map) => TicketLine(
    type: map['type'] as String,
    quantity: (map['quantity'] as num).toInt(),
    unitPrice: (map['unit_price'] as num).toDouble(),
    subtotal: (map['subtotal'] as num).toDouble(),
  );
}

class PaymentRecord {
  const PaymentRecord({
    required this.method,
    required this.status,
    required this.amount,
    required this.paidAt,
    required this.intentId,
  });

  final String method;
  final String status;
  final double amount;
  final DateTime paidAt;
  final String? intentId;

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    method: map['method'] as String,
    status: map['status'] as String,
    amount: (map['total_amount'] as num).toDouble(),
    paidAt: DateTime.parse(map['created_at'] as String).toLocal(),
    intentId: map['stripe_payment_intent_id'] as String?,
  );
}

class BookingDetail {
  const BookingDetail({
    required this.bookingId,
    required this.reference,
    required this.status,
    required this.route,
    required this.sailingAt,
    required this.ferryNum,
    required this.scheduleStatus,
    required this.delayMinutes,
    required this.lines,
    required this.total,
    required this.bookedAt,
    this.payment,
    this.discountAmount,
    this.voucherTitle,
  });

  final String bookingId;
  final String reference;
  final String status;
  final String route;
  final DateTime sailingAt;
  final String ferryNum;
  final String scheduleStatus;
  final int delayMinutes;
  final List<TicketLine> lines;
  final double total;
  final DateTime bookedAt;
  final PaymentRecord? payment;
  final double? discountAmount;
  final String? voucherTitle;

  bool get isPast => sailingAt.isBefore(DateTime.now());

  int get pointsEarned => rewardPointsFor(total);

  String get ticketSummary => lines.isEmpty
      ? 'No tickets'
      : lines.map((l) => '${l.quantity} ${l.type}').join(', ');

  factory BookingDetail.fromMap(
    Map<String, dynamic> map, {
    double? discountAmount,
    String? voucherTitle,
  }) {
    final schedule = map['schedule'] as Map<String, dynamic>;
    final ferry = schedule['ferry'] as Map<String, dynamic>?;
    final payments =
        (map['payment'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    return BookingDetail(
      discountAmount: discountAmount,
      voucherTitle: voucherTitle,
      bookingId: map['booking_id'] as String,
      reference: map['reference'] as String,
      status: map['status'] as String,
      route: '${schedule['departure']} → ${schedule['destination']}',
      sailingAt: DateTime.parse('${schedule['date']} ${schedule['time']}'),
      ferryNum: ferry?['ferry_num'] as String? ?? '—',
      scheduleStatus: schedule['status'] as String? ?? '—',
      delayMinutes: (schedule['delay_time'] as num?)?.toInt() ?? 0,
      lines: (map['ticket'] as List)
          .cast<Map<String, dynamic>>()
          .map(TicketLine.fromMap)
          .toList(),
      total: (map['total'] as num).toDouble(),
      bookedAt: DateTime.parse(map['created_at'] as String).toLocal(),
      payment: payments.isEmpty ? null : PaymentRecord.fromMap(payments.first),
    );
  }
}
