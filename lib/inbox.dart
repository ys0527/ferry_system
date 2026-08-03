import 'package:flutter/material.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  final List<Map<String, String>> notifications = const [
    {'title': 'Ferry Delayed 5 min', 'date': '23 Jul', 'icon': 'warning'},
    {'title': 'Booking Confirmed \u2013 08:20 to Butterworth', 'date': '23 Jul', 'icon': 'check'},
    {'title': 'Weather Advisory: Choppy Seas Expected', 'date': '22 Jul', 'icon': 'weather'},
    {'title': '+8 Loyalty Points Earned', 'date': '21 Jul', 'icon': 'gift'},
    {'title': 'General Notification', 'date': '18 Jul', 'icon': 'bell'},
  ];

  IconData _iconFor(String key) {
    switch (key) {
      case 'warning':
        return Icons.report_problem;
      case 'check':
        return Icons.check_circle;
      case 'weather':
        return Icons.cloud;
      case 'gift':
        return Icons.card_giftcard;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Inbox'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final n = notifications[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: teal,
                  child: Icon(_iconFor(n['icon']!), color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    n['title']!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                  ),
                ),
                const SizedBox(width: 8),
                Text(n['date']!, style: const TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          );
        },
      ),
    );
  }
}
