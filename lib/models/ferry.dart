class Ferry {
  const Ferry({
    required this.ferryId,
    required this.ferryNum,
    required this.adultCap,
    required this.childCap,
    required this.bicycleCap,
    required this.motorcycleCap,
    required this.isActive,
  });

  final String ferryId;
  final String ferryNum;
  final int adultCap;
  final int childCap;
  final int bicycleCap;
  final int motorcycleCap;
  final bool isActive;

  int capacityFor(String ticketType) {
    switch (ticketType) {
      case 'adult':
        return adultCap;
      case 'child':
        return childCap;
      case 'bicycle':
        return bicycleCap;
      case 'motorcycle':
        return motorcycleCap;
      default:
        return 0;
    }
  }

  factory Ferry.fromMap(Map<String, dynamic> map) {
    return Ferry(
      ferryId: map['ferry_id'] as String,
      ferryNum: map['ferry_num'] as String,
      adultCap: map['adult_cap'] as int,
      childCap: map['child_cap'] as int,
      bicycleCap: map['bicycle_cap'] as int,
      motorcycleCap: map['motorcycle_cap'] as int,
      isActive: map['is_active'] as bool,
    );
  }
}
