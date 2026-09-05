import 'package:flutter/material.dart';
import 'booking_payment.dart';
import 'constants.dart';
import 'models/ferry.dart';
import 'models/schedule.dart';
import 'services/crowd_density_service.dart';
import 'services/schedule_service.dart';
import 'widgets/crowd_density_badge.dart';

class FerrySchedulePage extends StatefulWidget {
  const FerrySchedulePage({super.key});

  @override
  State<FerrySchedulePage> createState() => _FerryScheduleState();
}

class _FerryScheduleState extends State<FerrySchedulePage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);
  static const alert = Color(0xFFE0703E);

  final _scheduleService = ScheduleService();
  final _crowdService = CrowdDensityService();
  final Map<String, String> _crowdLevels = {};

  String selectedDestination = 'Butterworth';

  late final List<DateTime> availableDates =
  List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  late DateTime selectedDate = availableDates.first;

  late Future<List<ScheduleSlot>> _scheduleFuture;
  Ferry? _ferry;

  String? _expandedPeriod;

  @override
  void initState() {
    super.initState();
    _resetExpandedPeriod();
    _scheduleFuture = _loadSchedule();
  }

  String get _departure =>
      selectedDestination == 'Butterworth' ? 'Georgetown Terminal' : 'Butterworth';

  String get _direction => '$_departure \u2192 $selectedDestination';

  Future<List<ScheduleSlot>> _loadSchedule() async {
    _ferry ??= await _scheduleService.fetchFerry(defaultFerryId);
    return _scheduleService.fetchSchedules(
      departure: _departure,
      destination: selectedDestination,
      date: selectedDate,
      ferryId: defaultFerryId,
    );
  }

  void _refreshSchedule() {
    setState(() {
      _resetExpandedPeriod();
      _scheduleFuture = _loadSchedule();
      _crowdLevels.clear();
    });
  }

  Future<void> _loadCrowdLevelsFor(List<ScheduleSlot> entries) async {
    if (_ferry == null) return;

    final missingIds = entries
        .map((e) => e.scheduleId)
        .where((id) => !_crowdLevels.containsKey(id))
        .toList();
    if (missingIds.isEmpty) return;

    try {
      final totals = await _crowdService.fetchBookedTotals(missingIds);
      final capacity = _ferry!.adultCap +
          _ferry!.childCap +
          _ferry!.bicycleCap +
          _ferry!.motorcycleCap;

      if (!mounted) return;
      setState(() {
        for (final id in missingIds) {
          final booked = totals[id] ?? 0;
          _crowdLevels[id] = _crowdService.levelFor(booked, capacity);
        }
      });
    } catch (_) {
    }
  }

  String _periodForHour(int hour) {
    if (hour < 12) return 'Morning';
    if (hour < 18) return 'Afternoon';
    return 'Evening';
  }

  void _resetExpandedPeriod() {
    final now = DateTime.now();
    _expandedPeriod =
    _isSameDay(selectedDate, now) ? _periodForHour(now.hour) : 'Morning';
  }

  void _togglePeriod(String label) {
    setState(() {
      _expandedPeriod = (_expandedPeriod == label) ? null : label;
    });
  }

  String _weekdayLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatTime(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

  String _displayStatus(ScheduleSlot entry) {
    if (entry.status == 'Delayed' && entry.delayTime > 0) {
      return 'Delayed ${entry.delayTime} min';
    }
    return entry.status;
  }

  DateTime _entryDateTime(ScheduleSlot entry) {
    final parts = entry.time.split(':');
    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  List<ScheduleSlot> _applyPastFilter(List<ScheduleSlot> entries) {
    final now = DateTime.now();
    if (!_isSameDay(selectedDate, now)) return entries;
    return entries.where((e) => _entryDateTime(e).isAfter(now)).toList();
  }

  List<MapEntry<String, List<ScheduleSlot>>> _groupByPeriod(List<ScheduleSlot> entries) {
    final morning = <ScheduleSlot>[];
    final afternoon = <ScheduleSlot>[];
    final evening = <ScheduleSlot>[];

    for (final e in entries) {
      final hour = int.parse(e.time.split(':')[0]);
      if (hour < 12) {
        morning.add(e);
      } else if (hour < 18) {
        afternoon.add(e);
      } else {
        evening.add(e);
      }
    }

    int byTime(ScheduleSlot a, ScheduleSlot b) => a.time.compareTo(b.time);
    morning.sort(byTime);
    afternoon.sort(byTime);
    evening.sort(byTime);

    final groups = <MapEntry<String, List<ScheduleSlot>>>[];
    if (morning.isNotEmpty) groups.add(MapEntry('Morning', morning));
    if (afternoon.isNotEmpty) groups.add(MapEntry('Afternoon', afternoon));
    if (evening.isNotEmpty) groups.add(MapEntry('Evening', evening));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Ferry Schedule'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshSchedule(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDestinationToggle(),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 16),
            const SizedBox(height: 8),
            FutureBuilder<List<ScheduleSlot>>(
              future: _scheduleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: navy)),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Unable to load schedule: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  );
                }

                final raw = snapshot.data ?? [];
                final visible = _applyPastFilter(raw);

                if (visible.isEmpty) {
                  final isToday = _isSameDay(selectedDate, DateTime.now());
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      isToday && raw.isNotEmpty
                          ? 'No more sailings today.'
                          : 'No sailings for this date.',
                      style: const TextStyle(color: Colors.black45, fontSize: 12.5),
                    ),
                  );
                }

                final groups = _groupByPeriod(visible);

                List<ScheduleSlot>? expandedEntries;
                for (final g in groups) {
                  if (g.key == _expandedPeriod) {
                    expandedEntries = g.value;
                    break;
                  }
                }
                if (expandedEntries != null) {
                  final entriesToLoad = expandedEntries;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _loadCrowdLevelsFor(entriesToLoad);
                  });
                }

                return Column(
                  children: groups.expand((group) {
                    final expanded = group.key == _expandedPeriod;
                    return [
                      _buildSectionHeader(group.key, group.value.length, expanded),
                      if (expanded) ...group.value.map(_buildScheduleRow),
                    ];
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, int count, bool expanded) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: GestureDetector(
        onTap: () => _togglePeriod(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: expanded ? navy.withOpacity(0.08) : ice,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: expanded ? navy.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: navy),
              ),
              const SizedBox(width: 6),
              Text(
                '($count)',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const Spacer(),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: navy,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: ['Georgetown Terminal', 'Butterworth'].map((dest) {
          final selected = dest == selectedDestination;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => selectedDestination = dest);
                _refreshSchedule();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'To $dest',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDatePicker() {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableDates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = availableDates[index];
          final selected = _isSameDay(date, selectedDate);
          return GestureDetector(
            onTap: () {
              setState(() => selectedDate = date);
              _refreshSchedule();
            },
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: selected ? teal : ice,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_weekdayLabel(date),
                      style: TextStyle(
                          fontSize: 11.5, color: selected ? Colors.white : navy, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${date.day}',
                      style: TextStyle(
                          fontSize: 15, color: selected ? Colors.white : navy, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleRow(ScheduleSlot entry) {
    final delayed = entry.status == 'Delayed';
    final cancelled = entry.status == 'Cancelled';
    final displayTime = _formatTime(entry.time);
    final crowdLevel = _crowdLevels[entry.scheduleId];
    final full = crowdLevel == 'Full';
    final blocked = cancelled || full;

    return GestureDetector(
      onTap: blocked
          ? null
          : () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingPaymentPage(
              initialDirection: _direction,
              initialDate: selectedDate,
              initialTime: displayTime,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: ice,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(displayTime,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navy)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'To $selectedDestination',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cancelled ? Colors.grey : (delayed ? alert : teal),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _displayStatus(entry),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: navy, size: 20),
                ],
              ),
              if (crowdLevel != null && !cancelled) ...[
                const SizedBox(height: 8),
                CrowdDensityBadge(level: crowdLevel),
              ],
            ],
          ),
        ),
      ),
    );
  }
}