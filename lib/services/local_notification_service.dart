import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class LocalNotificationService {
  LocalNotificationService._internal();
  static final LocalNotificationService instance = LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // A plain counter instead of a time-based id -- two notifications fired
  // back-to-back (e.g. Booking Confirmed then Reward Points Earned) can
  // land within the same second, which previously gave them the same id
  // and made the second one silently overwrite the first in the tray.
  int _nextId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'ferrylink_notifications',
    'FerryLink Notifications',
    description: 'Booking, rewards, weather, and ferry delay alerts',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    // Required on Android 13+ (API 33+) -- without this, notifications are
    // silently suppressed even though the code runs without error.
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> show({required String title, String? body}) async {
    if (!_initialized) await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    // A unique id per call keeps each notification distinct instead of
    // overwriting the previous one in the tray.
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}