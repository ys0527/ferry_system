import 'package:flutter/material.dart';
import 'account_management.dart';
import 'rewards.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  final String userName = 'Sin Wai Yan';

  final List<Map<String, dynamic>> menuItems = const [
    {'label': 'Account & Security', 'icon': Icons.manage_accounts},
    {'label': 'Rewards', 'icon': Icons.card_giftcard},
    {'label': 'Help & Support', 'icon': Icons.support_agent},
    {'label': 'Logout', 'icon': Icons.logout},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountManagementPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: navy,
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navy)),
                        const SizedBox(height: 2),
                        const Text('View Profile',
                            style: TextStyle(fontSize: 12, color: teal)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: navy),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...menuItems.map((item) => _buildMenuTile(context, item)),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'FerryLink Penang · Ver. 1.0.0',
              style: TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, Map<String, dynamic> item) {
    final isLogout = item['label'] == 'Logout';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: ice,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(item['icon'] as IconData, color: isLogout ? Colors.redAccent : navy),
        title: Text(
          item['label'] as String,
          style: TextStyle(color: isLogout ? Colors.redAccent : Colors.black87),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (item['label'] == 'Account & Security') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountManagementPage()),
            );
            return;
          }
          if (item['label'] == 'Rewards') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RewardsPage()),
            );
            return;
          }
        },
      ),
    );
  }
}
