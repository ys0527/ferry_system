enum ReviewWindowStatus { notYetOpen, open, expired }

class ReviewWindow {
  ReviewWindow(this.tripEndTime);

  final DateTime tripEndTime;

  static const Duration _delayBeforeOpening = Duration(minutes: 1);
  static const Duration _windowLength = Duration(hours: 24);

  DateTime get opensAt => tripEndTime.add(_delayBeforeOpening);
  DateTime get closesAt => opensAt.add(_windowLength);

  ReviewWindowStatus statusAt(DateTime now) {
    if (now.isBefore(opensAt)) return ReviewWindowStatus.notYetOpen;
    if (now.isAfter(closesAt)) return ReviewWindowStatus.expired;
    return ReviewWindowStatus.open;
  }

  ReviewWindowStatus get status => statusAt(DateTime.now());

  Duration get timeUntilOpen => opensAt.difference(DateTime.now());

  Duration get timeUntilClose => closesAt.difference(DateTime.now());
}
