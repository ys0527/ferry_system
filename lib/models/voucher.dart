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

  double previewFare(double fare) {
    if (fare <= 0) return 0;
    return (fare - (discountAmount ?? 0)).clamp(2.0, fare);
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
