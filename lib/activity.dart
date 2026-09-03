import 'package:flutter/material.dart';
import 'booking_detail.dart';
import 'constants.dart';
import 'models/booking_history_entry.dart';
import 'reviews_ratings.dart';
import 'services/booking_service.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityState();
}

class _ActivityState extends State<ActivityPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  final _bookingService = BookingService();

  bool showUpcoming = true;
  bool _loading = true;
  String? _error;
  List<BookingHistoryEntry> _upcoming = const [];
  List<BookingHistoryEntry> _past = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _bookingService.fetchBookingHistory(demoUserId);
      final upcoming = entries.where((e) => !e.isPast).toList()
        ..sort((a, b) => a.sailingAt.compareTo(b.sailingAt));
      final past = entries.where((e) => e.isPast).toList()
        ..sort((a, b) => b.sailingAt.compareTo(a.sailingAt));
      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
        _past = past;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your bookings: $e';
        _loading = false;
      });
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatSailing(DateTime at) {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${_months[at.month - 1]} \u00b7 $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final bookings = showUpcoming ? _upcoming : _past;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Activity'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  _buildTabButton('Upcoming', true),
                  _buildTabButton('Past', false),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : bookings.isEmpty
                        ? const Center(child: Text('No bookings here yet.'))
                        : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
            ),
          ),
        ],
      ),
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
            TextButton(onPressed: _loadHistory, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isUpcomingTab) {
    final selected = showUpcoming == isUpcomingTab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => showUpcoming = isUpcomingTab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? navy : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : navy,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingHistoryEntry booking) {
    final isPast = booking.isPast;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isPast ? Colors.grey.shade400 : teal,
                child: const Icon(Icons.directions_boat, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.route,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: isPast ? Colors.black45 : navy)),
                    const SizedBox(height: 2),
                    Text(
                      isPast
                          ? 'Completed \u00b7 ${_formatSailing(booking.sailingAt)}'
                          : _formatSailing(booking.sailingAt),
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ferry ${booking.ferryNum} \u00b7 ${booking.departurePort}',
                      style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isPast)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewsRatingsPage(tripLabel: booking.route),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Rate',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Confirmed',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (isPast) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.card_giftcard, size: 14, color: teal),
                const SizedBox(width: 6),
                Text('+${booking.pointsEarned} Reward Points earned',
                    style: const TextStyle(fontSize: 10.5, color: navy, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPage(bookingId: booking.bookingId),
        ),
      ),
      child: card,
    );
  }
}
