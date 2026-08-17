import 'package:flutter_test/flutter_test.dart';
import 'package:viet_calendar/utils/lunar_converter.dart';

void main() {
  group('LunarConverter', () {
    test('Chuyển đổi ngày Tết Nguyên Đán 2025 (29/1/2025 = 1/1 Ất Tỵ)', () {
      final solar = DateTime(2025, 1, 29);
      final lunar = LunarConverter.solarToLunar(solar);
      expect(lunar.day, equals(1));
      expect(lunar.month, equals(1));
      expect(lunar.year, equals(2025));
    });

    test('Chuyển đổi ngày rằm tháng 7 - 2024 (18/8/2024)', () {
      final solar = DateTime(2024, 8, 18);
      final lunar = LunarConverter.solarToLunar(solar);
      expect(lunar.day, equals(15));
      expect(lunar.month, equals(7));
    });

    test('Chuyển đổi ngày Trung Thu 2024 (17/9/2024)', () {
      final solar = DateTime(2024, 9, 17);
      final lunar = LunarConverter.solarToLunar(solar);
      expect(lunar.day, equals(15));
      expect(lunar.month, equals(8));
    });

    test('Lấy tên năm âm lịch Ất Tỵ (2025)', () {
      final name = LunarConverter.getLunarYearName(2025);
      expect(name, equals('Ất Tỵ'));
    });

    test('Lấy tên năm âm lịch Giáp Thìn (2024)', () {
      final name = LunarConverter.getLunarYearName(2024);
      expect(name, equals('Giáp Thìn'));
    });

    test('Con giáp Tỵ (2025)', () {
      expect(LunarConverter.getZodiacYear(2025), equals('Tỵ'));
    });

    test('Con giáp Thìn (2024)', () {
      expect(LunarConverter.getZodiacYear(2024), equals('Thìn'));
    });

    test('Ngày 1/1/2024 dương lịch = ngày âm lịch đúng', () {
      final solar = DateTime(2024, 1, 1);
      final lunar = LunarConverter.solarToLunar(solar);
      // 1/1/2024 dương = 20/11/2023 âm
      expect(lunar.month, equals(11));
      expect(lunar.day, equals(20));
      expect(lunar.year, equals(2023));
    });

    test('Giao thừa Tết 2026 (16/2/2026 = 29/12 Ất Tỵ)', () {
      final solar = DateTime(2026, 2, 16);
      final lunar = LunarConverter.solarToLunar(solar);
      expect(lunar.month, equals(12));
      expect(lunar.year, equals(2025));
    });
  });
}
