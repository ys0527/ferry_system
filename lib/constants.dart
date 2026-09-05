const ticketTypeLabels = {
  'adult': 'Adult',
  'child': 'Child',
  'bicycle': 'Bicycle',
  'motorcycle': 'Motorcycle',
};

final ticketTypeKeys = {
  for (final entry in ticketTypeLabels.entries) entry.value: entry.key,
};

const ticketTypePrices = {
  'adult': 3.50,
  'child': 3.00,
  'bicycle': 3.00,
  'motorcycle': 4.00,
};

int rewardPointsFor(double fare) => (fare * 6).round();
