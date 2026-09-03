import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';

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
  final _client = Supabase.instance.client;

  Future<PaymentIntentInfo> createPaymentIntent({
    required String bookingId,
  }) async {
    final response = await _client.functions.invoke(
      'create-payment-intent',
      body: {'booking_id': bookingId, 'user_id': demoUserId},
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
        .select('reference')
        .eq('booking_id', bookingId)
        .single();
    final reference = bookingRow['reference'] as String;

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

    await _awardPoints(rewardPointsFor(amount));

    return reference;
  }

  Future<void> _awardPoints(int points) async {
    if (points <= 0) return;
    try {
      final row = await _client
          .from('users')
          .select('reward_point')
          .eq('user_id', demoUserId)
          .single();
      final current = (row['reward_point'] as num?)?.toInt() ?? 0;
      await _client
          .from('users')
          .update({'reward_point': current + points})
          .eq('user_id', demoUserId);
    } catch (e) {
      return;
    }
  }
}
