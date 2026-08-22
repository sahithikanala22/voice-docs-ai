import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules local reminder notifications for calendar/history entries —
/// entirely on-device, no Google account or backend involved. A thin
/// singleton (rather than a per-widget object) since there is exactly one
/// OS-level notification channel for the whole app to manage.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _reminderChannelId = 'entry_reminders';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (_) {
      // Falls back to UTC if the platform can't report its timezone —
      // reminders still fire, just without DST-aware local-time math.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidSettings));

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            'Entry reminders',
            description: 'Reminders you set on calendar and history entries',
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  /// Prompts for the Android 13+ notification runtime permission. Returns
  /// false if the user denies it, so callers can revert whatever toggle they
  /// were about to turn on rather than silently scheduling a reminder that
  /// will never show.
  Future<bool> requestPermission() async {
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;
    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Schedules a reminder at [scheduledDate]. [id] must be stable for a
  /// given entry so a later call with the same id replaces (rather than
  /// duplicates) any previously scheduled reminder for it. Falls back to
  /// inexact delivery when the device hasn't granted exact-alarm access,
  /// rather than failing the whole reminder outright.
  ///
  /// [matchDateTimeComponents] turns this into a repeating reminder: pass
  /// [DateTimeComponents.time] to repeat daily at [scheduledDate]'s
  /// time-of-day, or [DateTimeComponents.dayOfWeekAndTime] to repeat weekly
  /// on its weekday+time — used for recurring tasks. Leave null for a
  /// one-shot reminder.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidImpl?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Entry reminders',
          channelDescription: 'Reminders you set on calendar and history entries',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode:
          canExact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Notification ids are 32-bit ints on Android; entry ids are strings
/// (timestamp-based). Masking the hash to a positive 31-bit value gives a
/// stable, collision-safe-enough id for the bounded number of reminders a
/// personal journal realistically schedules at once.
int reminderNotificationId(String entryId) => entryId.hashCode & 0x7fffffff;
