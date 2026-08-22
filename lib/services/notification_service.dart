import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/calendar_event.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _sdkVersion = 0;

  // ─── Khởi tạo ──────────────────────────────────────────────────────────────

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

    // Tạo lại channel mỗi lần (xóa cũ để reset importance nếu đã bị hạ)
    await _recreateChannels();
    _initialized = true;
    debugPrint('[Notif] Initialized OK, SDK=$_sdkVersion');
  }

  Future<void> _recreateChannels() async {
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (ap == null) return;

    // Xóa channel cũ để tạo lại với đúng importance
    // (Android không cho update importance sau khi tạo)
    await ap.deleteNotificationChannel('event_channel');
    await ap.deleteNotificationChannel('holiday_channel');

    // Channel sự kiện: HIGH importance để hiện banner + âm thanh + màn hình khóa
    await ap.createNotificationChannel(const AndroidNotificationChannel(
      'event_channel',
      'Nhắc nhở sự kiện',
      description: 'Thông báo nhắc nhở các sự kiện trong lịch',
      importance: Importance.high, // HIGH = hiện banner, phát âm, rung
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF1565C0),
    ));

    // Channel ngày lễ: DEFAULT importance
    await ap.createNotificationChannel(const AndroidNotificationChannel(
      'holiday_channel',
      'Ngày lễ & Sự kiện đặc biệt',
      description: 'Thông báo về các ngày lễ và sự kiện đặc biệt',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    ));

    debugPrint('[Notif] Channels recreated');
  }

  static void _onTapped(NotificationResponse r) =>
      debugPrint('[Notif] Tapped: ${r.payload}');

  @pragma('vm:entry-point')
  static void _onBgTapped(NotificationResponse r) =>
      debugPrint('[Notif] BG tapped: ${r.payload}');

  // ─── Xin quyền đầy đủ ─────────────────────────────────────────────────────

  /// Xin tất cả quyền cần thiết để thông báo hoạt động.
  /// Trả về map kết quả để UI hiển thị hướng dẫn cho user.
  Future<Map<String, bool>> requestAllPermissions() async {
    final result = <String, bool>{};

    if (!Platform.isAndroid) {
      final ip = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ip?.requestPermissions(
            alert: true, badge: true, sound: true) ??
          true;
      result['notification'] = granted;
      return result;
    }

    // 1. POST_NOTIFICATIONS (Android 13+)
    if (_sdkVersion >= 33) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      result['notification'] =
          await ap?.requestNotificationsPermission() ?? false;
    } else {
      result['notification'] = true;
    }

    // 2. SCHEDULE_EXACT_ALARM (Android 12+)
    if (_sdkVersion >= 31) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await ap?.canScheduleExactNotifications() ?? false;
      result['exactAlarm'] = canExact;
      if (!canExact) {
        // Mở Settings để user bật thủ công
        await Permission.scheduleExactAlarm.request();
      }
    } else {
      result['exactAlarm'] = true;
    }

    // 3. IGNORE_BATTERY_OPTIMIZATIONS — quan trọng nhất!
    //    Không có cái này alarm bị Doze mode tắt trên mọi máy
    final batteryStatus =
        await Permission.ignoreBatteryOptimizations.status;
    result['battery'] = batteryStatus.isGranted;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
      // Đọc lại sau khi request
      result['battery'] =
          (await Permission.ignoreBatteryOptimizations.status).isGranted;
    }

    // 4. USE_FULL_SCREEN_INTENT (Android 14+)
    if (_sdkVersion >= 34) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      result['fullScreen'] =
          await ap?.canScheduleExactNotifications() ?? false;
    } else {
      result['fullScreen'] = true;
    }

    debugPrint('[Notif] Permissions: $result');
    return result;
  }

  // Compat method cho code cũ
  Future<bool> requestPermission() async {
    final results = await requestAllPermissions();
    return results.values.every((v) => v);
  }

  /// Kiểm tra trạng thái hiện tại (không request)
  Future<Map<String, bool>> checkPermissions() async {
    final result = <String, bool>{};
    if (!Platform.isAndroid) {
      result['notification'] = true;
      result['exactAlarm'] = true;
      result['battery'] = true;
      result['fullScreen'] = true;
      return result;
    }

    result['notification'] = _sdkVersion < 33
        ? true
        : (await Permission.notification.status).isGranted;

    if (_sdkVersion >= 31) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      result['exactAlarm'] =
          await ap?.canScheduleExactNotifications() ?? false;
    } else {
      result['exactAlarm'] = true;
    }

    result['battery'] =
        (await Permission.ignoreBatteryOptimizations.status).isGranted;
    result['fullScreen'] = true;

    return result;
  }

  // ─── Lên lịch thông báo ────────────────────────────────────────────────────

  Future<void> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return;

    final notifTime = _calcNotifTime(event);
    if (notifTime == null) {
      debugPrint('[Notif] Không tính được giờ: ${event.title}');
      return;
    }

    // Nếu thời gian đã qua → không schedule
    final now = DateTime.now();
    if (notifTime.isBefore(now)) {
      debugPrint(
          '[Notif] Đã qua: ${event.title} (notif=$notifTime, now=$now)');
      return;
    }

    debugPrint('[Notif] Scheduling "${event.title}" lúc $notifTime');

    final isHoliday = event.type == EventType.holiday ||
        event.type == EventType.lunarHoliday;

    final notifId = _notifId(event.id);
    final tzTime = tz.TZDateTime.from(notifTime, tz.local);
    final scheduleMode = await _scheduleMode();
    final body = _buildBody(event);

    final android = AndroidNotificationDetails(
      isHoliday ? 'holiday_channel' : 'event_channel',
      isHoliday ? 'Ngày lễ & Sự kiện đặc biệt' : 'Nhắc nhở sự kiện',
      importance: isHoliday ? Importance.defaultImportance : Importance.high,
      priority: isHoliday ? Priority.defaultPriority : Priority.high,
      // Hiển thị đầy đủ trên màn hình khóa
      visibility: NotificationVisibility.public,
      // Full screen intent: hiện kể cả khi màn hình tắt
      fullScreenIntent: !isHoliday,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      color: event.color,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: event.title,
        summaryText: 'Lịch Việt',
      ),
      category: AndroidNotificationCategory.reminder,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    try {
      await _plugin.zonedSchedule(
        notifId,
        event.title,
        body,
        tzTime,
        NotificationDetails(android: android, iOS: ios),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: event.id,
      );
      debugPrint('[Notif] ✅ id=$notifId mode=$scheduleMode time=$tzTime');
    } catch (e) {
      debugPrint('[Notif] ❌ zonedSchedule error: $e');
    }
  }

  /// Test ngay lập tức bằng cách lên lịch sau 5 giây
  Future<void> scheduleTestIn5Seconds() async {
    final testTime =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    final mode = await _scheduleMode();

    const android = AndroidNotificationDetails(
      'event_channel',
      'Nhắc nhở sự kiện',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.zonedSchedule(
      999999,
      '🔔 Lịch Việt - Test lên lịch',
      'Nếu bạn thấy thông báo này, hệ thống nhắc nhở hoạt động!',
      testTime,
      const NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('[Notif] Test scheduled at $testTime mode=$mode');
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (_sdkVersion >= 31) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await ap?.canScheduleExactNotifications() ?? false;
      debugPrint('[Notif] canScheduleExact=$canExact');
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  // ─── Hủy ────────────────────────────────────────────────────────────────────

  Future<void> cancelEventNotification(String eventId) async {
    await _plugin.cancel(_notifId(eventId));
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  // ─── Instant ────────────────────────────────────────────────────────────────

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
      fullScreenIntent: true,
      color: color,
      playSound: true,
      enableVibration: true,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  int _notifId(String eventId) => eventId.hashCode.abs() % 2147483647;

  DateTime? _calcNotifTime(CalendarEvent event) {
    final d = event.date;
    final minsBefore = event.notificationMinutesBefore ?? 30;

    if (event.startTime != null) {
      // Có giờ cụ thể → nhắc trước N phút
      final start = DateTime(
          d.year, d.month, d.day, event.startTime!.hour, event.startTime!.minute);
      return start.subtract(Duration(minutes: minsBefore));
    }

    if (event.isAllDay) {
      // Cả ngày → nhắc 8h sáng ngày đó
      // Nếu minsBefore >= 1440 → nhắc 8h sáng ngày hôm trước
      return minsBefore >= 1440
          ? DateTime(d.year, d.month, d.day - 1, 8, 0)
          : DateTime(d.year, d.month, d.day, 8, 0);
    }

    // Không có giờ, không phải cả ngày → nhắc 8h sáng
    return DateTime(d.year, d.month, d.day, 8, 0);
  }

  String _buildBody(CalendarEvent event) {
    if (event.description?.isNotEmpty == true) return event.description!;
    if (event.isAllDay) return 'Sự kiện cả ngày hôm nay';
    if (event.startTime != null) {
      final h = event.startTime!.hour.toString().padLeft(2, '0');
      final m = event.startTime!.minute.toString().padLeft(2, '0');
      final mins = event.notificationMinutesBefore ?? 30;
      return 'Bắt đầu lúc $h:$m${mins > 0 ? " (còn $mins phút)" : ""}';
    }
    return 'Nhắc nhở sự kiện';
  }
}
