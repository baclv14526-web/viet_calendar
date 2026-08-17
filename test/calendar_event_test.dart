import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_calendar/models/calendar_event.dart';

void main() {
  final testDate = DateTime(2025, 6, 15);

  group('CalendarEvent serialization', () {
    test('toMap và fromMap nhất quán', () {
      final event = CalendarEvent(
        id: 'test-123',
        title: 'Họp nhóm',
        description: 'Họp online lúc 9 giờ',
        date: testDate,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
        type: EventType.personal,
        repeatType: RepeatType.weekly,
        color: const Color(0xFF2196F3),
        hasNotification: true,
        notificationMinutesBefore: 15,
        isAllDay: false,
      );

      final map = event.toMap();
      final restored = CalendarEvent.fromMap(map);

      expect(restored.id, equals(event.id));
      expect(restored.title, equals(event.title));
      expect(restored.description, equals(event.description));
      expect(restored.type, equals(event.type));
      expect(restored.repeatType, equals(event.repeatType));
      expect(restored.hasNotification, equals(event.hasNotification));
      expect(restored.notificationMinutesBefore,
          equals(event.notificationMinutesBefore));
      expect(restored.isAllDay, equals(event.isAllDay));
      expect(restored.startTime?.hour, equals(9));
      expect(restored.endTime?.minute, equals(30));
    });

    test('copyWith thay đổi đúng field', () {
      final original = CalendarEvent(
        id: 'abc',
        title: 'Test',
        date: testDate,
        color: const Color(0xFF2196F3),
      );

      final updated = original.copyWith(title: 'Updated', isAllDay: true);

      expect(updated.id, equals('abc'));
      expect(updated.title, equals('Updated'));
      expect(updated.isAllDay, isTrue);
      expect(updated.color, equals(const Color(0xFF2196F3)));
    });

    test('Event không có mô tả - nullable description', () {
      final event = CalendarEvent(
        id: 'no-desc',
        title: 'Không có mô tả',
        date: testDate,
        color: const Color(0xFF4CAF50),
      );
      final map = event.toMap();
      final restored = CalendarEvent.fromMap(map);
      expect(restored.description, isNull);
    });

    test('Event âm lịch lưu lunarDay và lunarMonth', () {
      final event = CalendarEvent(
        id: 'lunar-1',
        title: 'Rằm tháng 7',
        date: testDate,
        color: const Color(0xFF9C27B0),
        isLunarBased: true,
        lunarDay: 15,
        lunarMonth: 7,
      );
      final map = event.toMap();
      final restored = CalendarEvent.fromMap(map);
      expect(restored.isLunarBased, isTrue);
      expect(restored.lunarDay, equals(15));
      expect(restored.lunarMonth, equals(7));
    });
  });
}
