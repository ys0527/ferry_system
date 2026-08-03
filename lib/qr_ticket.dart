import 'package:flutter/material.dart';

class QrTicketPage extends StatelessWidget {
  const QrTicketPage({super.key});

  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('My QR Ticket'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                const Text('Georgetown Terminal \u2192 Butterworth',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('08:20 · Slot B · 1 Adult',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 20),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_2, size: 120, color: navy),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('RM 1.20 · Paid',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
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
      ),
    );
  }
}
