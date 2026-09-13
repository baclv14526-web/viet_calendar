/// Tính Can Chi (Thiên Can + Địa Chi) cho ngày/tháng/năm/giờ
/// và Giờ Hoàng Đạo theo âm lịch Việt Nam chuẩn xác
class CanChiHelper {
  // ─── Bảng tra Thiên Can & Địa Chi tiếng Việt ────────────────────────────────

  static const List<String> thienCan = [
    'Giáp', 'Ất', 'Bính', 'Đinh', 'Mậu',
    'Kỷ', 'Canh', 'Tân', 'Nhâm', 'Quý',
  ];

  static const List<String> diaChi = [
    'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ',
    'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
  ];

  static const List<String> chiNames = [
    'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ',
    'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
  ];

  // ─── Bảng tra Thiên Can & Địa Chi chữ Hán ──────────────────────────────────

  static const List<String> thienCanHan = [
    '甲', '乙', '丙', '丁', '戊',
    '己', '庚', '辛', '壬', '癸',
  ];

  static const List<String> diaChiHan = [
    '子', '丑', '寅', '卯', '辰', '巳',
    '午', '未', '申', '酉', '戌', '亥',
  ];

  // ─── Năm Can Chi ───────────────────────────────────────────────────────────
  // Can năm = (Năm + 6) % 10 (0: Giáp, 1: Ất, 2: Bính, ..., 2026 -> Bính)
  // Chi năm = (Năm + 8) % 12 (0: Tý, ..., 6: Ngọ, ..., 2026 -> Ngọ)

  static int getYearCanIndex(int lunarYear) => (lunarYear + 6) % 10;
  static int getYearChiIndex(int lunarYear) => (lunarYear + 8) % 12;

  static String namCanChi(int lunarYear) {
    final canIndex = getYearCanIndex(lunarYear);
    final chiIndex = getYearChiIndex(lunarYear);
    return '${thienCan[canIndex]} ${diaChi[chiIndex]}';
  }

  static String namCanChiHan(int lunarYear) {
    final canIndex = getYearCanIndex(lunarYear);
    final chiIndex = getYearChiIndex(lunarYear);
    return '${thienCanHan[canIndex]}${diaChiHan[chiIndex]}年';
  }

  // ─── Tháng Can Chi ─────────────────────────────────────────────────────────
  // Thiên can tháng giêng (tháng 1) tính theo thiên can năm:
  // - Năm Giáp/Kỷ (can 0, 5) -> Bính Dần (can 2)
  // - Năm Ất/Canh (can 1, 6) -> Mậu Dần (can 4)
  // - Năm Bính/Tân (can 2, 7) -> Canh Dần (can 6)
  // - Năm Đinh/Nhâm (can 3, 8) -> Nhâm Dần (can 8)
  // - Năm Mậu/Quý (can 4, 9) -> Giáp Dần (can 0)

  static String thangCanChi(int lunarMonth, int lunarYear) {
    final yearCanIndex = getYearCanIndex(lunarYear);
    final baseCanForMonth1 = [2, 4, 6, 8, 0, 2, 4, 6, 8, 0][yearCanIndex];
    final monthCanIndex = (baseCanForMonth1 + (lunarMonth - 1)) % 10;
    // Tháng 1 âm luôn là Dần (index 2), tháng 2 là Mão (index 3), ...
    final monthChiIndex = (lunarMonth + 1) % 12;
    return '${thienCan[monthCanIndex]} ${diaChi[monthChiIndex]}';
  }

  static String thangCanChiHan(int lunarMonth, int lunarYear) {
    final yearCanIndex = getYearCanIndex(lunarYear);
    final baseCanForMonth1 = [2, 4, 6, 8, 0, 2, 4, 6, 8, 0][yearCanIndex];
    final monthCanIndex = (baseCanForMonth1 + (lunarMonth - 1)) % 10;
    final monthChiIndex = (lunarMonth + 1) % 12;
    return '${thienCanHan[monthCanIndex]}${diaChiHan[monthChiIndex]}月';
  }

  // ─── Ngày Can Chi ──────────────────────────────────────────────────────────
  // Tính dựa trên số ngày Julian (JDN) theo chuẩn thiên văn học Việt Nam

