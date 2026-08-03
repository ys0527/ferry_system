import 'package:flutter/material.dart';
import 'payment.dart';

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

  late String direction = widget.initialDirection ?? 'Georgetown Terminal \u2192 Butterworth';
  late final List<DateTime> availableDates =
  List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  late DateTime selectedDate = widget.initialDate ?? availableDates.first;

  late String selectedTime = widget.initialTime ?? '08:20';
  final List<String> timeSlots = const ['07:50', '08:20', '08:50', '09:20', '09:50'];

  final List<Map<String, dynamic>> ticketTypes = const [
    {'key': 'adult', 'label': 'Adult', 'icon': Icons.person, 'price': 1.20, 'capacity': 150, 'baseBooked': 95},
    {'key': 'child', 'label': 'Child', 'icon': Icons.child_care, 'price': 0.60, 'capacity': 50, 'baseBooked': 20},
    {'key': 'bicycle', 'label': 'Bicycle', 'icon': Icons.pedal_bike, 'price': 1.00, 'capacity': 25, 'baseBooked': 9},
    {'key': 'motorcycle', 'label': 'Motorcycle', 'icon': Icons.two_wheeler, 'price': 3.00, 'capacity': 25, 'baseBooked': 14},
  ];

  final Map<String, int> counts = {'adult': 1, 'child': 0, 'bicycle': 0, 'motorcycle': 0};

  double get fare {
    double total = 0;
    for (final t in ticketTypes) {
      total += (t['price'] as double) * (counts[t['key']] ?? 0);
    }
    return total;
  }

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
          _buildLabel('Crowd Density \u2014 This Sailing'),
          ...ticketTypes.map(_buildCrowdBar),
          const SizedBox(height: 8),
          _buildTotalCrowdBar(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Fare', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('RM ${fare.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: fare == 0
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentPage(
                      route: direction,
                      date: '${_weekdayLabel(selectedDate)}, ${selectedDate.day}/${selectedDate.month}',
                      time: selectedTime,
                      ticketSummary: ticketSummary,
                      fare: fare,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Confirm & Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionToggle() {
    const options = ['Georgetown Terminal \u2192 Butterworth', 'Butterworth \u2192 Georgetown Terminal'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: options.map((opt) {
          final selected = opt == direction;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => direction = opt),
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
            onTap: () => setState(() => selectedDate = date),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: timeSlots.map((time) {
        final selected = time == selectedTime;
        return GestureDetector(
          onTap: () => setState(() => selectedTime = time),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? teal : ice,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: selected ? Colors.white : navy,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
        );
      }).toList(),
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
    final capacity = t['capacity'] as int;
    final baseBooked = t['baseBooked'] as int;
    final booked = baseBooked + (counts[key] ?? 0);
    final ratio = (booked / capacity).clamp(0.0, 1.0);
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
      totalCapacity += t['capacity'] as int;
      totalBooked += (t['baseBooked'] as int) + (counts[t['key']] ?? 0);
    }
    final ratio = (totalBooked / totalCapacity).clamp(0.0, 1.0);

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
