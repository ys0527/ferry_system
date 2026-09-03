class ScheduleSlot {
  const ScheduleSlot({
    required this.scheduleId,
    required this.departure,
    required this.destination,
    required this.date,
    required this.time,
    required this.status,
    required this.delayTime,
    required this.ferryId,
  });

  final String scheduleId;
  final String departure;
  final String destination;
  final String date;
  final String time;
  final String status;
  final int delayTime;
  final String ferryId;

  factory ScheduleSlot.fromMap(Map<String, dynamic> map) {
    return ScheduleSlot(
      scheduleId: map['schedule_id'] as String,
      departure: map['departure'] as String,
      destination: map['destination'] as String,
      date: map['date'] as String,
      time: map['time'] as String,
      status: map['status'] as String,
      delayTime: (map['delay_time'] as num?)?.toInt() ?? 0,
      ferryId: map['ferry_id'] as String,
    );
  }
}
