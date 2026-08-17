import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../utils/lunar_converter.dart';

class VietnameseHolidays {
  /// Lấy tất cả ngày lễ trong một năm dương lịch
  static List<CalendarEvent> getHolidaysForYear(int year) {
    final List<CalendarEvent> holidays = [];

    // ============ NGÀY LỄ DƯƠNG LỊCH CỐ ĐỊNH ============

    // Tết Dương lịch - 1/1
    holidays.add(_createHoliday(
      id: 'new_year_$year',
      title: '🎆 Tết Dương Lịch',
      description: 'Ngày đầu năm mới theo dương lịch',
      date: DateTime(year, 1, 1),
      type: EventType.holiday,
      color: const Color(0xFFE91E63),
    ));

    // Ngày thành lập Đảng CSVN - 3/2
    holidays.add(_createHoliday(
      id: 'party_day_$year',
      title: '🔴 Ngày thành lập Đảng CSVN',
      description: 'Ngày thành lập Đảng Cộng sản Việt Nam (3/2/1930)',
      date: DateTime(year, 2, 3),
      type: EventType.holiday,
      color: const Color(0xFFD32F2F),
    ));

    // Ngày Quốc tế Phụ nữ - 8/3
    holidays.add(_createHoliday(
      id: 'women_day_$year',
      title: '🌹 Ngày Quốc tế Phụ nữ',
      description: 'International Women\'s Day - Tôn vinh phụ nữ toàn thế giới',
      date: DateTime(year, 3, 8),
      type: EventType.holiday,
      color: const Color(0xFFE91E63),
    ));

    // Ngày Giải phóng miền Nam - 30/4
    holidays.add(_createHoliday(
      id: 'liberation_day_$year',
      title: '🏳️ Ngày Giải Phóng Miền Nam',
      description: 'Ngày Thống nhất đất nước 30/4/1975',
      date: DateTime(year, 4, 30),
      type: EventType.holiday,
      color: const Color(0xFF4CAF50),
    ));

    // Ngày Quốc tế Lao động - 1/5
    holidays.add(_createHoliday(
      id: 'labor_day_$year',
      title: '⚙️ Ngày Quốc tế Lao Động',
      description: 'International Labour Day - Ngày của những người lao động',
      date: DateTime(year, 5, 1),
      type: EventType.holiday,
      color: const Color(0xFFFF5722),
    ));

    // Ngày Quốc khánh - 2/9
    holidays.add(_createHoliday(
      id: 'national_day_$year',
      title: '🇻🇳 Quốc Khánh Việt Nam',
      description:
          'Ngày Quốc khánh nước Cộng hòa Xã hội Chủ nghĩa Việt Nam (2/9/1945)',
      date: DateTime(year, 9, 2),
      type: EventType.holiday,
      color: const Color(0xFFD32F2F),
    ));

    // Ngày Phụ nữ Việt Nam - 20/10
    holidays.add(_createHoliday(
      id: 'vn_women_day_$year',
      title: '🌸 Ngày Phụ nữ Việt Nam',
      description: 'Ngày Phụ nữ Việt Nam 20/10 - Tôn vinh phụ nữ Việt',
      date: DateTime(year, 10, 20),
      type: EventType.holiday,
      color: const Color(0xFFFF4081),
    ));

    // Ngày Nhà giáo Việt Nam - 20/11
    holidays.add(_createHoliday(
      id: 'teacher_day_$year',
      title: '📚 Ngày Nhà Giáo Việt Nam',
      description: 'Ngày Nhà giáo Việt Nam 20/11 - Tôn vinh các thầy cô giáo',
      date: DateTime(year, 11, 20),
      type: EventType.holiday,
      color: const Color(0xFF3F51B5),
    ));

    // Ngày Quân đội Nhân dân - 22/12
    holidays.add(_createHoliday(
      id: 'army_day_$year',
      title: '⭐ Ngày Quân đội Nhân dân',
      description: 'Ngày thành lập Quân đội Nhân dân Việt Nam 22/12/1944',
      date: DateTime(year, 12, 22),
      type: EventType.holiday,
      color: const Color(0xFF4CAF50),
    ));

    // Giáng Sinh - 25/12
    holidays.add(_createHoliday(
      id: 'christmas_$year',
      title: '🎄 Giáng Sinh',
      description: 'Christmas Day - Lễ Giáng Sinh',
      date: DateTime(year, 12, 25),
      type: EventType.holiday,
      color: const Color(0xFFD32F2F),
    ));

    // ============ NGÀY LỄ ÂM LỊCH ============
    holidays.addAll(_getLunarHolidaysForYear(year));

    return holidays;
  }

  /// Ngày lễ âm lịch - tính theo từng năm dương lịch
  static List<CalendarEvent> _getLunarHolidaysForYear(int year) {
    final List<CalendarEvent> lunarHolidays = [];

    // Tết Nguyên Đán (1/1 âm lịch) - quét 2 năm để bắt hết
    for (int y = year - 1; y <= year; y++) {
      final tetDate = _findLunarDate(1, 1, y);
      if (tetDate != null && tetDate.year == year) {
        // Giao thừa (30 tháng Chạp)
        final giaothua = tetDate.subtract(const Duration(days: 1));
        lunarHolidays.add(_createHoliday(
          id: 'tet_eve_$year',
          title: '🎊 Giao Thừa Tết Nguyên Đán',
          description: 'Đêm giao thừa - 30 tháng Chạp âm lịch',
          date: giaothua,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFF6F00),
        ));

        // Mùng 1 Tết
        lunarHolidays.add(_createHoliday(
          id: 'tet_1_$year',
          title: '🧧 Mùng 1 Tết - ${LunarConverter.getLunarYearName(y + 1)}',
          description: 'Tết Nguyên Đán - Mùng 1 tháng Giêng âm lịch',
          date: tetDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFF0000),
        ));

        // Mùng 2, 3 Tết
        for (int i = 1; i <= 2; i++) {
          lunarHolidays.add(_createHoliday(
            id: 'tet_${i + 1}_$year',
            title: '🎉 Mùng ${i + 1} Tết',
            description: 'Tết Nguyên Đán - Ngày ${i + 1} tháng Giêng',
            date: tetDate.add(Duration(days: i)),
            type: EventType.lunarHoliday,
            color: const Color(0xFFFF1744),
          ));
        }
      }

