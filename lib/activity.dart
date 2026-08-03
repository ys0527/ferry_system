import 'package:flutter/material.dart';
import 'reviews_ratings.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityState();
}

class _ActivityState extends State<ActivityPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  bool showUpcoming = true;

  final List<Map<String, dynamic>> upcomingBookings = const [
    {
      'route': 'Georgetown Terminal \u2192 Butterworth',
      'datetime': '23 Jul \u00b7 08:20',
      'status': 'Confirmed',
      'ferryNo': 'FL-204',
      'port': 'Georgetown Terminal',
    },
    {
      'route': 'Butterworth \u2192 Georgetown Terminal',
      'datetime': '25 Jul \u00b7 18:00',
      'status': 'Confirmed',
      'ferryNo': 'FL-311',
      'port': 'Butterworth Terminal',
    },
  ];

  final List<Map<String, dynamic>> pastBookings = const [
    {
      'route': 'Georgetown Terminal \u2192 Butterworth',
      'datetime': '18 Jul \u00b7 07:50',
      'status': 'Completed',
      'ferryNo': 'FL-198',
      'port': 'Georgetown Terminal',
      'points': 8,
    },
    {
      'route': 'Butterworth \u2192 Georgetown Terminal',
      'datetime': '15 Jul \u00b7 17:30',
      'status': 'Completed',
      'ferryNo': 'FL-276',
      'port': 'Butterworth Terminal',
      'points': 8,
    },
    {
      'route': 'Georgetown Terminal \u2192 Butterworth',
      'datetime': '10 Jul \u00b7 08:20',
      'status': 'Completed',
      'ferryNo': 'FL-142',
      'port': 'Georgetown Terminal',
      'points': 6,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bookings = showUpcoming ? upcomingBookings : pastBookings;
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
            child: bookings.isEmpty
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isPast = booking['status'] == 'Completed';
    return Container(
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
                    Text(booking['route'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: navy)),
                    const SizedBox(height: 2),
                    Text(booking['datetime'] as String, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 2),
                    Text(
                      'Ferry ${booking['ferryNo']} \u00b7 ${booking['port']}',
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
                        builder: (context) => ReviewsRatingsPage(tripLabel: booking['route'] as String),
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
                Text('+${booking['points']} Reward Points earned',
                    style: const TextStyle(fontSize: 10.5, color: navy, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
