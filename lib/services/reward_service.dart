import '../models/voucher.dart';
import '../supabase_config.dart';

class VoucherApplication {
  const VoucherApplication({required this.newTotal, required this.reference});

  final double newTotal;
  final String reference;
}

class RewardService {
  final _client = supabase;

  Future<List<Voucher>> fetchAvailableVouchers(String userId) async {
    final redemptionRows = List<Map<String, dynamic>>.from(
      await _client
          .from('redemption')
          .select('redemption_id, reward_id')
          .eq('user_id', userId)
          .eq('type', 'Redeemed')
          .order('created_at', ascending: false),
    );
    if (redemptionRows.isEmpty) return const [];

    final rewardIds = redemptionRows
        .map((row) => row['reward_id'] as String)
        .toSet()
        .toList();

    final rewardRows = List<Map<String, dynamic>>.from(
      await _client
          .from('reward')
          .select('reward_id, title, reward_type, discount_amount')
          .inFilter('reward_id', rewardIds),
    );
    final rewardsById = {
      for (final row in rewardRows) row['reward_id'] as String: row,
    };

    return redemptionRows
        .where((row) => rewardsById.containsKey(row['reward_id']))
        .map(
          (row) => Voucher.fromRows(
            redemption: row,
            reward: rewardsById[row['reward_id']]!,
          ),
        )
        .toList();
  }

  Future<VoucherApplication> applyVoucher({
    required String redemptionId,
    required String bookingId,
  }) async {
    final response = await _client.rpc(
      'apply_voucher',
      params: {'p_redemption_id': redemptionId, 'p_booking_id': bookingId},
    );

    final row = (response as List).first as Map<String, dynamic>;
    return VoucherApplication(
      newTotal: (row['new_total'] as num).toDouble(),
      reference: row['reference'] as String,
    );
  }

  Future<void> finalizeVoucher(String bookingId) async {
    await _client.rpc('finalize_voucher', params: {'p_booking_id': bookingId});
  }

  Future<void> releaseVoucher(String bookingId) async {
    await _client.rpc('release_voucher', params: {'p_booking_id': bookingId});
  }
}
