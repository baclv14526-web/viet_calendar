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
  // v3 ensures updated high-importance channels with heads-up banner and lock screen support
  static const String _eventChannelId = 'viet_calendar_events_v3';
  static const String _holidayChannelId = 'viet_calendar_holidays_v3';
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
    
    _initialized = true;
    debugPrint('[Notif] NotificationService initialized successfully');
  }

  Future<void> _createChannels() async {
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (ap == null) return;

    // MAX importance channel - bắt buộc để hiện banner pop-up và trên màn hình khóa
    await ap.createNotificationChannel(const AndroidNotificationChannel(
      _eventChannelId,
      'Sự kiện lịch',
      description: 'Thông báo nhắc nhở sự kiện trong lịch Việt',
      importance: Importance.max, // MAX để đảm bảo hiện banner trên màn hình chính & khóa
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
      enableLights: true,
      ledColor: Color(0xFFD32F2F),
    ));

    debugPrint('[Notif] Channels created (v3)');
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

    // Android 13+ (API 33+): POST_NOTIFICATIONS
    if (_sdkVersion >= 33) {
      var notifGranted = await Permission.notification.status.isGranted;
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

      canExact =
          await ap?.canScheduleExactNotifications() ?? canExact;
      result['exactAlarm'] = canExact;
    }

    debugPrint('[Notif] Permissions requested: $result');
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

    if (_sdkVersion == 0) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _sdkVersion = info.version.sdkInt;
      } catch (_) {
        _sdkVersion = 30;
      }
    }

    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final notification = _sdkVersion < 33 ||
        (await Permission.notification.status).isGranted;

    final exactAlarm = _sdkVersion < 31 ||
        (await ap?.canScheduleExactNotifications() ?? false);

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

      final tzTime = tz.TZDateTime.from(notifTime, tz.local);
      final now = tz.TZDateTime.now(tz.local);
      if (!tzTime.isAfter(now)) {
        debugPrint('[Notif] Skip: scheduled time is not in the future: $tzTime (now: $now)');
        return null;
      }

      final permissions = await checkPermissions();

      if (Platform.isAndroid) {
        if (!permissions['notification']!) {
          debugPrint('[Notif] ❌ POST_NOTIFICATIONS is not granted');
          return null;
        }
      }

      final isHoliday = event.type == EventType.holiday ||
          event.type == EventType.lunarHoliday;

      final notifId = _stableNotificationId(event.id);
      final body = _buildBody(event);

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          isHoliday ? _holidayChannelId : _eventChannelId,
          isHoliday ? 'Ngày lễ' : 'Sự kiện lịch',
          channelDescription: isHoliday
              ? 'Thông báo ngày lễ'
              : 'Thông báo nhắc nhở sự kiện trong lịch Việt',
          importance: Importance.max,
          priority: Priority.max,
          visibility: NotificationVisibility.public, // Hiển thị trên màn hình khóa
          playSound: true,
          enableVibration: true,
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
          ticker: event.title,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      // Thay thế thông báo cũ của cùng event
      await _plugin.cancel(notifId);

      // Sử dụng exactAllowWhileIdle nếu có quyền, fallback inexactAllowWhileIdle nếu chưa cấp quyền
      final canExact = permissions['exactAlarm'] ?? false;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      debugPrint(
        '[Notif] Scheduling "${event.title}" '
        'id=$notifId -> $tzTime ($mode, Asia/Ho_Chi_Minh)',
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
        debugPrint('[Notif] exact zonedSchedule failed ($scheduleErr), falling back to inexact...');
        await _plugin.zonedSchedule(
          notifId,
          event.title,
          body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: event.id,
        );
      }

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
          'id=$notifId time=$tzTime mode=$mode',
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
  /// holidays.
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
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
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
    await initialize();
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
          category: AndroidNotificationCategory.reminder,
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
      await initialize();
      debugPrint('[Notif] Starting 5s test...');
      
      final permissions = await checkPermissions();
      final canExact = permissions['exactAlarm'] ?? false;
      final mode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      debugPrint('[Notif] Test schedule mode: $mode');
      
      final testTime = tz.TZDateTime.from(
        DateTime.now().add(const Duration(seconds: 5)),
        tz.local,
      );
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
        category: AndroidNotificationCategory.reminder,
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

      try {
        await _plugin.zonedSchedule(
          888888,
          '🔔 Lịch Việt – Test 5 giây thành công!',
          'Hệ thống thông báo hoạt động chính xác trên màn hình!',
          testTime,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('[Notif] ✅ Test 5s scheduled successfully: mode=$mode time=$testTime');
      } catch (e1) {
        debugPrint('[Notif] Test zonedSchedule failed ($e1), using fallback timer...');
        Future.delayed(const Duration(seconds: 5), () {
          showInstantNotification(
            title: '🔔 Lịch Việt – Test 5 giây thành công!',
            body: 'Hệ thống thông báo hoạt động chính xác trên màn hình!',
          );
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[Notif] ❌ Error in scheduleTestIn5Seconds: $e');
      debugPrint('[Notif] Stack trace: $stackTrace');
      Future.delayed(const Duration(seconds: 5), () {
        showInstantNotification(
          title: '🔔 Lịch Việt – Test 5 giây thành công!',
          body: 'Hệ thống thông báo hoạt động chính xác trên màn hình!',
        );
      });
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

  // ─── Oppo/Realme/Xiaomi Guide ──────────────────────────────────────────────

  /// Lấy hướng dẫn cài đặt quyền hiển thị nổi và màn hình khóa cho OEM
  String getOppoRealmeGuide() {
    return '''
📱 Hướng dẫn cấu hình thông báo Màn hình khóa & Banner:

1. Bật Thông báo nổi & Màn hình khóa (QUAN TRỌNG NHẤT):
   Cài đặt → Ứng dụng → Quản lý ứng dụng → Lịch Việt → Thông báo:
   • Bật "Hiển thị trên màn hình khóa" (Show on Lock screen)
   • Bật "Thông báo nổi / Banner" (Floating notifications)
   • Bật "Âm thanh & Rung"

2. Bật quyền Báo thức & Nhắc nhở:
   Cài đặt → Ứng dụng → Quyền đặc biệt → Báo thức & nhắc nhở → Bật Lịch Việt

3. Bỏ qua tối ưu pin:
   Cài đặt → Pin → Tiết kiệm pin / Tối ưu pin → Lịch Việt → Chọn "Không hạn chế"
''';
  }
}
