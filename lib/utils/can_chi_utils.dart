import '../utils/lunar_converter.dart';

/// Tiện ích tính Can Chi và Giờ Hoàng Đạo
class CanChiUtils {
  static const List<String> _stems = [
    'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu',
    'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý',
  ];

  static const List<String> _branches = [
    'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ',
    'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
  ];

  // Giờ tương ứng từng địa chi
  static const List<String> _branchHours = [
    '23-01', '01-03', '03-05', '05-07', '07-09', '09-11',
    '11-13', '13-15', '15-17', '17-19', '19-21', '21-23',
  ];

  // ─── Số ngày Julian ──────────────────────────────────────────────────────

  static int _dateToJdn(int day, int month, int year) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  // ─── Can Chi ngày ────────────────────────────────────────────────────────

  static int dayStemIndex(DateTime date) {
    final jdn = _dateToJdn(date.day, date.month, date.year);
    return (jdn + 8) % 10;
  }

  static int dayBranchIndex(DateTime date) {
    final jdn = _dateToJdn(date.day, date.month, date.year);
    return (jdn + 2) % 12;
  }

  static String dayStem(DateTime date) => _stems[dayStemIndex(date)];
  static String dayBranch(DateTime date) => _branches[dayBranchIndex(date)];
  static String dayCanChi(DateTime date) =>
      '${dayStem(date)} ${dayBranch(date)}';

  // ─── Can Chi tháng âm lịch ───────────────────────────────────────────────

  static int _monthStemBase(int lunarYear) {
    final ys = lunarYear % 10;
    // Giáp/Kỷ → Bính(2), Ất/Canh → Mậu(4), Bính/Tân → Canh(6),
    // Đinh/Nhâm → Nhâm(8), Mậu/Quý → Giáp(0)
    const bases = [2, 4, 6, 8, 0, 2, 4, 6, 8, 0];
    return bases[ys];
  }

  static String monthCanChi(DateTime solar) {
    final lunar = LunarConverter.solarToLunar(solar);
    final stemIdx =
        (_monthStemBase(lunar.year) + lunar.month - 1) % 10;
    final branchIdx = (lunar.month + 1) % 12; // Tháng 1 = Dần (2)
    return '${_stems[stemIdx]} ${_branches[branchIdx]}';
  }

  // ─── Can Chi giờ hiện tại ────────────────────────────────────────────────

  static int hourBranchIndex(int hour) {
    // Tý: 23-01, Sửu: 01-03, ...
    return (hour == 23 ? 0 : (hour + 1) ~/ 2) % 12;
  }

  static String hourCanChi(DateTime date) {
    final dayStem = dayStemIndex(date);
    // Giáp/Kỷ → Tý giờ = Giáp(0), Ất/Canh → Bính(2), Bính/Tân → Mậu(4),
    // Đinh/Nhâm → Canh(6), Mậu/Quý → Nhâm(8)
    const hourStemBases = [0, 2, 4, 6, 8, 0, 2, 4, 6, 8];
    final base = hourStemBases[dayStem];
    final hBranch = hourBranchIndex(date.hour);
    final stemIdx = (base + hBranch) % 10;
    return '${_stems[stemIdx]} ${_branches[hBranch]}';
  }

  // ─── Giờ Hoàng Đạo ───────────────────────────────────────────────────────

  /// 6 giờ hoàng đạo của ngày, trả về list branch index
  static List<int> _hoangDaoBranches(int dayBranch) {
    // Bảng giờ hoàng đạo theo địa chi ngày
    // Mỗi ngày có 6 giờ tốt (Thanh Long, Minh Đường, Kim Quỹ,
    // Bảo Quang, Ngọc Đường, Tư Mệnh)
    const table = [
      [0, 1, 3, 6, 8, 9],   // Tý
      [2, 3, 5, 8, 10, 11], // Sửu
      [4, 5, 7, 10, 0, 1],  // Dần
      [6, 7, 9, 0, 2, 3],   // Mão
      [8, 9, 11, 2, 4, 5],  // Thìn
      [10, 11, 1, 4, 6, 7], // Tỵ
      [0, 1, 3, 6, 8, 9],   // Ngọ  (giống Tý)
      [2, 3, 5, 8, 10, 11], // Mùi  (giống Sửu)
      [4, 5, 7, 10, 0, 1],  // Thân (giống Dần)
      [6, 7, 9, 0, 2, 3],   // Dậu  (giống Mão)
      [8, 9, 11, 2, 4, 5],  // Tuất (giống Thìn)
      [10, 11, 1, 4, 6, 7], // Hợi  (giống Tỵ)
    ];
    return table[dayBranch % 12];
  }

