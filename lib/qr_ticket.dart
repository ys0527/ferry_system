import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'models/qr_ticket_data.dart';
import 'services/booking_service.dart';
import 'services/current_user_service.dart';
import 'widgets/ticket_qr_card.dart';

class QrTicketPage extends StatefulWidget {
  const QrTicketPage({this.initialData, super.key});

  /// Passed in right after a successful payment. When omitted (e.g. the
  /// bottom-nav "QR" tab), the page fetches the user's latest confirmed
  /// ticket instead.
  final QrTicketData? initialData;

  @override
  State<QrTicketPage> createState() => _QrTicketPageState();
}

class _QrTicketPageState extends State<QrTicketPage> {
  static const navy = Color(0xFF3472CA);
  static const ice = Color(0xFFEAF4F8);

  final _bookingService = BookingService();

  bool _loading = false;
  QrTicketData? _data;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    if (_data == null) {
      _loadLatestTicket();
    }
  }

  Future<void> _loadLatestTicket() async {
    setState(() => _loading = true);
    try {
      final userId = await currentUserId();
      final data = await _bookingService.fetchLatestConfirmedTicket(userId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addToCalendar(QrTicketData data) async {
    final description = StringBuffer()
      ..writeln('Booking ${data.reference}')
      ..writeln(data.ticketSummary)
      ..writeln('Total RM ${data.fare.toStringAsFixed(2)}');

    final event = Event(
      title: 'Ferry: ${data.route}',
      location: data.route.split('→').first.trim(),
      description: description.toString().trimRight(),
      startDate: data.sailingAt,
      endDate: data.sailingAt.add(const Duration(minutes: 30)),
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
        title: const Text('My QR Ticket'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? _buildEmptyState()
              : _buildTicket(_data!),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 64, color: navy),
            const SizedBox(height: 12),
            const Text(
              'No active ticket yet',
              style: TextStyle(fontWeight: FontWeight.bold, color: navy),
            ),
            const SizedBox(height: 6),
            const Text(
              'Book a sailing to get your QR ticket here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicket(QrTicketData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TicketQrCard(
          route: data.route,
          subtitle: '${data.date} · ${data.time} · ${data.ticketSummary}',
          reference: data.reference,
          fare: data.fare,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _addToCalendar(data),
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(14)),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: navy, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Show this QR code to the boarding officer to check in.',
                  style: TextStyle(fontSize: 12, color: navy),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
