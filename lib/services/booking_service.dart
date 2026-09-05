import 'dart:math';
import '../constants.dart';
import '../models/booking_detail.dart';
import '../models/booking_history_entry.dart';
import '../models/qr_ticket_data.dart';
import '../supabase_config.dart';
import 'current_user_service.dart';
import 'reward_service.dart';
import 'schedule_service.dart';

String _generateReference(DateTime now) {
  const alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  final random = Random.secure();
  final suffix = List.generate(
    5,
        (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
  final yy = (now.year % 100).toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return 'FL$yy$mm$dd$suffix';
}

class BookingCapacityException implements Exception {
  BookingCapacityException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BookingService {
  final _client = supabase;
  final _scheduleService = ScheduleService();
  final _rewardService = RewardService();

  static const List<String> _pooledKeys = ['adult', 'child'];

  Future<String> createPendingBooking({
    required String scheduleId,
    required String ferryId,
    required List<Map<String, dynamic>> ticketTypes,
    required Map<String, int> counts,
    required double fare,
  }) async {
    final ferry = await _scheduleService.fetchFerry(ferryId);
    final booked = await _scheduleService.fetchBookedCounts(scheduleId);

    final pooledRequested = _pooledKeys.fold<int>(0, (sum, k) => sum + (counts[k] ?? 0));
    if (pooledRequested > 0) {
      final pooledCapacity = _pooledKeys.fold<int>(0, (sum, k) => sum + ferry.capacityFor(k));
      final pooledAlready = _pooledKeys.fold<int>(0, (sum, k) => sum + (booked[k] ?? 0));
      if (pooledAlready + pooledRequested > pooledCapacity) {
        throw BookingCapacityException(
          'Sold out: only ${pooledCapacity - pooledAlready} passenger seat(s) left on this sailing.',
        );
      }
    }

    for (final t in ticketTypes) {
      final key = t['key'] as String;
      if (_pooledKeys.contains(key)) continue;
      final requested = counts[key] ?? 0;
      if (requested == 0) continue;
      final capacity = ferry.capacityFor(key);
      final already = booked[key] ?? 0;
      if (already + requested > capacity) {
        throw BookingCapacityException(
          'Sold out for ${t['label']}: only ${capacity - already} seat(s) left on this sailing.',
        );
      }
    }

    final userId = await currentUserId();

    final bookingRow = await _client
        .from('booking')
        .insert({
      'reference': _generateReference(DateTime.now()),
      'status': 'Pending',
      'total': fare,
      'user_id': userId,
      'schedule_id': scheduleId,
    })
        .select()
        .single();
    final bookingId = bookingRow['booking_id'] as String;

    final ticketRows = <Map<String, dynamic>>[];
    for (final t in ticketTypes) {
      final key = t['key'] as String;
      final quantity = counts[key] ?? 0;
      if (quantity == 0) continue;
      final unitPrice = t['price'] as double;
      ticketRows.add({
        'type': ticketTypeLabels[key] ?? key,
        'quantity': quantity,
        'unit_price': unitPrice,
        'subtotal': unitPrice * quantity,
        'booking_id': bookingId,
      });
    }
    if (ticketRows.isNotEmpty) {
      await _client.from('ticket').insert(ticketRows);
    }

    return bookingId;
  }

  Future<void> cancelPendingBooking(String bookingId) async {
    try {
      await _rewardService.releaseVoucher(bookingId);
    } catch (e) {
    }
    await _client.from('ticket').delete().eq('booking_id', bookingId);
    await _client
        .from('booking')
        .delete()
        .eq('booking_id', bookingId)
        .eq('status', 'Pending');
  }

  Future<List<BookingHistoryEntry>> fetchBookingHistory(String userId) async {
    final rows = await _client
        .from('booking')
        .select(
      'booking_id, reference, total, schedule:schedule_id(departure, destination, date, time, ferry:ferry_id(ferry_num)), ticket(type, quantity)',
    )
        .eq('user_id', userId)
        .inFilter('status', ['Confirmed', 'Completed']);

    return rows.map(BookingHistoryEntry.fromMap).toList();
  }

  Future<BookingDetail> fetchBookingDetail(String bookingId) async {
    final row = await _client
        .from('booking')
        .select(
      'booking_id, reference, status, total, created_at, '
          'schedule:schedule_id(departure, destination, date, time, status, delay_time, ferry:ferry_id(ferry_num)), '
          'ticket(type, quantity, unit_price, subtotal), '
          'payment(method, total_amount, status, created_at, stripe_payment_intent_id)',
    )
        .eq('booking_id', bookingId)
        .single();

    final redemptionRows = List<Map<String, dynamic>>.from(
      await _client
          .from('redemption')
          .select('reward_id')
          .eq('booking_id', bookingId)
          .eq('type', 'Used')
          .limit(1),
    );

    double? discountAmount;
    String? voucherTitle;
    if (redemptionRows.isNotEmpty) {
      final rewardId = redemptionRows.first['reward_id'] as String?;
      if (rewardId != null) {
        final rewardRow = await _client
            .from('reward')
            .select('title, discount_amount')
            .eq('reward_id', rewardId)
            .maybeSingle();
        voucherTitle = rewardRow?['title'] as String?;
        discountAmount = (rewardRow?['discount_amount'] as num?)?.toDouble();
      }
    }

    return BookingDetail.fromMap(
      row,
      discountAmount: discountAmount,
      voucherTitle: voucherTitle,
    );
  }

  Future<QrTicketData?> fetchLatestConfirmedTicket(String userId) async {
    final row = await _client
        .from('booking')
        .select(
      'reference, qr_code, total, created_at, schedule:schedule_id(departure, destination, date, time), ticket(type, quantity)',
    )
        .eq('user_id', userId)
        .eq('status', 'Confirmed')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) return null;

    final schedule = row['schedule'] as Map<String, dynamic>;
    final tickets = (row['ticket'] as List).cast<Map<String, dynamic>>();

    final summaryParts = <String>[];
    for (final t in tickets) {
      final type = t['type'] as String;
      final qty = (t['quantity'] as num).toInt();
      summaryParts.add('$qty $type');
    }

    final timeStr = (schedule['time'] as String);

    return QrTicketData(
      reference: (row['reference'] ?? row['qr_code'] ?? '') as String,
      route: '${schedule['departure']} → ${schedule['destination']}',
      date: schedule['date'] as String,
      time: timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr,
      ticketSummary: summaryParts.isEmpty
          ? 'No tickets'
          : summaryParts.join(', '),
      fare: (row['total'] as num).toDouble(),
      sailingAt: DateTime.parse('${schedule['date']} $timeStr'),
    );
  }
}