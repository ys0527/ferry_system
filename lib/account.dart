import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_management.dart';
import 'login.dart';
import 'rewards.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  String userName = 'Loading...';
  String? profileUrl;
  bool isLoading = true;

  final List<Map<String, dynamic>> menuItems = const [
    {
      'label': 'Account & Security',
      'icon': Icons.manage_accounts,
    },
    {
      'label': 'Rewards',
      'icon': Icons.card_giftcard,
    },
    {
      'label': 'Help & Support',
      'icon': Icons.support_agent,
    },
    {
      'label': 'Logout',
      'icon': Icons.logout,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;

      if (authUser == null) {
        throw Exception('No user is currently logged in');
      }

      final userData = await Supabase.instance.client
          .from('users')
          .select('name, profile')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        userName = userData?['name'] ?? 'User';
        profileUrl = userData?['profile'];
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        userName = 'User';
        profileUrl = null;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load account: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _openAccountManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountManagementPage(),
      ),
    );

    // Reload the latest name and profile picture after returning.
    await _loadUserData();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
          (route) => false,
    );
  }

  Future<void> _handleMenuTap(String label) async {
    switch (label) {
      case 'Account & Security':
        await _openAccountManagement();
        break;

      case 'Rewards':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RewardsPage(),
          ),
        );
        break;

      case 'Help & Support':
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Help & Support is coming soon'),
          ),
        );
        break;

      case 'Logout':
        await _logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProfilePicture =
        profileUrl != null && profileUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Account'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _openAccountManagement,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ice,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: navy,
                      backgroundImage: hasProfilePicture
                          ? NetworkImage(profileUrl!)
                          : null,
                      child: hasProfilePicture
                          ? null
                          : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoading ? 'Loading...' : userName,
                            style: const TextStyle(
                              color: navy,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'View Profile',
                            style: TextStyle(
                              color: teal,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: navy,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ...menuItems.map((item) {
              final label = item['label'] as String;
              final icon = item['icon'] as IconData;
              final isLogout = label == 'Logout';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: ice,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _handleMenuTap(label),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 17,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: isLogout ? Colors.redAccent : navy,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                color: isLogout
                                    ? Colors.redAccent
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
            const Center(
              child: Text(
                'FerryLink Penang · Ver. 1.0.0',
                style: TextStyle(
                  color: Colors.black38,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}