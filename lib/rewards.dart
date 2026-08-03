import 'package:flutter/material.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const deepBlue = Color(0xFF2458A8);
  static const ice = Color(0xFFEAF4F8);

  final int points = 132;

  final List<Map<String, dynamic>> rewards = const [
    {'title': 'RM 1 Fare Discount', 'cost': 50, 'icon': Icons.local_offer},
    {'title': 'Free One-Way Trip', 'cost': 120, 'icon': Icons.confirmation_number},
    {'title': 'FerryLink Tote Bag', 'cost': 200, 'icon': Icons.shopping_bag},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Rewards'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [navy, deepBlue]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Points', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Text('$points pts',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
                const SizedBox(height: 4),
                const Text('Silver Tier · 68 pts to Gold',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Redeem Rewards',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
          const SizedBox(height: 12),
          ...rewards.map((r) => _buildRewardTile(r)),
        ],
      ),
    );
  }

  Widget _buildRewardTile(Map<String, dynamic> r) {
    final affordable = points >= (r['cost'] as int);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: ice,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: affordable ? teal : Colors.grey.shade400,
          child: Icon(r['icon'] as IconData, color: Colors.white, size: 18),
        ),
        title: Text(r['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${r['cost']} pts'),
        trailing: ElevatedButton(
          onPressed: affordable
              ? () {

          }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: teal,
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Redeem', style: TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ),
    );
  }
}
