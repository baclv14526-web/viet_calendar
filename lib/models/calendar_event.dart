import 'package:flutter/material.dart';

enum EventType {
  personal,    // Sự kiện cá nhân
  holiday,     // Ngày lễ quốc gia
  lunarHoliday, // Ngày lễ âm lịch
  reminder,    // Nhắc nhở
}

enum RepeatType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
}

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final EventType type;
  final RepeatType repeatType;
  final Color color;
  final bool hasNotification;
  final int? notificationMinutesBefore;
  final bool isAllDay;
  final bool isLunarBased; // Sự kiện theo âm lịch
  final int? lunarDay;
  final int? lunarMonth;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.startTime,
    this.endTime,
    this.type = EventType.personal,
    this.repeatType = RepeatType.none,
    this.color = const Color(0xFF2196F3),
    this.hasNotification = true,
    this.notificationMinutesBefore = 30,
    this.isAllDay = false,
    this.isLunarBased = false,
    this.lunarDay,
    this.lunarMonth,
  });

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    EventType? type,
    RepeatType? repeatType,
    Color? color,
    bool? hasNotification,
    int? notificationMinutesBefore,
    bool? isAllDay,
    bool? isLunarBased,
    int? lunarDay,
    int? lunarMonth,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      repeatType: repeatType ?? this.repeatType,
      color: color ?? this.color,
      hasNotification: hasNotification ?? this.hasNotification,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
      isAllDay: isAllDay ?? this.isAllDay,
      isLunarBased: isLunarBased ?? this.isLunarBased,
      lunarDay: lunarDay ?? this.lunarDay,
      lunarMonth: lunarMonth ?? this.lunarMonth,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'startTimeHour': startTime?.hour,
      'startTimeMinute': startTime?.minute,
      'endTimeHour': endTime?.hour,
      'endTimeMinute': endTime?.minute,
      'type': type.index,
      'repeatType': repeatType.index,
      'color': color.value,
      'hasNotification': hasNotification ? 1 : 0,
      'notificationMinutesBefore': notificationMinutesBefore,
      'isAllDay': isAllDay ? 1 : 0,
      'isLunarBased': isLunarBased ? 1 : 0,
      'lunarDay': lunarDay,
      'lunarMonth': lunarMonth,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      startTime: map['startTimeHour'] != null
          ? TimeOfDay(
              hour: map['startTimeHour'] as int,
              minute: map['startTimeMinute'] as int)
          : null,
      endTime: map['endTimeHour'] != null
          ? TimeOfDay(
              hour: map['endTimeHour'] as int,
              minute: map['endTimeMinute'] as int)
          : null,
      type: EventType.values[map['type'] as int],
      repeatType: RepeatType.values[map['repeatType'] as int],
      color: Color(map['color'] as int),
      hasNotification: (map['hasNotification'] as int) == 1,
      notificationMinutesBefore: map['notificationMinutesBefore'] as int?,
      isAllDay: (map['isAllDay'] as int) == 1,
      isLunarBased: (map['isLunarBased'] as int) == 1,
      lunarDay: map['lunarDay'] as int?,
      lunarMonth: map['lunarMonth'] as int?,
    );
  }
}
