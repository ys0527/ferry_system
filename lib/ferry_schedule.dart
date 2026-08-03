import 'package:flutter/material.dart';
import 'booking_payment.dart';

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

  String selectedDestination = 'Butterworth';

  late final List<DateTime> availableDates =
  List.generate(7, (i) => DateTime.now().add(Duration(days: i)));
  late DateTime selectedDate = availableDates.first;

  final List<Map<String, dynamic>> schedule = const [
    {'time': '07:50', 'status': 'On time'},
    {'time': '08:20', 'status': 'On time'},
    {'time': '08:50', 'status': 'Delayed 5 min'},
    {'time': '09:20', 'status': 'On time'},
    {'time': '09:50', 'status': 'On time'},
    {'time': '10:20', 'status': 'On time'},
  ];

  String get _direction => selectedDestination == 'Butterworth'
      ? 'Georgetown Terminal \u2192 Butterworth'
      : 'Butterworth \u2192 Georgetown Terminal';

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
        title: const Text('Ferry Schedule'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDestinationToggle(),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 16),
          const Text(
            'Tap a sailing to book it',
            style: TextStyle(fontSize: 11.5, color: Colors.black45, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          ...schedule.map(_buildScheduleRow),
          const SizedBox(height: 8),
          const Text(
            'Data source: Penang Port ferry timetable',
            style: TextStyle(fontSize: 11, color: Colors.black45, fontStyle: FontStyle.italic),
          ),
        ],
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
              onTap: () => setState(() => selectedDestination = dest),
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
                    fontSize: 11,
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

  Widget _buildScheduleRow(Map<String, dynamic> row) {
    final delayed = (row['status'] as String).contains('Delayed');
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingPaymentPage(
              initialDirection: _direction,
              initialDate: selectedDate,
              initialTime: row['time'] as String,
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
          child: Row(
            children: [
              Text(row['time'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navy)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('To $selectedDestination',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: delayed ? alert : teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  row['status'] as String,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: navy, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
