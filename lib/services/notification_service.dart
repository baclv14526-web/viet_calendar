import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/calendar_event.dart';

const int _androidQ = 29;
const int _androidS = 31;
const int _androidT = 33;

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _sdkVersion = 0;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      _sdkVersion = info.version.sdkInt;
      debugPrint('[Notif] Android SDK: $_sdkVersion');
    }

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTapped,
      onDidReceiveBackgroundNotificationResponse: _onBgTapped,
    );

    await _createChannels();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (ap == null) return;

    // Channel sự kiện — high importance, âm thanh + rung + lock screen
    await ap.createNotificationChannel(const AndroidNotificationChannel(
      'event_channel',
      'Nhắc nhở sự kiện',
      description: 'Thông báo nhắc nhở các sự kiện trong lịch',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF1565C0),
    ));

    // Channel ngày lễ
    await ap.createNotificationChannel(const AndroidNotificationChannel(
      'holiday_channel',
      'Ngày lễ & Sự kiện đặc biệt',
      description: 'Thông báo về các ngày lễ và sự kiện đặc biệt',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    ));
  }

  static void _onTapped(NotificationResponse r) =>
      debugPrint('[Notif] Tapped: ${r.payload}');

  @pragma('vm:entry-point')
  static void _onBgTapped(NotificationResponse r) =>
      debugPrint('[Notif] BG tapped: ${r.payload}');

  // ─── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      if (_sdkVersion < _androidT) return true; // API < 33 tự động granted
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await ap?.requestNotificationsPermission() ?? true;
    }
    final ip = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ip?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
  }

  // ─── Schedule ──────────────────────────────────────────────────────────────

  Future<void> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return;

    final notifTime = _calcNotifTime(event);
    if (notifTime == null) {
      debugPrint('[Notif] ${event.title}: không tính được giờ thông báo');
      return;
    }
    if (notifTime.isBefore(DateTime.now())) {
      debugPrint('[Notif] ${event.title}: thời gian thông báo đã qua ($notifTime)');
      return;
    }

    debugPrint('[Notif] Schedule "${event.title}" lúc $notifTime');

    final tzTime = tz.TZDateTime.from(notifTime, tz.local);
    final isHoliday = event.type == EventType.holiday ||
        event.type == EventType.lunarHoliday;

    final android = AndroidNotificationDetails(
      isHoliday ? 'holiday_channel' : 'event_channel',
      isHoliday ? 'Ngày lễ & Sự kiện đặc biệt' : 'Nhắc nhở sự kiện',
      channelDescription: isHoliday
          ? 'Thông báo về các ngày lễ và sự kiện đặc biệt'
          : 'Thông báo nhắc nhở các sự kiện trong lịch',
      importance: isHoliday ? Importance.defaultImportance : Importance.high,
      priority: isHoliday ? Priority.defaultPriority : Priority.high,
      // LOCK SCREEN: hiển thị đầy đủ nội dung trên màn hình khóa
      visibility: NotificationVisibility.public,
      color: event.color,
      // BigText style để hiện đủ nội dung
      styleInformation: BigTextStyleInformation(
        _buildBody(event),
        contentTitle: event.title,
        summaryText: 'Lịch Việt',
        htmlFormatBigText: false,
      ),
      category: AndroidNotificationCategory.reminder,
      // fullScreenIntent: bật chuông + hiển thị kể cả khi màn hình tắt
      fullScreenIntent: !isHoliday && _sdkVersion >= _androidQ,
      // Âm thanh + rung
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // Không auto-cancel để user không bỏ lỡ
      autoCancel: true,
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final scheduleMode = await _getScheduleMode();

    // FIX: ID phải dương — dùng abs() + tránh trùng
    final notifId = event.id.hashCode.abs() % 2147483647;

    await _plugin.zonedSchedule(
      notifId,
      event.title,
      _buildBody(event),
      tzTime,
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: event.id,
    );

    debugPrint('[Notif] ✅ Scheduled id=$notifId cho "${event.title}" lúc $tzTime');
  }

  Future<AndroidScheduleMode> _getScheduleMode() async {
    if (_sdkVersion >= _androidS) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await ap?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  // ─── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelEventNotification(String eventId) async {
    final id = eventId.hashCode.abs() % 2147483647;
    await _plugin.cancel(id);
    debugPrint('[Notif] Cancelled id=$id');
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // ─── Instant (test) ────────────────────────────────────────────────────────

  Future<void> showInstantNotification({
    required String title,
    required String body,
    Color color = const Color(0xFF2196F3),
  }) async {
    final android = AndroidNotificationDetails(
      'event_channel',
      'Nhắc nhở sự kiện',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      color: color,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: _sdkVersion >= _androidQ,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  // ─── Time calculation ──────────────────────────────────────────────────────

  /// FIX: Tính đúng giờ thông báo cho mọi loại sự kiện
  DateTime? _calcNotifTime(CalendarEvent event) {
    final d = event.date;
    final minsBefore = event.notificationMinutesBefore ?? 30;

    if (event.isAllDay) {
      // Sự kiện cả ngày → thông báo lúc 8:00 sáng ngày đó
      // Nếu minsBefore >= 1440 (1 ngày) → thông báo 8:00 sáng hôm trước
      final notifDay = minsBefore >= 1440
          ? DateTime(d.year, d.month, d.day - 1, 8, 0)
          : DateTime(d.year, d.month, d.day, 8, 0);
      return notifDay;
    }

    if (event.startTime != null) {
      // Sự kiện có giờ → thông báo trước N phút
      final start = DateTime(
        d.year, d.month, d.day,
        event.startTime!.hour,
        event.startTime!.minute,
      );
      return start.subtract(Duration(minutes: minsBefore));
    }

    // Sự kiện không có giờ, không phải allDay
    // → thông báo lúc 8:00 sáng ngày đó
    return DateTime(d.year, d.month, d.day, 8, 0);
  }

  String _buildBody(CalendarEvent event) {
    if (event.description != null && event.description!.isNotEmpty) {
      return event.description!;
    }
    if (event.isAllDay) return 'Sự kiện cả ngày';
    if (event.startTime != null) {
      final h = event.startTime!.hour.toString().padLeft(2, '0');
      final m = event.startTime!.minute.toString().padLeft(2, '0');
      final mins = event.notificationMinutesBefore ?? 30;
      return 'Bắt đầu lúc $h:$m${mins > 0 ? ' (còn $mins phút)' : ''}';
    }
    return 'Nhắc nhở sự kiện';
  }

  // ─── Debug ─────────────────────────────────────────────────────────────────

  /// Liệt kê các thông báo đã lên lịch (debug)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }
}
