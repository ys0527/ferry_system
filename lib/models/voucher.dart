class Voucher {
  const Voucher({
    required this.redemptionId,
    required this.title,
    required this.rewardType,
    this.discountAmount,
  });

  final String redemptionId;
  final String title;
  final String rewardType;
  final double? discountAmount;

  bool get isFree => rewardType == 'Free Ticket';

  double previewFare(double fare) {
    if (isFree) return 0;
    final discounted = fare - (discountAmount ?? 0);
    return discounted.clamp(0, fare);
  }

  factory Voucher.fromRows({
    required Map<String, dynamic> redemption,
    required Map<String, dynamic> reward,
  }) {
    return Voucher(
      redemptionId: redemption['redemption_id'] as String,
      title: reward['title'] as String,
      rewardType: reward['reward_type'] as String,
      discountAmount: (reward['discount_amount'] as num?)?.toDouble(),
    );
  }
}