      // Rằm tháng Giêng (15/1 âm lịch) - Tết Nguyên Tiêu
      final nguyenTieuDate = _findLunarDate(15, 1, y);
      if (nguyenTieuDate != null && nguyenTieuDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'nguyen_tieu_$year',
          title: '🏮 Rằm tháng Giêng - Tết Nguyên Tiêu',
          description: 'Ngày 15/1 âm lịch - Lễ hội đèn lồng',
          date: nguyenTieuDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFF8F00),
        ));
      }

      // Ngày Thần Tài (10/1 âm lịch)
      final thanTaiDate = _findLunarDate(10, 1, y);
      if (thanTaiDate != null && thanTaiDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'than_tai_$year',
          title: '💰 Ngày Thần Tài',
          description: 'Ngày 10/1 âm lịch - Ngày Thần Tài',
          date: thanTaiDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFFD600),
        ));
      }

      // Giỗ Tổ Hùng Vương (10/3 âm lịch)
      final hungVuongDate = _findLunarDate(10, 3, y);
      if (hungVuongDate != null && hungVuongDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'hung_vuong_$year',
          title: '👑 Giỗ Tổ Hùng Vương',
          description:
              'Ngày 10/3 âm lịch - Ngày Quốc lễ Giỗ Tổ Hùng Vương (Nghỉ bù)',
          date: hungVuongDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFF6D00),
        ));
      }

      // Tết Đoan Ngọ (5/5 âm lịch)
      final doanNgoDate = _findLunarDate(5, 5, y);
      if (doanNgoDate != null && doanNgoDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'doan_ngo_$year',
          title: '🍚 Tết Đoan Ngọ',
          description: 'Ngày 5/5 âm lịch - Tết giết sâu bọ',
          date: doanNgoDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFF6D4C41),
        ));
      }

      // Rằm tháng 7 - Vu Lan (15/7 âm lịch)
      final vuLanDate = _findLunarDate(15, 7, y);
      if (vuLanDate != null && vuLanDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'vu_lan_$year',
          title: '🙏 Lễ Vu Lan - Rằm tháng 7',
          description: 'Ngày 15/7 âm lịch - Lễ báo hiếu cha mẹ',
          date: vuLanDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFF7B1FA2),
        ));
      }

      // Tết Trung Thu (15/8 âm lịch)
      final trungThuDate = _findLunarDate(15, 8, y);
      if (trungThuDate != null && trungThuDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'trung_thu_$year',
          title: '🌕 Tết Trung Thu',
          description: 'Ngày 15/8 âm lịch - Tết thiếu nhi, ngắm trăng',
          date: trungThuDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFF8F00),
        ));
      }

      // Táo Quân về trời (23 tháng Chạp)
      final taoQuanDate = _findLunarDate(23, 12, y);
      if (taoQuanDate != null && taoQuanDate.year == year) {
        lunarHolidays.add(_createHoliday(
          id: 'tao_quan_$year',
          title: '🔥 Ông Táo Về Trời',
          description: 'Ngày 23 tháng Chạp âm lịch - Tiễn Táo Quân về trời',
          date: taoQuanDate,
          type: EventType.lunarHoliday,
          color: const Color(0xFFFF5722),
        ));
      }
    }

    return lunarHolidays;
  }

  /// Tìm ngày dương lịch tương ứng với ngày âm lịch
  static DateTime? _findLunarDate(int lunarDay, int lunarMonth, int lunarYear) {
    // Tìm khoảng thời gian dương lịch có thể chứa ngày âm lịch này
    // Âm lịch tháng 1 rơi vào khoảng Jan-Feb dương lịch
    // Thêm offset theo tháng để tìm kiếm hiệu quả hơn
    final startSearch = DateTime(lunarYear, lunarMonth > 2 ? lunarMonth - 2 : 1, 1);
    final endSearch = DateTime(lunarYear + 1, lunarMonth < 11 ? lunarMonth + 2 : 12, 31);

    for (DateTime d = startSearch;
        d.isBefore(endSearch);
        d = d.add(const Duration(days: 1))) {
      final lunar = LunarConverter.solarToLunar(d);
      if (lunar.day == lunarDay &&
          lunar.month == lunarMonth &&
          lunar.year == lunarYear) {
        return d;
      }
    }
    return null;
  }

  static CalendarEvent _createHoliday({
    required String id,
    required String title,
    String? description,
    required DateTime date,
    required EventType type,
    Color color = const Color(0xFFD32F2F),
  }) {
    return CalendarEvent(
      id: id,
      title: title,
      description: description,
      date: date,
      type: type,
      color: color,
      isAllDay: true,
      hasNotification: true,
      notificationMinutesBefore: 60 * 24, // 1 ngày trước
      repeatType: RepeatType.yearly,
    );
  }

  /// Kiểm tra có phải ngày lễ không
  static bool isHoliday(DateTime date, List<CalendarEvent> events) {
    return events.any((e) =>
        e.type == EventType.holiday || e.type == EventType.lunarHoliday);
  }
}
