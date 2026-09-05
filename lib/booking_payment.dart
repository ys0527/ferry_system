import 'package:flutter/material.dart';
import 'constants.dart';
import 'models/ferry.dart';
import 'models/qr_ticket_data.dart';
import 'models/schedule.dart';
import 'models/voucher.dart';
import 'payment.dart';
import 'qr_ticket.dart';
import 'rewards.dart';
import 'services/booking_service.dart';
import 'services/crowd_density_service.dart';
import 'services/current_user_service.dart';
import 'services/reward_service.dart';
import 'services/schedule_service.dart';

class BookingPaymentPage extends StatefulWidget {
  const BookingPaymentPage({
    this.initialDirection,
    this.initialDate,
    this.initialTime,
    super.key,
  });

  final String? initialDirection;
  final DateTime? initialDate;
  final String? initialTime;

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentState();
}

class _BookingPaymentState extends State<BookingPaymentPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);
  static const alert = Color(0xFFE0703E);
  static const levelGreen = Color(0xFF3CAE6A);
  static const levelAmber = Color(0xFFE3A72E);
  static const levelRed = Color(0xFFE0483C);

  final _scheduleService = ScheduleService();
  final _bookingService = BookingService();
  final _rewardService = RewardService();
  final _crowdService = CrowdDensityService();

  late String direction = widget.initialDirection ?? 'Georgetown Terminal → Butterworth';
  late final List<DateTime> availableDates =
  List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  late DateTime selectedDate = widget.initialDate ?? availableDates.first;

  late String selectedTime = widget.initialTime ?? '08:20';

  final List<Map<String, dynamic>> ticketTypes = [
    {'key': 'adult', 'label': 'Adult', 'icon': Icons.person, 'price': ticketTypePrices['adult']!},
    {'key': 'child', 'label': 'Child', 'icon': Icons.child_care, 'price': ticketTypePrices['child']!},
    {'key': 'bicycle', 'label': 'Bicycle', 'icon': Icons.pedal_bike, 'price': ticketTypePrices['bicycle']!},
    {'key': 'motorcycle', 'label': 'Motorcycle', 'icon': Icons.two_wheeler, 'price': ticketTypePrices['motorcycle']!},
  ];

  final Map<String, int> counts = {'adult': 1, 'child': 0, 'bicycle': 0, 'motorcycle': 0};

  bool _loadingSlot = true;
  bool _confirming = false;
  String? _slotError;
  List<ScheduleSlot> _availableSlots = const [];
  ScheduleSlot? _schedule;
  Ferry? _ferry;
  Map<String, int> _booked = {};

  Map<String, String> _slotCrowdLevels = {};

  bool _loadingVouchers = true;
  List<Voucher> _vouchers = const [];
  Voucher? _selectedVoucher;

  @override
  void initState() {
    super.initState();
    _loadSlot();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _loadingVouchers = true);
    try {
      final userId = await currentUserId();
      final vouchers = await _rewardService.fetchAvailableVouchers(userId);
      if (!mounted) return;
      setState(() {
        _vouchers = vouchers;
        _loadingVouchers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vouchers = const [];
        _loadingVouchers = false;
      });
    }
  }

  void _openRewards() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RewardsPage()),
    ).then((_) => _loadVouchers());
  }

  List<String> get _departureDestination {
    return direction.startsWith('Georgetown')
        ? const ['Georgetown Terminal', 'Butterworth']
        : const ['Butterworth', 'Georgetown Terminal'];
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

  Future<Map<String, String>> _loadSlotCrowdLevels(
      List<ScheduleSlot> slots,
      Ferry ferry,
      ) async {
    if (slots.isEmpty) return {};
    try {
      final ids = slots.map((s) => s.scheduleId).toList();
      final totals = await _crowdService.fetchBookedTotals(ids);
      final capacity =
          ferry.adultCap + ferry.childCap + ferry.bicycleCap + ferry.motorcycleCap;

      final levels = <String, String>{};
      for (final slot in slots) {
        final booked = totals[slot.scheduleId] ?? 0;
        levels[slot.scheduleId] = _crowdService.levelFor(booked, capacity);
      }
      return levels;
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadSlot() async {
    setState(() {
      _loadingSlot = true;
      _slotError = null;
      _schedule = null;
      _booked = {};
    });
    try {
      final parts = _departureDestination;
      final rawSlots = await _scheduleService.fetchSchedules(
        departure: parts[0],
        destination: parts[1],
        date: selectedDate,
        ferryId: defaultFerryId,
      );

      final filteredSlots = _applyPastFilter(rawSlots);

      filteredSlots.sort((a, b) => a.time.compareTo(b.time));

      final ferry = await _scheduleService.fetchFerry(defaultFerryId);
      final slotCrowdLevels = await _loadSlotCrowdLevels(filteredSlots, ferry);

      ScheduleSlot? chosen;
      for (final slot in filteredSlots) {
        if (slot.time.startsWith(selectedTime) &&
            slotCrowdLevels[slot.scheduleId] != 'Full') {
          chosen = slot;
          break;
        }
      }
      chosen ??= filteredSlots
          .where((s) => slotCrowdLevels[s.scheduleId] != 'Full')
          .cast<ScheduleSlot?>()
          .firstWhere((_) => true, orElse: () => null);

      final booked = chosen == null
          ? <String, int>{}
          : await _scheduleService.fetchBookedCounts(chosen.scheduleId);

      if (!mounted) return;
      setState(() {
        _availableSlots = filteredSlots;
        _schedule = chosen;
        _slotCrowdLevels = slotCrowdLevels;
        if (chosen != null) selectedTime = chosen.time.substring(0, 5);
        _ferry = ferry;
        _booked = booked;
        _loadingSlot = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slotError = 'Could not load sailings for this day: $e';
        _loadingSlot = false;
      });
    }
  }

  Future<void> _selectSlot(ScheduleSlot slot) async {
    if (slot.scheduleId == _schedule?.scheduleId) return;
    if (_slotCrowdLevels[slot.scheduleId] == 'Full') return;
    setState(() {
      _schedule = slot;
      selectedTime = slot.time.substring(0, 5);
    });
    try {
      final booked = await _scheduleService.fetchBookedCounts(slot.scheduleId);
      if (!mounted) return;
      setState(() => _booked = booked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _slotError = 'Could not load crowd data: $e');
    }
  }

  double get fare {
    double total = 0;
    for (final t in ticketTypes) {
      total += (t['price'] as double) * (counts[t['key']] ?? 0);
    }
    return total;
  }

  double get displayFare =>
      _selectedVoucher == null ? fare : _selectedVoucher!.previewFare(fare);

  String get ticketSummary {
    final parts = <String>[];
    for (final t in ticketTypes) {
      final n = counts[t['key']] ?? 0;
      if (n > 0) parts.add('$n ${t['label']}');
    }
    return parts.isEmpty ? 'No tickets selected' : parts.join(', ');
  }

  String _weekdayLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _confirmAndPay() async {
    if (_schedule == null) return;
    setState(() => _confirming = true);
    try {
      final bookingId = await _bookingService.createPendingBooking(
        scheduleId: _schedule!.scheduleId,
        ferryId: defaultFerryId,
        ticketTypes: ticketTypes,
        counts: counts,
        fare: fare,
      );

      var payableFare = fare;
      String? freeTicketReference;

      if (_selectedVoucher != null) {
        final result = await _rewardService.applyVoucher(
          redemptionId: _selectedVoucher!.redemptionId,
          bookingId: bookingId,
        );
        payableFare = result.newTotal;
        freeTicketReference = result.reference;
      }

      if (!mounted) return;
      setState(() => _confirming = false);

      if (payableFare <= 0) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => QrTicketPage(
              initialData: QrTicketData(
                reference: freeTicketReference!,
                route: direction,
                date: '${_weekdayLabel(selectedDate)}, ${selectedDate.day}/${selectedDate.month}',
                time: selectedTime,
                ticketSummary: ticketSummary,
                fare: 0,
              ),
            ),
          ),
              (route) => route.isFirst,
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            bookingId: bookingId,
            route: direction,
            date: '${_weekdayLabel(selectedDate)}, ${selectedDate.day}/${selectedDate.month}',
            time: selectedTime,
            ticketSummary: ticketSummary,
            fare: payableFare,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Booking & Payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLabel('Direction'),
          _buildDirectionToggle(),
          const SizedBox(height: 20),
          _buildLabel('Date (bookings open up to 7 days ahead)'),
          _buildDatePicker(),
          const SizedBox(height: 20),
          _buildLabel('Time Slot'),
          _buildTimeSlotPicker(),
          const SizedBox(height: 20),
          _buildLabel('Ticket Types'),
          ...ticketTypes.map(_buildTicketRow),
          const SizedBox(height: 20),
          _buildLabel('Crowd Density — This Sailing'),
          if (_slotError != null)
            Text(_slotError!, style: const TextStyle(color: alert, fontSize: 12))
          else if (_loadingSlot)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_schedule == null)
              const Text(
                'Pick a sailing above to see crowd levels.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              )
            else ...[
                ...ticketTypes.map(_buildCrowdBar),
                const SizedBox(height: 8),
                _buildTotalCrowdBar(),
              ],
          const SizedBox(height: 20),
          _buildLabel('Voucher'),
          _buildVoucherSection(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Fare', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('RM ${displayFare.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                if (_selectedVoucher != null) ...[
                  const SizedBox(height: 4),
                  Text('Voucher applied: ${_selectedVoucher!.title}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (fare == 0 || _loadingSlot || _confirming || _schedule == null)
                  ? null
                  : _confirmAndPay,
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _confirming
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text('Confirm & Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionToggle() {
    const options = ['Georgetown Terminal → Butterworth', 'Butterworth → Georgetown Terminal'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: options.map((opt) {
          final selected = opt == direction;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => direction = opt);
                _loadSlot();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : navy,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
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
              _loadSlot();
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
                          fontSize: 10.5, color: selected ? Colors.white : navy, fontWeight: FontWeight.w600)),
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

  Widget _buildTimeSlotPicker() {
    if (_loadingSlot) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_availableSlots.isEmpty) {
      return const Text(
        'No sailings open for booking on this day yet.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _availableSlots.map((slot) {
        final label = slot.time.substring(0, 5);
        final selected = slot.scheduleId == _schedule?.scheduleId;
        final isFull = _slotCrowdLevels[slot.scheduleId] == 'Full';

        return GestureDetector(
          onTap: isFull ? null : () => _selectSlot(slot),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isFull ? Colors.grey.shade300 : (selected ? teal : ice),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isFull ? Colors.grey.shade600 : (selected ? Colors.white : navy),
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                if (isFull)
                  Text(
                    'Full',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVoucherSection() {
    if (_loadingVouchers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_vouchers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No vouchers yet.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            TextButton(onPressed: _openRewards, child: const Text('Redeem a reward')),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._vouchers.map(_buildVoucherTile),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _openRewards, child: const Text('Redeem another reward')),
        ),
      ],
    );
  }
  Widget _buildVoucherTile(Voucher v) {
    final selected = v.redemptionId == _selectedVoucher?.redemptionId;
    final effect = v.isFree
        ? 'Whole booking free'
        : '− RM ${(v.discountAmount ?? 0).toStringAsFixed(2)} off';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedVoucher = selected ? null : v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? teal : ice,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                v.isFree ? Icons.confirmation_number : Icons.local_offer,
                size: 20,
                color: selected ? Colors.white : navy,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      style: TextStyle(
                        color: selected ? Colors.white : navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effect,
                      style: TextStyle(
                        color: selected ? Colors.white70 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Applied',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.close, size: 16, color: Colors.white),
                  ],
                )
              else
                const Text(
                  'Apply',
                  style: TextStyle(
                    color: teal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(Map<String, dynamic> t) {
    final key = t['key'] as String;
    final count = counts[key] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(t['icon'] as IconData, color: navy, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['label'] as String,
                    style: const TextStyle(color: navy, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('RM ${(t['price'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            onPressed: count > 0 ? () => setState(() => counts[key] = count - 1) : null,
            icon: const Icon(Icons.remove_circle_outline, color: navy),
          ),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          IconButton(
            onPressed: () => setState(() => counts[key] = count + 1),
            icon: const Icon(Icons.add_circle_outline, color: navy),
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdBar(Map<String, dynamic> t) {
    final key = t['key'] as String;
    final capacity = _ferry?.capacityFor(key) ?? 0;
    final baseBooked = _booked[key] ?? 0;
    final booked = baseBooked + (counts[key] ?? 0);
    final ratio = capacity == 0 ? 0.0 : (booked / capacity).clamp(0.0, 1.0);
    final color = ratio >= 0.85 ? alert : teal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['label'] as String, style: const TextStyle(fontSize: 12, color: navy, fontWeight: FontWeight.w600)),
              Text('$booked / $capacity', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: ice,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCrowdBar() {
    int totalCapacity = 0;
    int totalBooked = 0;
    for (final t in ticketTypes) {
      final key = t['key'] as String;
      totalCapacity += _ferry?.capacityFor(key) ?? 0;
      totalBooked += (_booked[key] ?? 0) + (counts[key] ?? 0);
    }
    final ratio = totalCapacity == 0 ? 0.0 : (totalBooked / totalCapacity).clamp(0.0, 1.0);

    String level;
    Color levelColor;
    int filledSegments;
    if (ratio < 0.4) {
      level = 'Low';
      levelColor = levelGreen;
      filledSegments = 1;
    } else if (ratio < 0.75) {
      level = 'Moderate';
      levelColor = levelAmber;
      filledSegments = 2;
    } else {
      level = 'High';
      levelColor = levelRed;
      filledSegments = 3;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Sailing Capacity',
                  style: TextStyle(fontSize: 12.5, color: navy, fontWeight: FontWeight.bold)),
              Text('$totalBooked / $totalCapacity',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(3, (i) {
              final filled = i < filledSegments;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  height: 9,
                  decoration: BoxDecoration(
                    color: filled ? levelColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(level, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: levelColor)),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navy)),
    );
  }
}