import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../models/calendar_event.dart';
import '../utils/vietnamese_holidays.dart';

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _sdkVersion = 0;
  String _manufacturer = '';
  String _deviceBrand = '';
  bool _isOppoOrRealme = false;

  // Notification Channels v4 - MAX Importance & Lock screen support
  static const String _defaultTimeZone = 'Asia/Ho_Chi_Minh';
  static const String _eventChannelId = 'viet_calendar_reminders_v4';
  static const String _holidayChannelId = 'viet_calendar_holidays_v4';
  static const String _smallIcon = 'ic_stat_calendar';

  bool get isOppoOrRealme => _isOppoOrRealme;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _sdkVersion = info.version.sdkInt;
        _manufacturer = info.manufacturer.toLowerCase();
        _deviceBrand = info.brand.toLowerCase();
        _isOppoOrRealme = _manufacturer.contains('oppo') ||
            _deviceBrand.contains('oppo') ||
            _manufacturer.contains('realme') ||
            _deviceBrand.contains('realme');

        debugPrint('[Notif] Android SDK: $_sdkVersion');
        debugPrint('[Notif] Manufacturer: $_manufacturer, Brand: $_deviceBrand');
      } catch (e) {
        _sdkVersion = 33;
        debugPrint('[Notif] DeviceInfo error: $e');
      }
    }

    // Khởi tạo timezone an toàn
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(_defaultTimeZone));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }
      debugPrint('[Notif] Timezone initialized: ${tz.local.name}');
    } catch (e) {
      debugPrint('[Notif] Timezone init warning: $e');
    }

    // Icon thông báo đơn sắc chuẩn Android (ic_stat_calendar)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(_smallIcon),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onTapped,
      );
    } catch (e) {
      debugPrint('[Notif] Plugin initialize error: $e');
    }

    await _createChannels();
    _initialized = true;
    debugPrint('[Notif] NotificationService initialized successfully');
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (ap == null) return;

    try {
      // Kênh Sự kiện - MAX importance để hiện banner nổi và trên màn hình khóa
      await ap.createNotificationChannel(const AndroidNotificationChannel(
        _eventChannelId,
        'Sự kiện & Nhắc nhở lịch',
        description: 'Thông báo nhắc nhở sự kiện và lịch hẹn trong Lịch Việt',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
        ledColor: Color(0xFF1565C0),
      ));

      // Kênh Ngày lễ
      await ap.createNotificationChannel(const AndroidNotificationChannel(
        _holidayChannelId,
        'Ngày lễ & Tết',
        description: 'Thông báo ngày lễ truyền thống và sự kiện đặc biệt',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
        ledColor: Color(0xFFD32F2F),
      ));

      debugPrint('[Notif] Notification Channels created (v4)');
    } catch (e) {
      debugPrint('[Notif] createNotificationChannel error: $e');
    }
  }

  static void _onTapped(NotificationResponse r) =>
      debugPrint('[Notif] Tapped: ${r.payload}');

  static const String _prefKeyBatteryOptPrompted = 'has_prompted_battery_optimization';

  // ─── Permissions ───────────────────────────────────────────────────────────

  Future<Map<String, bool>> requestAllPermissions({bool forceBattery = false}) async {
    await initialize();
    final result = <String, bool>{
      'notification': true,
      'exactAlarm': true,
      'battery': true,
    };

    if (Platform.isIOS) {
      final ip = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      result['notification'] = await ip?.requestPermissions(
            alert: true, badge: true, sound: true) ?? false;
      return result;
    }

    if (Platform.isAndroid) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

      // Android 13+ (API 33+): POST_NOTIFICATIONS
      if (_sdkVersion >= 33) {
        var notifGranted = (await Permission.notification.status).isGranted;
        if (!notifGranted) {
          final status = await Permission.notification.request();
          notifGranted = status.isGranted;
        }
        if (!notifGranted) {
          notifGranted = await ap?.requestNotificationsPermission() ?? false;
        }
        result['notification'] = notifGranted;
      }

      // Android 12+ (API 31+): SCHEDULE_EXACT_ALARM
      if (_sdkVersion >= 31) {
        var canExact = await ap?.canScheduleExactNotifications() ?? false;
        if (!canExact) {
          try {
            canExact = await ap?.requestExactAlarmsPermission() ?? false;
          } catch (e) {
            debugPrint('[Notif] requestExactAlarmsPermission: $e');
          }
        }
        canExact = await ap?.canScheduleExactNotifications() ?? canExact;
        result['exactAlarm'] = canExact;
      }

      // Yêu cầu quyền Chạy nền / Bỏ qua tối ưu pin: chỉ hỏi 1 lần duy nhất sau khi cài đặt
      var batteryGranted = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!batteryGranted) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final hasPrompted = prefs.getBool(_prefKeyBatteryOptPrompted) ?? false;
          if (!hasPrompted || forceBattery) {
            await prefs.setBool(_prefKeyBatteryOptPrompted, true);
            if (await Permission.ignoreBatteryOptimizations.isDenied) {
              final status = await Permission.ignoreBatteryOptimizations.request();
              batteryGranted = status.isGranted;
            }
          }
        } catch (e) {
          debugPrint('[Notif] ignoreBatteryOptimizations error: $e');
        }
      }
      result['battery'] = batteryGranted;
    }

    debugPrint('[Notif] Permissions requested: $result');
    return result;
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    if (_sdkVersion >= 33) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      var status = await Permission.notification.request();
      if (!status.isGranted && ap != null) {
        return await ap.requestNotificationsPermission() ?? false;
      }
      return status.isGranted;
    }
    return true;
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (_sdkVersion >= 31 && ap != null) {
      try {
        await ap.requestExactAlarmsPermission();
      } catch (_) {}
      return await ap.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  Future<bool> requestBatteryPermission() async {
    await initialize();
    if (!Platform.isAndroid) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyBatteryOptPrompted, true);
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    final r = await requestAllPermissions();
    return r.values.every((v) => v);
  }

  Future<Map<String, bool>> checkPermissions() async {
    if (!Platform.isAndroid) {
      return {'notification': true, 'exactAlarm': true, 'battery': true};
    }

    if (_sdkVersion == 0) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _sdkVersion = info.version.sdkInt;
      } catch (_) {
        _sdkVersion = 33;
      }
    }

    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final notification = _sdkVersion < 33 ||
        (await Permission.notification.status).isGranted;

    final exactAlarm = _sdkVersion < 31 ||
        (await ap?.canScheduleExactNotifications() ?? false);

    final battery = await Permission.ignoreBatteryOptimizations.isGranted;

    return {
      'notification': notification,
      'exactAlarm': exactAlarm,
      'battery': battery,
    };
  }

  // ─── Details Builder ───────────────────────────────────────────────────────

  NotificationDetails _buildNotificationDetails({
    required String title,
    required String body,
    bool isHoliday = false,
    Color color = const Color(0xFF1565C0),
  }) {
    final channelId = isHoliday ? _holidayChannelId : _eventChannelId;
    final channelName = isHoliday ? 'Ngày lễ & Tết' : 'Sự kiện & Nhắc nhở lịch';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Thông báo nhắc nhở từ Lịch Việt',
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        color: color,
        icon: _smallIcon,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Lịch Việt',
        ),
        category: AndroidNotificationCategory.reminder,
        autoCancel: true,
        fullScreenIntent: false,
        ticker: title,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  // ─── Schedule notification ─────────────────────────────────────────────────

  /// Lên lịch thông báo cho sự kiện.
  Future<DateTime?> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return null;

    try {
      await initialize();

      final notifTime = _calcNotifTime(event);
      if (notifTime == null) return null;

      final tzTime = tz.TZDateTime(
        tz.local,
        notifTime.year,
        notifTime.month,
        notifTime.day,
        notifTime.hour,
        notifTime.minute,
        notifTime.second,
      );
      final now = tz.TZDateTime.now(tz.local);

      if (!tzTime.isAfter(now)) {
        debugPrint(
          '[Notif] Skip: scheduled time is not in the future: $tzTime (now: $now)',
        );
        return null;
      }

      final permissions = await checkPermissions();
      if (Platform.isAndroid && !permissions['notification']!) {
        debugPrint('[Notif] ❌ POST_NOTIFICATIONS is not granted');
        return null;
      }

      final isHoliday = event.type == EventType.holiday ||
          event.type == EventType.lunarHoliday;

      final notifId = _stableNotificationId(event.id);
      final body = _buildBody(event);
      final details = _buildNotificationDetails(
        title: event.title,
        body: body,
        isHoliday: isHoliday,
        color: event.color,
      );

      // Xóa thông báo cũ của sự kiện nếu có
      await _plugin.cancel(notifId);

      final canExact = permissions['exactAlarm'] ?? false;
      var mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      debugPrint(
        '[Notif] Scheduling "${event.title}" id=$notifId -> $tzTime ($mode)',
      );

      try {
        await _plugin.zonedSchedule(
          notifId,
          event.title,
          body,
          tzTime,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: event.id,
        );
      } catch (scheduleErr) {
        debugPrint(
          '[Notif] Exact schedule failed ($scheduleErr); retrying inexactAllowWhileIdle',
        );
        mode = AndroidScheduleMode.inexactAllowWhileIdle;

        await _plugin.zonedSchedule(
          notifId,
          event.title,
          body,
          tzTime,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: event.id,
        );
      }

      debugPrint('[Notif] ✅ Scheduled successfully: id=$notifId time=$tzTime');
      return notifTime;
    } catch (e, stackTrace) {
      debugPrint('[Notif] ❌ Error scheduling "${event.title}": $e');
      debugPrint('[Notif] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Tải lại tất cả thông báo sự kiện và ngày lễ
  Future<void> rescheduleAll(Iterable<CalendarEvent> events) async {
    await initialize();

    final permissions = await checkPermissions();
    if (Platform.isAndroid && !permissions['notification']!) {
      debugPrint('[Notif] rescheduleAll skipped: POST_NOTIFICATIONS not granted');
      return;
    }

    var count = 0;
    for (final event in events) {
      if (await scheduleEventNotification(event) != null) {
        count++;
      }
    }

    final now = tz.TZDateTime.now(tz.local);
    for (final year in [now.year, now.year + 1]) {
      for (final holiday in VietnameseHolidays.getHolidaysForYear(year)) {
        if (await scheduleEventNotification(holiday) != null) {
          count++;
        }
      }
    }

    debugPrint('[Notif] rescheduleAll: scheduled=$count');
  }

  int _stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  // ─── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelEventNotification(String eventId) async {
    try {
      await _plugin.cancel(_stableNotificationId(eventId));
    } catch (_) {}
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }

  // ─── Instant Notification (Hiển thị ngay lập tức) ──────────────────────────

  Future<void> showInstantNotification({
    required String title,
    required String body,
    Color color = const Color(0xFF1565C0),
  }) async {
    try {
      await initialize();
      final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
      final details = _buildNotificationDetails(
        title: title,
        body: body,
        color: color,
      );

      await _plugin.show(id, title, body, details);
      debugPrint('[Notif] ✅ Instant notification displayed: id=$id');
    } catch (e) {
      debugPrint('[Notif] ❌ showInstantNotification error: $e');
    }
  }

  // ─── Test 5 giây (Bảo đảm 100% không crash & có hiển thị) ───────────────────

  Future<void> scheduleTestIn5Seconds() async {
    try {
      await initialize();
      debugPrint('[Notif] Starting 5s test...');

      final permissions = await checkPermissions();
      final canExact = permissions['exactAlarm'] ?? false;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final testTime =
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

      final details = _buildNotificationDetails(
        title: '🔔 Lịch Việt – Test 5 giây thành công!',
        body: 'Thông báo hẹn giờ đang hoạt động chính xác trên màn hình!',
        color: const Color(0xFFFF9800),
      );

      // 1. Đặt lịch thông qua AlarmManager hệ thống
      try {
        await _plugin.zonedSchedule(
          888888,
          '🔔 Lịch Việt – Test 5 giây thành công!',
          'Thông báo hẹn giờ đang hoạt động chính xác trên màn hình!',
          testTime,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('[Notif] ✅ Test 5s zonedSchedule created: mode=$mode time=$testTime');
      } catch (e1) {
        debugPrint('[Notif] ⚠️ zonedSchedule fallback: $e1');
        await _plugin.zonedSchedule(
          888888,
          '🔔 Lịch Việt – Test 5 giây thành công!',
          'Thông báo hẹn giờ đang hoạt động chính xác trên màn hình!',
          testTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[Notif] ❌ Error in scheduleTestIn5Seconds: $e');
      debugPrint('[Notif] Stack trace: $stackTrace');
    }
  }

  // ─── Time calculation ──────────────────────────────────────────────────────

  DateTime? _calcNotifTime(CalendarEvent event) {
    final d = event.date;
    final minsBefore = event.notificationMinutesBefore ?? 30;

    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    final eventDay = tz.TZDateTime(tz.local, d.year, d.month, d.day);

    if (eventDay.isBefore(today)) return null;

    if (event.startTime != null) {
      final startDt = tz.TZDateTime(
        tz.local,
        d.year,
        d.month,
        d.day,
        event.startTime!.hour,
        event.startTime!.minute,
        0,
      );

      var notifTime = startDt.subtract(Duration(minutes: minsBefore));

      if (notifTime.isBefore(now) && startDt.isAfter(now)) {
        // Nếu giờ nhắc nhở đã qua nhưng sự kiện chưa bắt đầu -> nhắc sau 10 giây
        notifTime = now.add(const Duration(seconds: 10));
      } else if (!notifTime.isAfter(now)) {
        return null;
      }

      return DateTime(
        notifTime.year,
        notifTime.month,
        notifTime.day,
        notifTime.hour,
        notifTime.minute,
        notifTime.second,
      );
    }

    // Sự kiện cả ngày: mặc định nhắc lúc 08:00
    final prevDay = minsBefore >= 1440
        ? eventDay.subtract(const Duration(days: 1))
        : eventDay;

    var notifTime = tz.TZDateTime(
      tz.local,
      prevDay.year,
      prevDay.month,
      prevDay.day,
      8,
      0,
      0,
    );

    if (!notifTime.isAfter(now) && !eventDay.isBefore(today)) {
      // Nếu là hôm nay và đã quá 8:00 sáng -> nhắc sau 10 giây
      notifTime = now.add(const Duration(seconds: 10));
    } else if (!notifTime.isAfter(now)) {
      return null;
    }

    return DateTime(
      notifTime.year,
      notifTime.month,
      notifTime.day,
      notifTime.hour,
      notifTime.minute,
      notifTime.second,
    );
  }

  String _buildBody(CalendarEvent event) {
    if (event.description?.isNotEmpty == true) return event.description!;
    if (event.isAllDay) return 'Sự kiện cả ngày';
    if (event.startTime != null) {
      final h = event.startTime!.hour.toString().padLeft(2, '0');
      final m = event.startTime!.minute.toString().padLeft(2, '0');
      final mins = event.notificationMinutesBefore ?? 30;
      return 'Bắt đầu lúc $h:$m${mins > 0 ? " • Nhắc trước $mins phút" : ""}';
    }
    return 'Nhắc nhở sự kiện trong lịch Việt';
  }

  // ─── Oppo/Realme/Xiaomi/Samsung Guide ──────────────────────────────────────

  String getOppoRealmeGuide() {
    return '''
📱 Hướng dẫn bật thông báo nổi & màn hình khóa trên Android (Xiaomi, Oppo, Realme, Samsung, Vivo):

1. Bật Thông báo nổi & Màn hình khóa (QUAN TRỌNG NHẤT):
   Cài đặt → Ứng dụng → Quản lý ứng dụng → Lịch Việt → Thông báo:
   • Bật "Hiển thị trên màn hình khóa" (Lock screen)
   • Bật "Thông báo nổi / Banner / Pop-up" (Floating notifications)
   • Bật "Âm thanh & Rung"

2. Bật quyền Báo thức & Nhắc nhở:
   Cài đặt → Ứng dụng → Quyền đặc biệt → Báo thức & nhắc nhở → Bật cho Lịch Việt

3. Bỏ qua tối ưu pin (Chạy nền):
   Cài đặt → Pin → Tiết kiệm pin / Tối ưu pin → Lịch Việt → Chọn "Không hạn chế" (No restrictions)
''';
  }
}