  static int _dateToJd(int day, int month, int year) {
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

  static int getNgayCanIndex(DateTime date) {
    final jd = _dateToJd(date.day, date.month, date.year);
    return (jd + 9) % 10;
  }

  static int getNgayChiIndex(DateTime date) {
    final jd = _dateToJd(date.day, date.month, date.year);
    return (jd + 1) % 12;
  }

  static String ngayCanChi(DateTime date) {
    final canIndex = getNgayCanIndex(date);
    final chiIndex = getNgayChiIndex(date);
    return '${thienCan[canIndex]} ${diaChi[chiIndex]}';
  }

  static String ngayCanChiHan(DateTime date) {
    final canIndex = getNgayCanIndex(date);
    final chiIndex = getNgayChiIndex(date);
    return '${thienCanHan[canIndex]}${diaChiHan[chiIndex]}日';
  }

  // ─── Giờ Can Chi ────────────────────────────────────────────────────────────
  // Mỗi Chi = 2 tiếng đồng hồ; Tý = 23:00-01:00
  // Can giờ Tý tính theo Can ngày:
  // - Ngày Giáp/Kỷ -> Giáp Tý (can 0)
  // - Ngày Ất/Canh -> Bính Tý (can 2)
  // - Ngày Bính/Tân -> Mậu Tý (can 4)
  // - Ngày Đinh/Nhâm -> Canh Tý (can 6)
  // - Ngày Mậu/Quý -> Nhâm Tý (can 8)

  static int _hourToChi(int hour) {
    // Tý: 23-1, Sửu: 1-3, Dần: 3-5, ...
    return ((hour + 1) ~/ 2) % 12;
  }

  static String gioCanChi(int hour, DateTime date) {
    final ngayCanIndex = getNgayCanIndex(date);
    final chiIndex = _hourToChi(hour);
    final baseGioCanForTy = [0, 2, 4, 6, 8, 0, 2, 4, 6, 8][ngayCanIndex];
    final gioCanIndex = (baseGioCanForTy + chiIndex) % 10;
    return '${thienCan[gioCanIndex]} ${diaChi[chiIndex]}';
  }

  static String currentGioCanChi(DateTime now) => gioCanChi(now.hour, now);

  // ─── Tên giờ (Chi) ──────────────────────────────────────────────────────────

  static String tenGio(int hour) {
    const names = [
      'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ',
      'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
    ];
    return names[_hourToChi(hour)];
  }

  // ─── Giờ Hoàng Đạo ─────────────────────────────────────────────────────────
  // 6 giờ hoàng đạo trong ngày tính theo Địa Chi của Ngày:
  // - Ngày Tý (0), Ngọ (6): Tý(0), Sửu(1), Mão(3), Ngọ(6), Thân(8), Dậu(9)
  // - Ngày Sửu (1), Mùi (7): Dần(2), Mão(3), Tỵ(5), Thân(8), Tuất(10), Hợi(11)
  // - Ngày Dần (2), Thân (8): Tý(0), Sửu(1), Thìn(4), Tỵ(5), Mùi(7), Tuất(10)
  // - Ngày Mão (3), Dậu (9): Tý(0), Dần(2), Mão(3), Ngọ(6), Mùi(7), Dậu(9)
  // - Ngày Thìn (4), Tuất (10): Dần(2), Thìn(4), Tỵ(5), Thân(8), Dậu(9), Hợi(11)
  // - Ngày Tỵ (5), Hợi (11): Sửu(1), Thìn(4), Ngọ(6), Mùi(7), Tuất(10), Hợi(11)

  static const Map<int, List<int>> _hoangDaoByDayChi = {
    0: [0, 1, 3, 6, 8, 9],
    6: [0, 1, 3, 6, 8, 9],
    1: [2, 3, 5, 8, 10, 11],
    7: [2, 3, 5, 8, 10, 11],
    2: [0, 1, 4, 5, 7, 10],
    8: [0, 1, 4, 5, 7, 10],
    3: [0, 2, 3, 6, 7, 9],
    9: [0, 2, 3, 6, 7, 9],
    4: [2, 4, 5, 8, 9, 11],
    10: [2, 4, 5, 8, 9, 11],
    5: [1, 4, 6, 7, 10, 11],
    11: [1, 4, 6, 7, 10, 11],
  };

  /// Trả về danh sách tên Chi của các giờ hoàng đạo trong ngày
  static List<String> gioHoangDao(DateTime date) {
    final chiIndex = getNgayChiIndex(date);
    final pattern = _hoangDaoByDayChi[chiIndex] ?? [0, 1, 4, 6, 7, 10];
    return pattern.map((i) => diaChi[i]).toList();
  }

  /// Kiểm tra giờ hiện tại có phải giờ hoàng đạo không
  static bool isHoangDao(DateTime now) {
    final hoangDao = gioHoangDao(now);
    final currentChi = diaChi[_hourToChi(now.hour)];
    return hoangDao.contains(currentChi);
  }

  // ─── Ngày/Tuần trong năm ────────────────────────────────────────────────────

  static int dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  static int weekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYearVal = date.difference(startOfYear).inDays;
    return ((dayOfYearVal + startOfYear.weekday - 1) ~/ 7) + 1;
  }

