import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking_payment.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const deepBlue = Color(0xFF2458A8);
  static const ice = Color(0xFFEAF4F8);

  int _points = 0;
  bool _isLoading = true;
  String? _redeemingRewardId;
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _redeemedVouchers = [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) throw Exception('Please log in first');

      final userData = await Supabase.instance.client
          .from('users')
          .select('user_id, reward_point')
          .eq('auth_id', authUser.id)
          .maybeSingle();
      if (userData == null) throw Exception('User profile was not found');

      final userId = userData['user_id'] as String;
      final rewardRows = await Supabase.instance.client
          .from('reward')
          .select(
        'reward_id, title, point, description, reward_type, '
            'discount_amount, is_active',
      )
          .order('point');

      final redemptionRows = await Supabase.instance.client
          .from('redemption')
          .select(
        'redemption_id, reward_id, type, points, description, created_at',
      )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final rewards = List<Map<String, dynamic>>.from(rewardRows);
      final redemptions = List<Map<String, dynamic>>.from(redemptionRows);
      final rewardsById = <String, Map<String, dynamic>>{
        for (final reward in rewards)
          if (reward['reward_id'] is String)
            reward['reward_id'] as String: reward,
      };

      final hiddenRewardIds = <String>{};
      final redeemedVouchers = <Map<String, dynamic>>[];
      for (final row in redemptions) {
        final rewardId = row['reward_id'];
        final type = row['type'];
        if (rewardId is String &&
            (type == 'Redeemed' || type == 'Expired')) {
          hiddenRewardIds.add(rewardId);

          final reward = rewardsById[rewardId];
          redeemedVouchers.add({
            ...row,
            'title': reward?['title'] ??
                row['description'] ??
                'Reward Voucher',
            'reward_description': reward?['description'],
            'reward_type': reward?['reward_type'],
          });
        }
      }

      final availableRewards = rewards
          .where(
            (reward) =>
        reward['is_active'] == true &&
            !hiddenRewardIds.contains(reward['reward_id']),
      )
          .toList();

      if (!mounted) return;
      setState(() {
        _points = userData['reward_point'] as int? ?? 0;
        _rewards = availableRewards;
        _redeemedVouchers = redeemedVouchers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load rewards: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _redeemReward(Map<String, dynamic> reward) async {
    final rewardId = reward['reward_id'] as String;
    final title = reward['title'] as String;
    final cost = reward['point'] as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redeem Reward'),
        content: Text('Use $cost points to redeem $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _redeemingRewardId = rewardId);

    try {
      await Supabase.instance.client.rpc(
        'redeem_reward',
        params: {'p_reward_id': rewardId},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title redeemed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadRewards();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _redeemingRewardId = null);
    }
  }

  IconData _iconFor(Map<String, dynamic> reward) {
    return reward['reward_type'] == 'Free Ticket'
        ? Icons.confirmation_number
        : Icons.local_offer;
  }

  String _descriptionFor(Map<String, dynamic> reward) {
    final description = reward['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) return description;

    if (reward['reward_type'] == 'Fixed Discount') {
      final amount = reward['discount_amount'];
      return amount == null ? 'Fare discount' : 'RM $amount fare discount';
    }
    return 'Free ferry ticket';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Date unavailable';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Rewards'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRewards,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [navy, deepBlue],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Points',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_points pts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildRedeemedVouchersPanel(),
            const SizedBox(height: 20),
            const Text(
              'Redeem Rewards',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: navy,
              ),
            ),
            const SizedBox(height: 12),
            if (_rewards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No rewards available')),
              )
            else
              ..._rewards.map(_buildRewardTile),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemedVouchersPanel() {
    return Card(
      elevation: 0,
      color: ice,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: navy.withOpacity(0.18)),
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          child: Icon(Icons.wallet_giftcard),
        ),
        title: const Text(
          'My Redeemed Vouchers',
          style: TextStyle(fontWeight: FontWeight.bold, color: navy),
        ),
        subtitle: Text('${_redeemedVouchers.length} voucher(s)'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_redeemedVouchers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('You have not redeemed any vouchers yet.'),
            )
          else
            ..._redeemedVouchers.map(_buildRedeemedVoucherTile),
        ],
      ),
    );
  }

  Widget _buildRedeemedVoucherTile(Map<String, dynamic> voucher) {
    final status = voucher['type']?.toString() ?? 'Redeemed';
    final isExpired = status == 'Expired';
    final points = voucher['points'] as int? ?? 0;
    final redemptionId = voucher['redemption_id']?.toString() ?? '-';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  voucher['title']?.toString() ?? 'Reward Voucher',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.red.withOpacity(0.12)
                      : Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isExpired ? Colors.red : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Voucher ID: $redemptionId'),
          Text('Points used: $points pts'),
          Text('Redeemed on: ${_formatDate(voucher['created_at'])}'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: isExpired
                  ? null
                  : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingPaymentPage(),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Use'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardTile(Map<String, dynamic> reward) {
    final cost = reward['point'] as int;
    final rewardId = reward['reward_id'] as String;
    final affordable = _points >= cost;
    final isRedeeming = _redeemingRewardId == rewardId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: ice,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: affordable ? teal : Colors.grey,
          child: Icon(_iconFor(reward), color: Colors.white),
        ),
        title: Text(
          reward['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${_descriptionFor(reward)}\n$cost pts'),
        isThreeLine: true,
        trailing: FilledButton(
          onPressed: affordable && !isRedeeming
              ? () => _redeemReward(reward)
              : null,
          child: isRedeeming
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Redeem'),
        ),
      ),
    );
  }
}
