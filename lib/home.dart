import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ferry_schedule.dart';
import 'qr_ticket.dart';
import 'account.dart';
import 'inbox.dart';
import 'booking_payment.dart';
import 'rewards.dart';
import 'activity.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const deepBlue = Color(0xFF2458A8);
  static const ice = Color(0xFFEAF4F8);

  bool isLoading = true;

  String userName = '';
  String language = 'EN';

  String weatherCondition = '';
  String weatherNote = '';

  String nextFerryDestination = '';
  String nextFerryTime = '';
  int nextFerryMinutesAway = 0;

  int bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;

      if (authUser == null) {
        throw Exception('No user is currently logged in');
      }

      final userData = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        userName = userData?['name'] ?? 'User';
        weatherCondition = 'Partly Cloudy, 29°C';
        weatherNote = 'Sailing as scheduled';
        nextFerryDestination = 'Butterworth';
        nextFerryTime = '08:20';
        nextFerryMinutesAway = 12;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        userName = 'User';
        weatherCondition = 'Partly Cloudy, 29°C';
        weatherNote = 'Sailing as scheduled';
        nextFerryDestination = 'Butterworth';
        nextFerryTime = '08:20';
        nextFerryMinutesAway = 12;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load user name: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showWeatherDetail() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Weather & Sailing Conditions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(weatherCondition, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(weatherNote),
            const SizedBox(height: 12),
            const Text(
              'Wind: 12 km/h · Sea state: Slight\nVisibility: Good',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeatherWidget(),
                    const SizedBox(height: 12),
                    _buildUpcomingScheduleCard(),
                    const SizedBox(height: 24),
                    Text('Services', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _buildServicesLayout(),
                    const SizedBox(height: 24),
                    Text('Events', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _buildEvents(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomNavIndex,
        selectedItemColor: teal,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => bottomNavIndex = index);
          Widget? destination;
          switch (index) {
            case 1:
              destination = const FerrySchedulePage();
              break;
            case 2:
              destination = const QrTicketPage();
              break;
            case 3:
              destination = const InboxPage();
              break;
            case 4:
              destination = const AccountPage();
              break;
          }
          if (destination != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination!),
            ).then((_) {
              if (!mounted) return;
              setState(() => bottomNavIndex = 0);
              loadHomeData();
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Ticket'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deepBlue, teal],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hi,', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                userName,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildLanguageToggle(),
              const SizedBox(height: 6),
              const Text('22 Jul 2026', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['BM', 'EN'].map((lang) {
          final selected = lang == language;
          return GestureDetector(
            onTap: () => setState(() => language = lang),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                lang,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: selected ? navy : Colors.white,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return GestureDetector(
      onTap: _showWeatherDetail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weatherCondition,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(weatherNote, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.directions_boat, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upcoming Ferry Schedule',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  '$nextFerryTime → $nextFerryDestination',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text('Departs in $nextFerryMinutesAway min',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesLayout() {
    const double gap = 12;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: _ServiceTile(
              label: 'Booking',
              subtitle: 'Reserve your next\nboarding slot',
              icon: Icons.confirmation_number,
              background: navy,
              foreground: Colors.white,
              iconBackground: Colors.white24,
              large: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookingPaymentPage()),
              ),
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ServiceTile(
                    label: 'Rewards',
                    subtitle: 'View your points',
                    icon: Icons.card_giftcard,
                    background: ice,
                    foreground: navy,
                    iconBackground: teal,
                    iconColor: Colors.white,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RewardsPage()),
                    ),
                  ),
                ),
                const SizedBox(height: gap),
                Expanded(
                  child: _ServiceTile(
                    label: 'Activity',
                    subtitle: 'Tickets & history',
                    icon: Icons.receipt_long,
                    background: ice,
                    foreground: navy,
                    iconBackground: deepBlue,
                    iconColor: Colors.white,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivityPage()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvents() {
    final events = [
      {
        'title': 'Gurney Food Fair',
        'subtitle': '25–27 Jul · Gurney Plaza',
        'image': 'assets/images/events/food_fair.png',
      },
      {
        'title': 'Weekend Pasar Malam',
        'subtitle': 'Every Sat · Jalan Macalister',
        'image': 'assets/images/events/pasar_malam.png',
      },
      {
        'title': 'Penang Design Market',
        'subtitle': '2 Aug · Hin Bus Depot',
        'image': 'assets/images/events/design_market.png',
      },
    ];
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final event = events[index];
          return Container(
            width: 200,
            decoration: BoxDecoration(
              color: ice,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  event['image']!,
                  width: double.infinity,
                  height: 100,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['subtitle']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.iconBackground,
    this.iconColor,
    this.large = false,
    this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color iconBackground;
  final Color? iconColor;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(large ? 14 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: large ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: large ? 22 : 15,
                backgroundColor: iconBackground,
                child: Icon(icon, color: iconColor ?? foreground, size: large ? 22 : 15),
              ),
              SizedBox(height: large ? 10 : 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: foreground, fontWeight: FontWeight.bold, fontSize: large ? 16 : 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: foreground.withOpacity(0.75), fontSize: large ? 11.5 : 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}