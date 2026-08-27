import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
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
  
  // Platform channel để gọi foreground service
  static const _platform = MethodChannel('com.viet.lichviet/notification_service');
  
  // Getter để truy cập từ bên ngoài
  bool get isOppoOrRealme => _isOppoOrRealme;

  // ─── Khởi tạo ──────────────────────────────────────────────────────────────

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
    
    // Đối với Oppo/Realme, khởi động foreground service để giữ app chạy
    if (_isOppoOrRealme) {
      try {
        await _platform.invokeMethod('startForegroundService');
        debugPrint('[Notif] Foreground service started for Oppo/Realme');
      } catch (e) {
        debugPrint('[Notif] Failed to start foreground service: $e');
      }
    }
    
    _initialized = true;
    debugPrint('[Notif] Initialized OK, SDK=$_sdkVersion');
  }

  Future<void> _recreateChannels() async {
    final ap = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (ap == null) return;

    // KHÔNG xóa channel cũ vì sẽ hủy hết pending notifications
    // Thay vào đó tạo với ID mới (v2) mỗi khi cần nâng importance
    // User chỉ cần cài lại app là channel v1 cũ biến mất tự nhiên

    await ap.createNotificationChannel(const AndroidNotificationChannel(
      'event_channel_v2', // v2 để tránh bị cache importance thấp từ lần cài trước
      'Nhắc nhở sự kiện',
      description: 'Thông báo nhắc nhở các sự kiện trong lịch',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
      enableLights: true,
      ledColor: Color(0xFF1565C0),
    ));

    await ap.createNotificationChannel(const AndroidNotificationChannel(
      'holiday_channel_v2',
      'Ngày lễ & Sự kiện đặc biệt',
      description: 'Thông báo về các ngày lễ và sự kiện đặc biệt',
      importance: Importance.defaultImportance,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    ));

    debugPrint('[Notif] Channels ready');
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
        // Đọc lại sau khi request
        result['exactAlarm'] = (await ap?.canScheduleExactNotifications() ?? false);
      }
    } else {
      result['exactAlarm'] = true;
    }

    // 3. IGNORE_BATTERY_OPTIMIZATIONS — quan trọng nhất!
    //    Không có cái này alarm bị Doze mode tắt trên mọi máy
    //    Đặc biệt quan trọng trên Oppo/Realme với ColorOS
    final batteryStatus =
        await Permission.ignoreBatteryOptimizations.status;
    result['battery'] = batteryStatus.isGranted;
    if (!batteryStatus.isGranted) {
      // Đối với Oppo/Realme, cần mở cài đặt cụ thể của ColorOS
      if (_isOppoOrRealme) {
        debugPrint('[Notif] Oppo/Realme detected - opening ColorOS battery settings');
        await _openOppoBatterySettings();
      }
      
      await Permission.ignoreBatteryOptimizations.request();
      // Đọc lại sau khi request
      result['battery'] =
          (await Permission.ignoreBatteryOptimizations.status).isGranted;
    }

    // 4. USE_FULL_SCREEN_INTENT (Android 14+)
    // Dùng permission_handler để check, không có API riêng trong flutter_local_notifications
    if (_sdkVersion >= 34) {
      final status = await Permission.systemAlertWindow.status;
      result['fullScreen'] = status.isGranted;
    } else {
      result['fullScreen'] = true;
    }

    // 5. Đối với Oppo/Realme, kiểm tra thêm quyền tự khởi động
    if (_isOppoOrRealme) {
      result['autoStart'] = await _checkOppoAutoStart();
    } else {
      result['autoStart'] = true;
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
      result['autoStart'] = true;
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
    
    // Kiểm tra quyền tự khởi động cho Oppo/Realme
    if (_isOppoOrRealme) {
      result['autoStart'] = await _checkOppoAutoStart();
    } else {
      result['autoStart'] = true;
    }

    return result;
  }

  // ─── Oppo/Realme ColorOS Specific Methods ───────────────────────────────────

  /// Mở cài đặt pin của ColorOS cho Oppo/Realme
  Future<void> _openOppoBatterySettings() async {
    try {
      // Mở cài đặt pin chung trước
      await Permission.ignoreBatteryOptimizations.request();
      
      // Thử mở các activity cụ thể của ColorOS
      // Lưu ý: Có thể cần người dùng thao tác thủ công
      debugPrint('[Notif] Opening battery optimization settings');
    } catch (e) {
      debugPrint('[Notif] Error opening battery settings: $e');
    }
  }

  /// Kiểm tra quyền tự khởi động trên Oppo/Realme
  /// Lưu ý: Không có API chính thức, chỉ có thể hướng dẫn người dùng
  Future<bool> _checkOppoAutoStart() async {
    // Trả về true mặc định vì không có cách kiểm tra chính xác
    // Sẽ hướng dẫn người dùng trong UI
    return true;
  }

  /// Lấy hướng dẫn cài đặt cho Oppo/Realme
  String getOppoRealmeGuide() {
    return '''
📱 Hướng dẫn cho Oppo/Realme (ColorOS):

1. Bật thông báo:
   Cài đặt → Thông báo → Lịch Việt → Bật "Cho phép thông báo"

2. Bỏ qua tối ưu pin (QUAN TRỌNG NHẤT):
   Cài đặt → Pin → Tiết kiệm pin → Lịch Việt → Chọn "Không hạn chế"
   
   HOẶC:
   Cài đặt → Ứng dụng → Lịch Việt → Pin → Bỏ qua tối ưu hóa

3. Bật tự khởi động:
   Cài đặt → Ứng dụng → Lịch Việt → Quyền → Tự khởi động → Bật

4. Bật báo thức:
   Cài đặt → Ứng dụng → Quyền đặc biệt → Báo thức & nhắc nhở → Bật Lịch Việt

5. Cho phép chạy trong nền:
   Cài đặt → Ứng dụng → Lịch Việt → Chạy trong nền → Bật
''';
  }

  // ─── Lên lịch thông báo ────────────────────────────────────────────────────

  Future<void> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return;

    final notifTime = _calcNotifTime(event);
    if (notifTime == null) {
      debugPrint('[Notif] Bỏ qua: ${event.title}');
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
      isHoliday ? 'holiday_channel_v2' : 'event_channel_v2',
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
      'event_channel_v2',
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
      'event_channel_v2',
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

  /// Tính thời điểm gửi thông báo cho sự kiện.
  /// Trả về null nếu không thể tính được.
  /// KHÔNG bao giờ trả về thời gian trong quá khứ — tự điều chỉnh.
  DateTime? _calcNotifTime(CalendarEvent event) {
    final d = event.date;
    final minsBefore = event.notificationMinutesBefore ?? 30;
    final now = DateTime.now();

    DateTime notifTime;

    if (event.startTime != null) {
      // Sự kiện có giờ cụ thể → nhắc trước N phút
      final startDt = DateTime(
        d.year, d.month, d.day,
        event.startTime!.hour,
        event.startTime!.minute,
      );
      notifTime = startDt.subtract(Duration(minutes: minsBefore));
    } else if (event.isAllDay || event.startTime == null) {
      // Cả ngày hoặc không có giờ:
      // - Nếu nhắc 1 ngày trước (1440 phút): 8h sáng ngày hôm trước
      // - Còn lại: 8h sáng ngày đó
      if (minsBefore >= 1440) {
        // Dùng subtract thay vì day-1 để tránh bug ngày 1 tháng
        final prevDay = d.subtract(const Duration(days: 1));
        notifTime = DateTime(prevDay.year, prevDay.month, prevDay.day, 8, 0);
      } else {
        notifTime = DateTime(d.year, d.month, d.day, 8, 0);
      }
    } else {
      return null;
    }

    // Nếu thời gian tính được đã qua:
    // → Với sự kiện trong tương lai: thử nhắc ngay sau 1 phút
    // → Với sự kiện trong quá khứ: bỏ qua
    if (notifTime.isBefore(now)) {
      final eventDay = DateTime(d.year, d.month, d.day);
      final today = DateTime(now.year, now.month, now.day);

      if (eventDay.isAfter(today)) {
        // Sự kiện ngày mai trở đi nhưng giờ nhắc bị tính ra hôm nay đã qua
        // → nhắc ngay sau 2 phút
        notifTime = now.add(const Duration(minutes: 2));
      } else if (eventDay.isAtSameMomentAs(today)) {
        // Sự kiện hôm nay, giờ nhắc đã qua (vd: thêm lúc 9h cho sự kiện 8h)
        // → nhắc ngay sau 1 phút nếu sự kiện chưa bắt đầu
        if (event.startTime != null) {
          final startDt = DateTime(
            d.year, d.month, d.day,
            event.startTime!.hour, event.startTime!.minute,
          );
          if (startDt.isAfter(now)) {
            // Sự kiện chưa bắt đầu → nhắc ngay sau 1 phút
            notifTime = now.add(const Duration(minutes: 1));
          } else {
            // Sự kiện đã bắt đầu rồi → không nhắc
            debugPrint('[Notif] Sự kiện "${event.title}" đã bắt đầu, bỏ qua');
            return null;
          }
        } else {
          // Cả ngày hôm nay, giờ 8h đã qua → nhắc ngay sau 1 phút
          notifTime = now.add(const Duration(minutes: 1));
        }
      } else {
        // Sự kiện ngày hôm qua trở về trước → không nhắc
        debugPrint('[Notif] Sự kiện "${event.title}" đã qua ngày, bỏ qua');
        return null;
      }
    }

    return notifTime;
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
