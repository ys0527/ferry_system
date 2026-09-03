const String demoUserId = 'U0001';
const String defaultFerryId = 'F0001';

const ticketTypeLabels = {
  'adult': 'Adult',
  'child': 'Child',
  'bicycle': 'Bicycle',
  'motorcycle': 'Motorcycle',
};

final ticketTypeKeys = {
  for (final entry in ticketTypeLabels.entries) entry.value: entry.key,
};

int rewardPointsFor(double fare) => (fare * 6).round();
