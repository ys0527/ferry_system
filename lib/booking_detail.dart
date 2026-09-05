import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'models/booking_detail.dart';
import 'services/booking_service.dart';
import 'widgets/ticket_qr_card.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);
  static const alert = Color(0xFFE0703E);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final _bookingService = BookingService();

  bool _loading = true;
  String? _error;
  BookingDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _bookingService.fetchBookingDetail(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this booking: $e';
        _loading = false;
      });
    }
  }

  String _dayAndTime(DateTime at) {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${_months[at.month - 1]} · $hh:$mm';
  }

  String _dateTimeWithYear(DateTime at) {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${_months[at.month - 1]} ${at.year} · $hh:$mm';
  }

  String _shortIntent(String? id) {
    if (id == null || id.isEmpty) return '—';
    return id.length <= 14 ? id : '…${id.substring(id.length - 12)}';
  }

  Future<void> _addToCalendar(BookingDetail d) async {
    final description = StringBuffer()
      ..writeln('Booking ${d.reference}')
      ..writeln(d.ticketSummary)
      ..writeln('Total RM ${d.total.toStringAsFixed(2)}');
    if (d.delayMinutes > 0) {
      description.writeln('Sailing reported +${d.delayMinutes} min delay.');
    }

    final event = Event(
      title: 'Ferry: ${d.route}',
      location: d.route.split('→').first.trim(),
      description: description.toString().trimRight(),
      startDate: d.sailingAt,
      endDate: d.sailingAt.add(const Duration(minutes: 30)),
    );

    bool opened;
    try {
      opened = await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      opened = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opened your calendar app.'
              : 'No calendar app could be opened on this device.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Booking Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildDetail(_detail!),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(BookingDetail d) {
    final payment = d.payment;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TicketQrCard(
          route: d.route,
          subtitle: '${_dayAndTime(d.sailingAt)} · ${d.ticketSummary}',
          reference: d.reference,
          fare: d.total,
          completed: d.isPast,
        ),
        const SizedBox(height: 16),

        if (!d.isPast) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addToCalendar(d),
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Add to calendar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: navy),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: ice,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _group(
                'Sailing',
                first: true,
                rows: [
                  _row('Ferry', d.ferryNum),
                  _row(
                    'Sailing status',
                    d.delayMinutes > 0
                        ? '${d.scheduleStatus} (+${d.delayMinutes} min)'
                        : d.scheduleStatus,
                    highlight: d.delayMinutes > 0,
                  ),
                ],
              ),
              _group(
                'Tickets',
                rows: [
                  ...d.lines.map(
                    (l) => _row(
                      '${l.type} × ${l.quantity}',
                      'RM ${l.subtotal.toStringAsFixed(2)}',
                      caption: 'RM ${l.unitPrice.toStringAsFixed(2)} each',
                    ),
                  ),
                  if (d.discountAmount != null && d.discountAmount! > 0)
                    _row(
                      d.voucherTitle ?? 'Voucher',
                      '− RM ${d.discountAmount!.toStringAsFixed(2)}',
                    ),
                  _row('Total', 'RM ${d.total.toStringAsFixed(2)}', bold: true),
                ],
              ),
              _group(
                'Payment',
                rows: payment == null
                    ? [
                        _row(
                          'Status',
                          d.status == 'Confirmed'
                              ? 'Covered by voucher'
                              : 'Not paid yet',
                        ),
                      ]
                    : [
                        _row('Method', payment.method),
                        _row('Status', payment.status),
                        _row('Paid at', _dateTimeWithYear(payment.paidAt)),
                        _row(
                          'Transaction',
                          _shortIntent(payment.intentId),
                          mono: true,
                        ),
                      ],
              ),
              _group(
                'Booking',
                rows: [
                  _row('Booked at', _dateTimeWithYear(d.bookedAt)),
                  _row('Status', d.status),
                ],
              ),
              if (d.isPast) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, size: 16, color: teal),
                    const SizedBox(width: 8),
                    Text(
                      '+${d.pointsEarned} Reward Points earned',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: navy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(
    String title, {
    required List<Widget> rows,
    bool first = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!first) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: navy,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        ...rows,
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    String? caption,
    bool bold = false,
    bool mono = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
                if (caption != null)
                  Text(
                    caption,
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: mono ? 10.5 : 11.5,
                color: highlight ? alert : navy,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
