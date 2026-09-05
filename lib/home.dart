import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'models/schedule.dart';
import 'services/crowd_density_service.dart';
import 'services/schedule_service.dart';
import 'services/notification_service.dart';
import 'widgets/crowd_density_badge.dart';
import 'ferry_schedule.dart';
import 'qr_ticket.dart';
import 'account.dart';
import 'overall_reviews.dart';
import 'booking_payment.dart';
import 'rewards.dart';
import 'activity.dart';
import 'weather.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomeState();
}

class _NextSailing {
  const _NextSailing(this.slot, this.direction);
  final ScheduleSlot slot;
  final String direction;
}

class _HomeState extends State<HomePage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const deepBlue = Color(0xFF2458A8);
  static const ice = Color(0xFFEAF4F8);

  final _scheduleService = ScheduleService();
  final _crowdService = CrowdDensityService();

  bool isLoading = true;

  String userName = '';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _todayLabel {
    final now = DateTime.now();
    return '${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  ScheduleSlot? nextFerry;
  String nextFerryDirection = '';
  String? nextFerryCrowdLevel;

  int bottomNavIndex = 0;

  Timer? _minuteTicker;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    loadHomeData();
    _notificationService.startListening();
    _minuteTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;

      final next = nextFerry;
      if (next != null) {
        final parts = next.time.split(':');
        final now = DateTime.now();
        final departureTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (!departureTime.isAfter(now)) {
          loadHomeData();
          return;
        }
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    _notificationService.stopListening();
    super.dispose();
  }

  Future<void> loadHomeData() async {
    String name = 'User';
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

      name = userData?['name'] ?? 'User';
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load user name: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    // Kept in its own try/catch so a schedule-fetch problem never blocks
    // the rest of the home screen from loading. Retries once, since a
    // transient cold-start network hiccup (common right after app launch,
    // especially on emulators) can fail once and then succeed immediately
    // on a second try.
    _NextSailing? nextSailing;
    try {
      nextSailing = await _findNextSailing();
    } catch (_) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        nextSailing = await _findNextSailing();
      } catch (retryError) {
        nextSailing = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to load next sailing: $retryError'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }

    // Crowd level is supplementary — kept in its own try/catch so a
    // failure here never blocks the rest of the card from showing.
    String? crowdLevel;
    if (nextSailing != null) {
      try {
        final ferry = await _scheduleService.fetchFerry(defaultFerryId);
        final totals = await _crowdService.fetchBookedTotals(
          [nextSailing.slot.scheduleId],
        );
        final capacity = ferry.adultCap + ferry.childCap + ferry.bicycleCap + ferry.motorcycleCap;
        crowdLevel = _crowdService.levelFor(
          totals[nextSailing.slot.scheduleId] ?? 0,
          capacity,
        );
      } catch (_) {
        crowdLevel = null;
      }
    }

    if (!mounted) return;

    setState(() {
      userName = name;
      nextFerry = nextSailing?.slot;
      nextFerryDirection = nextSailing?.direction ?? '';
      nextFerryCrowdLevel = crowdLevel;
      isLoading = false;
    });
  }

  Future<_NextSailing?> _findNextSailing() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const routes = [
      ['Georgetown Terminal', 'Butterworth'],
      ['Butterworth', 'Georgetown Terminal'],
    ];

    ScheduleSlot? bestSlot;
    String bestDirection = '';

    for (final route in routes) {
      final slots = await _scheduleService.fetchSchedules(
        departure: route[0],
        destination: route[1],
        date: today,
        ferryId: defaultFerryId,
      );

      for (final slot in slots) {
        if (slot.status == 'Cancelled') continue;

        final parts = slot.time.split(':');
        final departureTime = DateTime(
          today.year,
          today.month,
          today.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (!departureTime.isAfter(now)) continue;

        if (bestSlot == null || slot.time.compareTo(bestSlot.time) < 0) {
          bestSlot = slot;
          bestDirection = route[1];
        }
      }
    }

    return bestSlot == null ? null : _NextSailing(bestSlot, bestDirection);
  }

  void _openWeatherSailing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WeatherSailingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
              destination = const OverallReviewsPage();
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
          BottomNavigationBarItem(icon: Icon(Icons.star_rate), label: 'Ratings'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
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
              Text(_todayLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherWidget() {
    return GestureDetector(
      onTap: _openWeatherSailing,
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
                  Text('Weather & Sailing Conditions',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Tap for live sea and weather conditions',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
    final next = nextFerry;

    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            Icon(Icons.directions_boat, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No more sailings today',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final displayTime = next.time.length >= 5 ? next.time.substring(0, 5) : next.time;
    final parts = next.time.split(':');
    final now = DateTime.now();
    final departureTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final minutesAway = departureTime.difference(now).inMinutes;

    return GestureDetector(
      onTap: nextFerryCrowdLevel == 'Full'
          ? null
          : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingPaymentPage(
              initialDirection: '${next.departure} \u2192 ${next.destination}',
              initialDate: DateTime.now(),
              initialTime: displayTime,
            ),
          ),
        ).then((_) {
          if (!mounted) return;
          loadHomeData();
        });
      },
      child: Container(
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
                    '$displayTime \u2192 $nextFerryDirection',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text('Departs in $minutesAway min',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  if (nextFerryCrowdLevel != null) ...[
                    const SizedBox(height: 6),
                    CrowdDensityBadge(level: nextFerryCrowdLevel!),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
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