  // ─── Tên ngày tiếng Hán ─────────────────────────────────────────────────────

  static const List<String> thuHanTu = [
    '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日',
  ];

  static String thuTrongTuanHan(DateTime date) {
    return thuHanTu[date.weekday - 1];
  }

  // ─── Tháng Hán tự ───────────────────────────────────────────────────────────

  static const List<String> thangHan = [
    '正月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '腊月',
  ];

  static const List<String> thangHanSimple = [
    '一月', '二月', '三月', '四月', '五月', '六月',
    '七月', '八月', '九月', '十月', '十一月', '十二月',
  ];

  // ─── Số Hán tự ──────────────────────────────────────────────────────────────

  static const List<String> soHan = [
    '〇', '一', '二', '三', '四', '五', '六', '七', '八', '九',
    '十', '十一', '十二', '十三', '十四', '十五', '十六', '十七',
    '十八', '十九', '二十', '廿一', '廿二', '廿三', '廿四', '廿五',
    '廿六', '廿七', '廿八', '廿九', '三十',
  ];

  /// Chuyển số ngày âm lịch sang Hán tự (Sơ nhất, Sơ nhị, ...)
  static String ngayHan(int day) {
    if (day == 1) return '初一';
    if (day == 2) return '初二';
    if (day == 3) return '初三';
    if (day < 10) return '初${soHan[day]}';
    if (day == 10) return '初十';
    if (day < 20) return '十${soHan[day - 10]}';
    if (day == 20) return '二十';
    if (day < 30) return '廿${soHan[day - 20]}';
    return '三十';
  }

  // ─── Danh ngôn / Câu hay theo ngày ─────────────────────────────────────────

  static const List<String> _quotes = [
    'Thời gian là vàng bạc, đừng để trôi đi vô ích.',
    'Học, học nữa, học mãi. — Lênin',
    'Có chí thì nên. — Tục ngữ Việt Nam',
    'Uống nước nhớ nguồn. — Tục ngữ Việt Nam',
    'Một ngày không học, mười ngày trở nên tối tăm.',
    'Kiến tha lâu đầy tổ. — Tục ngữ Việt Nam',
    'Người không học như ngọc không mài.',
    'Đường dài hay biết ngựa hay, lâu ngày hay biết lòng người. — Tục ngữ',
    'Thất bại là mẹ thành công. — Tục ngữ',
    'Lửa thử vàng, gian nan thử sức. — Tục ngữ Việt Nam',
    'Học thầy không tày học bạn. — Tục ngữ',
    'Công danh là nợ anh hùng phải trả. — Nguyễn Công Trứ',
    'Cần cù bù thông minh. — Tục ngữ',
    'Trăm nghe không bằng một thấy. — Tục ngữ',
    'Tiên học lễ, hậu học văn. — Tục ngữ',
  ];

  static String quoteOfDay(DateTime date) {
    final idx = (date.day + date.month * 3 + date.year) % _quotes.length;
    return _quotes[idx];
  }
}