  /// Trả về list tên giờ hoàng đạo kèm giờ cụ thể
  static List<HoangDaoHour> getHoangDaoHours(DateTime date) {
    final dayBranch = dayBranchIndex(date);
    final branches = _hoangDaoBranches(dayBranch);
    return branches.map((b) {
      return HoangDaoHour(
        branch: _branches[b],
        timeRange: _branchHours[b],
        isCurrentHour: b == hourBranchIndex(date.hour),
      );
    }).toList();
  }

  /// Kiểm tra giờ hiện tại có phải giờ hoàng đạo không
  static bool isCurrentHourHoangDao(DateTime date) {
    final dayBranch = dayBranchIndex(date);
    final branches = _hoangDaoBranches(dayBranch);
    return branches.contains(hourBranchIndex(date.hour));
  }

  // ─── Ngày Hoàng Đạo / Hắc Đạo ───────────────────────────────────────────

  /// Ngày hoàng đạo theo địa chi ngày
  /// Tý, Sửu, Thìn, Tỵ, Thân, Hợi = hoàng đạo
  static bool isDayHoangDao(DateTime date) {
    final b = dayBranchIndex(date);
    return [0, 1, 4, 5, 8, 11].contains(b);
  }

  // ─── Ngày trong năm, số tuần ─────────────────────────────────────────────

  static int dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  }

  static int weekOfYear(DateTime date) {
    final firstMonday = _firstMondayOfYear(date.year);
    if (date.isBefore(firstMonday)) {
      return weekOfYear(DateTime(date.year - 1, 12, 31));
    }
    return date.difference(firstMonday).inDays ~/ 7 + 1;
  }

  static DateTime _firstMondayOfYear(int year) {
    var d = DateTime(year, 1, 1);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  // ─── Thứ tiếng Việt ──────────────────────────────────────────────────────

  static String weekdayVi(int weekday) {
    const names = [
      'Thứ Hai', 'Thứ Ba', 'Thứ Tư',
      'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
    ];
    return names[(weekday - 1) % 7];
  }

  // ─── Danh ngôn theo ngày ─────────────────────────────────────────────────

  static const List<String> _quotes = [
    'Có công mài sắt, có ngày nên kim.',
    'Uống nước nhớ nguồn.',
    'Học ăn, học nói, học gói, học mở.',
    'Một con ngựa đau, cả tàu bỏ cỏ.',
    'Bầu ơi thương lấy bí cùng.',
    'Lời nói chẳng mất tiền mua, lựa lời mà nói cho vừa lòng nhau.',
    'Trăm năm bia đá thì mòn, ngàn năm bia miệng hãy còn trơ trơ.',
    'Cần cù bù thông minh.',
    'Thương người như thể thương thân.',
    'Đi một ngày đàng, học một sàng khôn.',
    'Gần mực thì đen, gần đèn thì sáng.',
    'Chớ thấy sóng cả mà ngã tay chèo.',
    'Kiến tha lâu cũng đầy tổ.',
    'Gieo gió thì gặt bão.',
    'Ăn quả nhớ kẻ trồng cây.',
    'Không có gì là không thể làm được nếu chịu khó.',
    'Biết thì thưa thốt, không biết thì dựa cột mà nghe.',
    'Nhất cử lưỡng tiện.',
    'Dạy con từ thuở còn thơ.',
    'Ở hiền gặp lành.',
    'Mưu sự tại nhân, thành sự tại thiên.',
    'Thắng không kiêu, bại không nản.',
    'Tiên trách kỷ, hậu trách nhân.',
    'Học thầy không tày học bạn.',
    'Miệng nam mô lòng dao kiếm.',
    'Chí công vô tư.',
    'Nhân vô thập toàn.',
    'Nước chảy đá mòn.',
    'Thời gian là vàng bạc.',
    'Sống để học, học để sống.',
  ];

  static String quoteOfDay(DateTime date) {
    final idx = (date.year * 366 + dayOfYear(date)) % _quotes.length;
    return _quotes[idx];
  }
}

class HoangDaoHour {
  final String branch;
  final String timeRange;
  final bool isCurrentHour;

  const HoangDaoHour({
    required this.branch,
    required this.timeRange,
    required this.isCurrentHour,
  });
}
