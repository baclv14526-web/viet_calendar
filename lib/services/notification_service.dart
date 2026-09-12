import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
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
  
  // Timezone constants - ĐỊNH NGHĨA TRƯỚC KHI SỬ DỤNG
  static const String _hanoiZone = 'Asia/Ho_Chi_Minh';
  // v2 prevents an old, user-muted/low-importance channel from surviving
  // an earlier buggy build.
  static const String _eventChannelId = 'viet_calendar_events_v2';
  static const String _holidayChannelId = 'viet_calendar_holidays_v2';
  tz.Location get _hanoi => tz.getLocation(_hanoiZone);
  
  // Getter để truy cập từ bên ngoài
  bool get isOppoOrRealme => _isOppoOrRealme;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      _sdkVersion = info.version.sdkInt;
      _manufacturer = info.manufacturer.toLowerCase();
      _deviceBrand = info.brand.toLowerCase();
      _isOppoOrRealme = _manufacturer.contains('oppo') || 
                       _deviceBrand.contains('oppo') ||
                       _manufacturer.contains('realme') ||
                       _deviceBrand.contains('realme');
      
      debugPrint('[Notif] Android SDK: $_sdkVersion');
      debugPrint('[Notif] Manufacturer: $_manufacturer');
      debugPrint('[Notif] Brand: $_deviceBrand');
      debugPrint('[Notif] Is Oppo/Realme: $_isOppoOrRealme');
    }

    // Initialize timezone - MUST be called before any TZDateTime usage
    tz.initializeTimeZones();
    final hanoi = _hanoi;
    tz.setLocalLocation(hanoi);
    debugPrint('[Notif] Timezone fixed to $_hanoiZone');

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // request sau khi app load xong
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTapped,
      onDidReceiveBackgroundNotificationResponse: _onBgTapped,
    );

    await _createChannels();
    
    // KHÔNG dùng foreground service - dùng AlarmManager như Google Calendar
    // Foreground service chỉ cần cho các trường hợp đặc biệt
    // Đối với thông báo lịch, AlarmClock mode đã đủ mạnh
    
    _initialized = true;
    debugPrint('[Notif] Using AlarmManager (like Google Calendar) - no foreground service needed');
  }

  Future<void> _createChannels() async {
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (ap == null) return;

    // HIGH importance channel - bắt buộc để hiện banner + âm thanh
    await ap.createNotificationChannel(const AndroidNotificationChannel(
      _eventChannelId,
      'Sự kiện lịch',
      description: 'Thông báo nhắc nhở sự kiện trong lịch Việt',
      importance: Importance.max, // MAX để đảm bảo hiện banner
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF1565C0),
    ));

    await ap.createNotificationChannel(const AndroidNotificationChannel(
      _holidayChannelId,
      'Ngày lễ',
      description: 'Thông báo ngày lễ và sự kiện đặc biệt',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    ));

    debugPrint('[Notif] Channels created');
  }

  static void _onTapped(NotificationResponse r) =>
      debugPrint('[Notif] Tapped: ${r.payload}');

  @pragma('vm:entry-point')
  static void _onBgTapped(NotificationResponse r) =>
      debugPrint('[Notif] BG tapped: ${r.payload}');

  // ─── Permissions ───────────────────────────────────────────────────────────

  Future<Map<String, bool>> requestAllPermissions() async {
    final result = <String, bool>{
      'notification': true,
      'exactAlarm': true,
      // Battery optimisation exemption is NOT required for exact alarms.
      // Keep this false only as an informational status; do not request it
      // automatically because OEM/Play policies may restrict this permission.
      'battery': true,
    };

    if (Platform.isIOS) {
      final ip = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      result['notification'] = await ip?.requestPermissions(
            alert: true, badge: true, sound: true) ?? false;
      return result;
    }

    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Android 13+: POST_NOTIFICATIONS
    if (_sdkVersion >= 33) {
      result['notification'] =
          await ap?.requestNotificationsPermission() ?? false;
    }

    // Android 12-32: SCHEDULE_EXACT_ALARM is user-controlled.
    // Android 33+: this calendar app declares USE_EXACT_ALARM, so the system
    // grants exact-alarm access at install time when the app qualifies.
    if (_sdkVersion >= 31 && _sdkVersion <= 32) {
      var canExact =
          await ap?.canScheduleExactNotifications() ?? false;

      if (!canExact) {
        debugPrint('[Notif] Exact alarm permission is OFF; requesting...');
        try {
          canExact = await ap?.requestExactAlarmsPermission() ?? false;
        } catch (e) {
          debugPrint('[Notif] requestExactAlarmsPermission failed: $e');
        }
      }

      // Re-check after returning from Settings.
      canExact =
          await ap?.canScheduleExactNotifications() ?? canExact;
      result['exactAlarm'] = canExact;

      if (!canExact) {
        debugPrint(
          '[Notif] Exact alarms are NOT available. '
          'User must enable "Alarms & reminders".',
        );
      }
    } else if (_sdkVersion >= 33) {
      result['exactAlarm'] =
          await ap?.canScheduleExactNotifications() ?? true;
    }

    debugPrint('[Notif] Permissions: $result');
    return result;
  }

  Future<bool> requestPermission() async {
    final r = await requestAllPermissions();
    return r.values.every((v) => v);
  }

  Future<Map<String, bool>> checkPermissions() async {
    if (!Platform.isAndroid) {
      return {'notification': true, 'exactAlarm': true, 'battery': true};
    }

    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final notification = _sdkVersion < 33 ||
        (await Permission.notification.status).isGranted;

    final exactAlarm = _sdkVersion < 31 ||
        (await ap?.canScheduleExactNotifications() ?? false);

    // Do not treat battery optimisation as a hard requirement.
    return {
      'notification': notification,
      'exactAlarm': exactAlarm,
      'battery': true,
    };
  }


  // ─── Schedule notification ─────────────────────────────────────────────────

  /// Lên lịch thông báo cho sự kiện.
  /// Trả về DateTime thực tế thông báo sẽ fire, hoặc null nếu không schedule.
  Future<DateTime?> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return null;

    try {
      await initialize();

      final notifTime = _calcNotifTime(event);
      if (notifTime == null) return null;

      final tzTime = tz.TZDateTime(
        _hanoi,
        notifTime.year,
        notifTime.month,
        notifTime.day,
        notifTime.hour,
        notifTime.minute,
        0,
      );

      final now = tz.TZDateTime.now(_hanoi);
      if (!tzTime.isAfter(now)) {
        debugPrint('[Notif] Skip: scheduled time is not in the future: $tzTime');
        return null;
      }

      final permissions = await checkPermissions();

      if (Platform.isAndroid) {
        if (!permissions['notification']!) {
          debugPrint('[Notif] ❌ POST_NOTIFICATIONS is not granted');
          return null;
        }

        if (_sdkVersion >= 31 && !permissions['exactAlarm']!) {
          debugPrint(
            '[Notif] ❌ Exact alarm permission is not granted. '
            'Refusing inexact fallback.',
          );
          return null;
        }
      }

      final isHoliday = event.type == EventType.holiday ||
          event.type == EventType.lunarHoliday;

      // Dart String.hashCode is not a persistent storage ID. Use a small,
      // deterministic FNV-1a hash so the same event always maps to the same
      // notification ID across app restarts/versions/platforms.
      final notifId = _stableNotificationId(event.id);

      final body = _buildBody(event);

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          isHoliday ? _holidayChannelId : _eventChannelId,
          isHoliday ? 'Ngày lễ' : 'Sự kiện lịch',
          channelDescription: isHoliday
              ? 'Thông báo ngày lễ'
              : 'Thông báo nhắc nhở sự kiện trong lịch Việt',
          importance: isHoliday ? Importance.high : Importance.max,
          priority: isHoliday ? Priority.high : Priority.max,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          color: event.color,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: event.title,
            summaryText: 'Lịch Việt',
          ),
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          fullScreenIntent: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      // Replace an old schedule for the same event before scheduling the new
      // one. This prevents duplicate notifications after editing an event.
      await _plugin.cancel(notifId);

      // exactAllowWhileIdle is preferable for calendar reminders:
      // exact timing + delivery while Android is in Doze/low-power idle.
      //
      // It still requires exact-alarm access on Android 12+.
      const mode = AndroidScheduleMode.exactAllowWhileIdle;

      debugPrint(
        '[Notif] Scheduling "${event.title}" '
        'id=$notifId -> $tzTime ($mode, Asia/Ho_Chi_Minh)',
      );

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

      // Verify that the plugin still sees this request as pending.
      // This does not prove Android will display it, but catches failed
      // scheduling immediately.
      final pending = await _plugin.pendingNotificationRequests();
      final found = pending.any((n) => n.id == notifId);

      if (!found) {
        debugPrint(
          '[Notif] ⚠️ Schedule call succeeded but request is not in '
          'pendingNotificationRequests(): id=$notifId',
        );
      } else {
        debugPrint(
          '[Notif] ✅ Scheduled and verified pending: '
          'id=$notifId time=$tzTime',
        );
      }

      return notifTime;
    } catch (e, stackTrace) {
      debugPrint('[Notif] ❌ Error scheduling "${event.title}": $e');
      debugPrint('[Notif] Stack trace: $stackTrace');
      return null;
    }
  }


  /// Re-schedules all persisted personal events and built-in Vietnamese
  /// holidays. This must run after app startup because the original app only
  /// scheduled an event at the moment it was created.
  Future<void> rescheduleAll(Iterable<CalendarEvent> events) async {
    await initialize();

    final permissions = await checkPermissions();
    if (Platform.isAndroid &&
        (!permissions['notification']! || !permissions['exactAlarm']!)) {
      debugPrint('[Notif] rescheduleAll skipped: permissions=$permissions');
      return;
    }

    var count = 0;

    for (final event in events) {
      if (await scheduleEventNotification(event) != null) {
        count++;
      }
    }

    // Built-in holidays are generated for the calendar UI and are NOT stored
    // in SQLite. They therefore need explicit scheduling too.
    final now = tz.TZDateTime.now(_hanoi);
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
    // FNV-1a 32-bit. Deterministic across app launches.
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }

    // Android notification IDs can be any signed int; keep 1 reserved
    // as a safe non-zero value.
    return hash == 0 ? 1 : hash;
  }

  // ─── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelEventNotification(String eventId) async {
    await _plugin.cancel(_stableNotificationId(eventId));
  }

  Future<void> cancelAllNotifications() async => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> getPendingNotifications() async =>
      _plugin.pendingNotificationRequests();

  // ─── Instant (show ngay) ──────────────────────────────────────────────────

  Future<void> showInstantNotification({
    required String title,
    required String body,
    Color color = const Color(0xFF1565C0),
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _eventChannelId,
          'Sự kiện lịch',
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          color: color,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ─── Test 5 giây ──────────────────────────────────────────────────────────

  Future<void> scheduleTestIn5Seconds() async {
    try {
      debugPrint('[Notif] Starting 5s test...');
      
      // Sử dụng exactAllowWhileIdle cho test như event chính
      const mode = AndroidScheduleMode.exactAllowWhileIdle;
      debugPrint('[Notif] Schedule mode: $mode');
      
      // Sử dụng _hanoi timezone để nhất quán
      final testTime = tz.TZDateTime.now(_hanoi).add(const Duration(seconds: 5));
      debugPrint('[Notif] Test time: $testTime');

      final androidDetails = AndroidNotificationDetails(
        _eventChannelId,
        'Sự kiện lịch',
        channelDescription: 'Test thông báo',
        importance: Importance.max,
        priority: Priority.max,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        // Tắt fullScreenIntent cho test để tránh crash
        fullScreenIntent: false,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      debugPrint('[Notif] Scheduling test notification...');
      
      await _plugin.zonedSchedule(
        888888,
        '🔔 Lịch Việt – Test thành công!',
        'Hệ thống thông báo hoạt động đúng. Mode: $mode',
        testTime,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      debugPrint('[Notif] ✅ Test 5s scheduled successfully: mode=$mode time=$testTime');
    } catch (e, stackTrace) {
      debugPrint('[Notif] ❌ Error in scheduleTestIn5Seconds: $e');
      debugPrint('[Notif] Stack trace: $stackTrace');
      // Không rethrow để tránh crash UI
    }
  }

  // ─── Time calculation ──────────────────────────────────────────────────────

  DateTime? _calcNotifTime(CalendarEvent event) {
    final d = event.date;
    final minsBefore = event.notificationMinutesBefore ?? 30;

    // All calendar calculations are explicitly in Hanoi time. This prevents
    // a phone whose system timezone is temporarily changed from moving the
    // reminder to another wall-clock time.
    final now = tz.TZDateTime.now(_hanoi);
    final today = tz.TZDateTime(_hanoi, now.year, now.month, now.day);
    final eventDay = tz.TZDateTime(_hanoi, d.year, d.month, d.day);

    if (eventDay.isBefore(today)) return null;

    if (event.startTime != null) {
      final startDt = tz.TZDateTime(
        _hanoi,
        d.year,
        d.month,
        d.day,
        event.startTime!.hour,
        event.startTime!.minute,
      );

      var notifTime = startDt.subtract(Duration(minutes: minsBefore));

      if (notifTime.isBefore(now) && startDt.isAfter(now)) {
        notifTime = now.add(const Duration(minutes: 1));
      } else if (!notifTime.isAfter(now)) {
        return null;
      }

      return DateTime(
        notifTime.year,
        notifTime.month,
        notifTime.day,
        notifTime.hour,
        notifTime.minute,
      );
    }

    // All-day event: default reminder at 08:00 Hanoi time.
    final prevDay = minsBefore >= 1440
        ? eventDay.subtract(const Duration(days: 1))
        : eventDay;

    var notifTime = tz.TZDateTime(
      _hanoi,
      prevDay.year,
      prevDay.month,
      prevDay.day,
      8,
      0,
    );

    if (!notifTime.isAfter(now) && !eventDay.isBefore(today)) {
      notifTime = now.add(const Duration(minutes: 1));
    } else if (!notifTime.isAfter(now)) {
      return null;
    }

    return DateTime(
      notifTime.year,
      notifTime.month,
      notifTime.day,
      notifTime.hour,
      notifTime.minute,
    );
  }

  String _buildBody(CalendarEvent event) {
    if (event.description?.isNotEmpty == true) return event.description!;
    if (event.isAllDay) return 'Sự kiện cả ngày';
    if (event.startTime != null) {
      final h = event.startTime!.hour.toString().padLeft(2, '0');
      final m = event.startTime!.minute.toString().padLeft(2, '0');
      final mins = event.notificationMinutesBefore ?? 30;
      return 'Bắt đầu lúc $h:$m${mins > 0 ? " • còn $mins phút" : ""}';
    }
    return 'Nhắc nhở sự kiện trong lịch Việt';
  }

  // ─── Oppo/Realme ColorOS Specific Methods ───────────────────────────────────

  /// Lấy hướng dẫn cài đặt cho Oppo/Realme
  String getOppoRealmeGuide() {
    return '''
📱 Hướng dẫn cho Oppo/Realme (ColorOS):
🔥 Giống Google Calendar - KHÔNG cần chạy nền!

1. Bật thông báo:
   Cài đặt → Thông báo → Lịch Việt → Bật "Cho phép thông báo"

2. Bỏ qua tối ưu pin (QUAN TRỌNG NHẤT):
   Cài đặt → Pin → Tiết kiệm pin → Lịch Việt → Chọn "Không hạn chế"
   
   HOẶC:
   Cài đặt → Ứng dụng → Lịch Việt → Pin → Bỏ qua tối ưu hóa

3. Bật báo thức (QUAN TRỌNG):
   Cài đặt → Ứng dụng → Quyền đặc biệt → Báo thức & nhắc nhở → Bật Lịch Việt
   (Đây là cách Google Calendar hoạt động - không cần app chạy)

💡 TIPS:
- KHÔNG cần bật "Chạy trong nền" - tốn pin
- Hệ thống tự thông báo như Google Calendar
- Đảm bảo quyền Báo thức là QUAN TRỌNG NHẤT
''';
  }
}
