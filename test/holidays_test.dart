import 'package:flutter_test/flutter_test.dart';
import 'package:viet_calendar/utils/vietnamese_holidays.dart';
import 'package:viet_calendar/models/calendar_event.dart';

void main() {
  group('VietnameseHolidays', () {
    late List<CalendarEvent> holidays2025;

    setUpAll(() {
      holidays2025 = VietnameseHolidays.getHolidaysForYear(2025);
    });

    test('Phải có đủ số ngày lễ', () {
      expect(holidays2025.length, greaterThanOrEqualTo(15));
    });

    test('Có Tết Dương lịch 1/1', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 1 && e.date.day == 1,
        orElse: () => throw Exception('Không tìm thấy Tết Dương lịch'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có ngày 8/3 Quốc tế Phụ nữ', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 3 && e.date.day == 8,
        orElse: () => throw Exception('Không tìm thấy 8/3'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có ngày 30/4 Giải phóng miền Nam', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 4 && e.date.day == 30,
        orElse: () => throw Exception('Không tìm thấy 30/4'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có ngày 1/5 Quốc tế Lao động', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 5 && e.date.day == 1,
        orElse: () => throw Exception('Không tìm thấy 1/5'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có ngày 2/9 Quốc khánh', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 9 && e.date.day == 2,
        orElse: () => throw Exception('Không tìm thấy 2/9'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có ngày 20/10 Phụ nữ Việt Nam', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 10 && e.date.day == 20,
        orElse: () => throw Exception('Không tìm thấy 20/10'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có ngày 20/11 Nhà giáo', () {
      final h = holidays2025.firstWhere(
        (e) => e.date.month == 11 && e.date.day == 20,
        orElse: () => throw Exception('Không tìm thấy 20/11'),
      );
      expect(h.type, equals(EventType.holiday));
    });

    test('Có Tết Nguyên Đán (âm lịch)', () {
      final tet = holidays2025.where(
        (e) => e.type == EventType.lunarHoliday && e.title.contains('Mùng 1'),
      );
      expect(tet, isNotEmpty);
    });

    test('Có Tết Trung Thu (âm lịch)', () {
      final trungThu = holidays2025.where(
        (e) => e.type == EventType.lunarHoliday && e.title.contains('Trung Thu'),
      );
      expect(trungThu, isNotEmpty);
    });

    test('Có Lễ Vu Lan (âm lịch)', () {
      final vuLan = holidays2025.where(
        (e) => e.type == EventType.lunarHoliday && e.title.contains('Vu Lan'),
      );
      expect(vuLan, isNotEmpty);
    });

    test('Tất cả ngày lễ có ID duy nhất', () {
      final ids = holidays2025.map((e) => e.id).toList();
      final uniqueIds = ids.toSet();
      expect(ids.length, equals(uniqueIds.length));
    });

    test('Tất cả ngày lễ đặt isAllDay = true', () {
      expect(holidays2025.every((h) => h.isAllDay), isTrue);
    });
  });
}
