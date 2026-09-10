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
  String _manufacturer = '';
  String _deviceBrand = '';
  bool _isOppoOrRealme = false;
  
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
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

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
      'viet_calendar_events',
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
      'viet_calendar_holidays',
      'Ngày lễ',
      description: 'Thông báo ngày lễ và sự kiện đặc biệt',
      importance: Importance.high,
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
      'battery': true,
    };

    if (Platform.isIOS) {
      final ip = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      result['notification'] = await ip?.requestPermissions(
            alert: true, badge: true, sound: true) ?? false;
      return result;
    }

    // Android 13+: POST_NOTIFICATIONS
    if (_sdkVersion >= 33) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      result['notification'] =
          await ap?.requestNotificationsPermission() ?? false;
    }

    // Android 12 (SDK 31-32): SCHEDULE_EXACT_ALARM
    // Android 13+ có USE_EXACT_ALARM auto-granted nên không cần check
    if (_sdkVersion == 31 || _sdkVersion == 32) {
      final ap = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await ap?.canScheduleExactNotifications() ?? false;
      result['exactAlarm'] = canExact;
      if (!canExact) {
        await Permission.scheduleExactAlarm.request();
        result['exactAlarm'] =
            await ap?.canScheduleExactNotifications() ?? false;
      }
    }

    // Battery optimization - cần thiết để alarm hoạt động trong Doze mode
    final battery = await Permission.ignoreBatteryOptimizations.status;
    result['battery'] = battery.isGranted;
    if (!battery.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
      result['battery'] =
          (await Permission.ignoreBatteryOptimizations.status).isGranted;
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

    return {
      'notification': _sdkVersion < 33 ||
          (await Permission.notification.status).isGranted,
      'exactAlarm': (_sdkVersion != 31 && _sdkVersion != 32) ||
          (await ap?.canScheduleExactNotifications() ?? false),
      'battery':
          (await Permission.ignoreBatteryOptimizations.status).isGranted,
    };
  }

  // ─── Schedule notification ─────────────────────────────────────────────────

  /// Lên lịch thông báo cho sự kiện.
  /// Trả về DateTime thực tế thông báo sẽ fire, hoặc null nếu không schedule.
  Future<DateTime?> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return null;

    try {
      final notifTime = _calcNotifTime(event);
      if (notifTime == null) return null;

      debugPrint('[Notif] Scheduling "${event.title}" → $notifTime');

      final isHoliday = event.type == EventType.holiday ||
          event.type == EventType.lunarHoliday;
      final notifId = event.id.hashCode.abs() % 2147483647;

      // Tạo TZDateTime trực tiếp với timezone Vietnam
      // QUAN TRỌNG: không dùng tz.TZDateTime.from() vì có thể sai khi
      // device timezone khác Asia/Ho_Chi_Minh
      final tzTime = tz.TZDateTime(
        tz.local,
        notifTime.year,
        notifTime.month,
        notifTime.day,
        notifTime.hour,
        notifTime.minute,
        0,
      );

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          isHoliday ? 'viet_calendar_holidays' : 'viet_calendar_events',
          isHoliday ? 'Ngày lễ' : 'Sự kiện lịch',
          channelDescription: isHoliday
              ? 'Thông báo ngày lễ'
              : 'Nhắc nhở sự kiện trong lịch Việt',
          importance: isHoliday ? Importance.high : Importance.max,
          priority: isHoliday ? Priority.high : Priority.max,
          // Hiển thị trên màn hình khóa với nội dung đầy đủ
          visibility: NotificationVisibility.public,
          // Bật âm thanh và rung
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          // Màu sắc
          color: event.color,
          // BigText để hiện đủ nội dung
          styleInformation: BigTextStyleInformation(
            _buildBody(event),
            contentTitle: event.title,
            summaryText: 'Lịch Việt',
          ),
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
          icon: '@mipmap/ic_launcher',
          // fullScreenIntent: tắt để tránh crash trên một số thiết bị
          // Đã test thấy fullScreenIntent có thể gây crash nếu thiếu quyền
          fullScreenIntent: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      // Chọn schedule mode tốt nhất
      final mode = await _scheduleMode();

      await _plugin.zonedSchedule(
        notifId,
        event.title,
        _buildBody(event),
        tzTime,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: event.id,
      );

      debugPrint('[Notif] ✅ Scheduled id=$notifId mode=$mode time=$tzTime');
      return notifTime;
    } catch (e, stackTrace) {
      debugPrint('[Notif] ❌ Error scheduling event "${event.title}": $e');
      debugPrint('[Notif] Stack trace: $stackTrace');
      return null;
    }
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    if (Platform.isIOS) return AndroidScheduleMode.exactAllowWhileIdle;

    // Giống Google Calendar: dùng AlarmManager thay vì foreground service
    // alarmClock mode = setAlarmClock() - EXEMPT từ Doze mode
    // Không cần app chạy - hệ thống Android tự hiển thị notification
    // Tương tự như Google Calendar, không cần foreground service
    
    if (_sdkVersion >= 33) {
      // Android 13+: USE_EXACT_ALARM auto-granted, alarmClock hoạt động tốt nhất
      debugPrint('[Notif] Using alarmClock mode (Android 13+, like Google Calendar)');
      return AndroidScheduleMode.alarmClock;
    }

    if (_sdkVersion < 31) {
      // Android 9-11 (SDK 28-30): alarmClock hoạt động tốt, không cần permission
      debugPrint('[Notif] Using alarmClock mode (Android 9-11, like Google Calendar)');
      return AndroidScheduleMode.alarmClock;
    }

    // Android 12 (SDK 31-32): cần SCHEDULE_EXACT_ALARM permission
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await ap?.canScheduleExactNotifications() ?? false;
    
    if (canExact) {
      debugPrint('[Notif] Using alarmClock mode (Android 12 with exact alarm, like Google Calendar)');
      return AndroidScheduleMode.alarmClock;
    } else {
      debugPrint('[Notif] WARNING: Using inexact mode - notifications may be delayed');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  // ─── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelEventNotification(String eventId) async {
    final id = eventId.hashCode.abs() % 2147483647;
    await _plugin.cancel(id);
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
          'viet_calendar_events',
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
      
      final mode = await _scheduleMode();
      debugPrint('[Notif] Schedule mode: $mode');
      
      final testTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      debugPrint('[Notif] Test time: $testTime');

      final androidDetails = AndroidNotificationDetails(
        'viet_calendar_events',
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
      rethrow;
    }
  }

  // ─── Time calculation ──────────────────────────────────────────────────────

  DateTime? _calcNotifTime(CalendarEvent event) {
    final d = event.date;
    final minsBefore = event.notificationMinutesBefore ?? 30;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(d.year, d.month, d.day);

    // Sự kiện đã qua → không nhắc
    if (eventDay.isBefore(today)) return null;

    DateTime notifTime;

    if (event.startTime != null) {
      // Sự kiện có giờ → nhắc trước N phút
      final startDt = DateTime(d.year, d.month, d.day,
          event.startTime!.hour, event.startTime!.minute);
      notifTime = startDt.subtract(Duration(minutes: minsBefore));

      // Nếu thời điểm nhắc đã qua nhưng sự kiện chưa bắt đầu → nhắc ngay
      if (notifTime.isBefore(now) && startDt.isAfter(now)) {
        notifTime = now.add(const Duration(minutes: 1));
      } else if (notifTime.isBefore(now)) {
        return null; // Đã qua rồi
      }
    } else {
      // Cả ngày → nhắc 8h sáng
      final prevDay = minsBefore >= 1440
          ? d.subtract(const Duration(days: 1))
          : d;
      notifTime = DateTime(prevDay.year, prevDay.month, prevDay.day, 8, 0);

      // 8h sáng đã qua nhưng sự kiện hôm nay → nhắc ngay sau 1 phút
      if (notifTime.isBefore(now) && !eventDay.isBefore(today)) {
        notifTime = now.add(const Duration(minutes: 1));
      } else if (notifTime.isBefore(now)) {
        return null;
      }
    }

    return notifTime;
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
