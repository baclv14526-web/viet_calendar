import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/calendar_event.dart';

// Android API level constants
const int _androidQ = 29;   // Android 10 - fullScreenIntent
const int _androidS = 31;   // Android 12 - SCHEDULE_EXACT_ALARM
const int _androidT = 33;   // Android 13 - POST_NOTIFICATIONS runtime

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _androidSdkVersion = 0; // cache để dùng nhiều lần

  Future<void> initialize() async {
    if (_initialized) return;

    // Lấy Android SDK version để guard các API mới
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      _androidSdkVersion = info.version.sdkInt;
      debugPrint('[NotificationService] Android SDK: $_androidSdkVersion');
    }

    tz.initializeTimeZones();
    // Đặt múi giờ Việt Nam
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // Tạo notification channel cho Android
    await _createNotificationChannels();

    _initialized = true;
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Channel cho sự kiện thông thường
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'event_channel',
          'Nhắc nhở sự kiện',
          description: 'Thông báo nhắc nhở các sự kiện trong lịch',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ),
      );

      // Channel cho ngày lễ
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'holiday_channel',
          'Ngày lễ & Sự kiện đặc biệt',
          description: 'Thông báo về các ngày lễ và sự kiện đặc biệt',
          importance: Importance.defaultImportance,
          enableVibration: false,
          showBadge: true,
        ),
      );
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    debugPrint('Notification tapped: ${response.payload}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('Background notification tapped: ${response.payload}');
  }

  /// Yêu cầu quyền thông báo
  /// - Android 9-12 (API 28-32): KHÔNG cần xin runtime permission, tự động granted
  /// - Android 13+ (API 33+): Phải xin POST_NOTIFICATIONS
  /// - iOS: Luôn phải xin
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      // Android 9, 10, 11, 12 — không cần xin, luôn được phép
      if (_androidSdkVersion < _androidT) {
        debugPrint('[NotificationService] Android < 13, không cần xin quyền thông báo');
        return true;
      }
      // Android 13+
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    }

    // iOS
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Lên lịch thông báo cho một sự kiện
  Future<void> scheduleEventNotification(CalendarEvent event) async {
    if (!event.hasNotification) return;

    try {
      final notifTime = _getNotificationTime(event);
      if (notifTime == null) return;

      // Bỏ qua nếu thời gian đã qua
      if (notifTime.isBefore(DateTime.now())) return;

      final tzTime = tz.TZDateTime.from(notifTime, tz.local);

      final isHoliday = event.type == EventType.holiday ||
          event.type == EventType.lunarHoliday;

      // fullScreenIntent chỉ hỗ trợ Android 10+ (API 29+)
      // Android 9 dùng thông báo thường thay thế
      final useFullScreen = !isHoliday && _androidSdkVersion >= _androidQ;

      final androidDetails = AndroidNotificationDetails(
        isHoliday ? 'holiday_channel' : 'event_channel',
        isHoliday ? 'Ngày lễ & Sự kiện đặc biệt' : 'Nhắc nhở sự kiện',
        channelDescription: isHoliday
            ? 'Thông báo về các ngày lễ và sự kiện đặc biệt'
            : 'Thông báo nhắc nhở các sự kiện trong lịch',
        importance: isHoliday ? Importance.defaultImportance : Importance.high,
        priority: isHoliday ? Priority.defaultPriority : Priority.high,
        color: event.color,
        styleInformation: BigTextStyleInformation(
          event.description ?? '',
          contentTitle: event.title,
          summaryText: 'Lịch Việt',
        ),
        category: isHoliday
            ? AndroidNotificationCategory.event
            : AndroidNotificationCategory.reminder,
        fullScreenIntent: useFullScreen,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      AndroidScheduleMode scheduleMode;
      if (_androidSdkVersion >= _androidS) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final canScheduleExact =
            await androidPlugin?.canScheduleExactNotifications() ?? false;
        scheduleMode = canScheduleExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
      } else {
        // Android 9, 10, 11 — exact luôn hoạt động
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      }

      await _notifications.zonedSchedule(
        event.id.hashCode,
        event.title,
        _buildNotificationBody(event),
        tzTime,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: event.id,
      );
    } catch (e) {
      debugPrint('[NotificationService] scheduleEventNotification error: $e');
    }
  }

  /// Hủy thông báo của một sự kiện
  Future<void> cancelEventNotification(String eventId) async {
    try {
      await _notifications.cancel(eventId.hashCode);
    } catch (e) {
      debugPrint('[NotificationService] cancelEventNotification error: $e');
    }
  }

  /// Hủy tất cả thông báo
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('[NotificationService] cancelAllNotifications error: $e');
    }
  }

  /// Hiển thị thông báo ngay lập tức (để test)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    Color color = const Color(0xFF2196F3),
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'event_channel',
      'Nhắc nhở sự kiện',
      importance: Importance.high,
      priority: Priority.high,
      color: color,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  DateTime? _getNotificationTime(CalendarEvent event) {
    final eventDate = event.date;
    if (event.isAllDay || event.startTime == null) {
      final baseDate = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        8,
        0,
      );
      final minutesBefore = event.notificationMinutesBefore ?? 30;
      return baseDate.subtract(Duration(minutes: minutesBefore));
    }

    final eventDateTime = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      event.startTime!.hour,
      event.startTime!.minute,
    );
    return eventDateTime.subtract(
      Duration(minutes: event.notificationMinutesBefore ?? 30),
    );
  }

  String _buildNotificationBody(CalendarEvent event) {
    if (event.description != null && event.description!.isNotEmpty) {
      return event.description!;
    }

    if (event.isAllDay) {
      return 'Sự kiện cả ngày hôm nay';
    }

    if (event.startTime != null) {
      final h = event.startTime!.hour.toString().padLeft(2, '0');
      final m = event.startTime!.minute.toString().padLeft(2, '0');
      final mins = event.notificationMinutesBefore ?? 30;
      return 'Bắt đầu lúc $h:$m (còn $mins phút)';
    }

    return 'Nhắc nhở sự kiện';
  }
}
