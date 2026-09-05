import '../constants.dart';
import '../supabase_config.dart';
import 'current_user_service.dart';
import 'notification_service.dart';
import 'reward_service.dart';

class PaymentIntentInfo {
  const PaymentIntentInfo({
    required this.clientSecret,
    required this.paymentIntentId,
    required this.customerId,
    required this.amount,
  });
  final String clientSecret;
  final String paymentIntentId;
  final String customerId;
  final double amount;
}

class PaymentService {
  final _client = supabase;
  final _rewardService = RewardService();

  Future<PaymentIntentInfo> createPaymentIntent({
    required String bookingId,
  }) async {
    final userId = await currentUserId();
    final response = await _client.functions.invoke(
      'create-payment-intent',
      body: {'booking_id': bookingId, 'user_id': userId},
    );

    final data = response.data as Map<String, dynamic>;
    return PaymentIntentInfo(
      clientSecret: data['clientSecret'] as String,
      paymentIntentId: data['paymentIntentId'] as String,
      customerId: data['customerId'] as String,
      amount: (data['amount'] as num) / 100,
    );
  }

  Future<String> confirmBookingPaid({
    required String bookingId,
    required String paymentIntentId,
    required String customerId,
    required double amount,
  }) async {
    final bookingRow = await _client
        .from('booking')
        .select('reference, user_id')
        .eq('booking_id', bookingId)
        .single();
    final reference = bookingRow['reference'] as String;
    final userId = bookingRow['user_id'] as String;

    await _client
        .from('booking')
        .update({'status': 'Confirmed', 'qr_code': reference})
        .eq('booking_id', bookingId);

    await _client.from('payment').insert({
      'method': 'Card',
      'total_amount': amount,
      'status': 'Succeeded',
      'stripe_payment_intent_id': paymentIntentId,
      'stripe_user_id': customerId,
      'booking_id': bookingId,
    });

    await _awardPoints(userId, rewardPointsFor(amount));
    await _finalizeVoucher(bookingId);

    try {
      final notificationService = NotificationService();
      await notificationService.notifyBookingConfirmed(userId: userId, reference: reference);
      final points = rewardPointsFor(amount);
      if (points > 0) {
        await notificationService.notifyPointsEarned(userId: userId, points: points);
      }
    } catch (_) {

    }

    return reference;
  }
  
  Future<void> _finalizeVoucher(String bookingId) async {
    try {
      await _rewardService.finalizeVoucher(bookingId);
    } catch (e) {
      return;
    }
  }

  Future<void> _awardPoints(String userId, int points) async {
    if (points <= 0) return;
    try {
      final row = await _client
          .from('users')
          .select('reward_point')
          .eq('user_id', userId)
          .single();
      final current = (row['reward_point'] as num?)?.toInt() ?? 0;
      await _client
          .from('users')
          .update({'reward_point': current + points})
          .eq('user_id', userId);
    } catch (e) {
      return;
    }
  }
}
