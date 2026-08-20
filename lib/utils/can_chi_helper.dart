/// Tính Can Chi (Thiên Can + Địa Chi) cho ngày/tháng/năm/giờ
/// và Giờ Hoàng Đạo theo âm lịch Việt Nam
class CanChiHelper {
  // ─── Bảng tra ──────────────────────────────────────────────────────────────

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

  // ─── Năm ───────────────────────────────────────────────────────────────────

  static String namCanChi(int lunarYear) {
    final can = thienCan[lunarYear % 10];
    final chi = diaChi[lunarYear % 12];
    return '$can $chi';
  }

  // ─── Tháng âm lịch ─────────────────────────────────────────────────────────
  // Thiên can tháng phụ thuộc vào Thiên can năm

  static String thangCanChi(int lunarMonth, int lunarYear) {
    // Can tháng giêng (tháng 1) theo can năm:
    // Giáp/Kỷ năm → tháng 1 = Bính Dần
    // Ất/Canh năm → tháng 1 = Mậu Dần
    // Bính/Tân năm → tháng 1 = Canh Dần
    // Đinh/Nhâm năm → tháng 1 = Nhâm Dần
    // Mậu/Quý năm → tháng 1 = Giáp Dần
    final yearCanIndex = lunarYear % 10; // 0=Giáp…9=Quý
    final baseCanForMonth1 = [2, 4, 6, 8, 0, 2, 4, 6, 8, 0][yearCanIndex];
    final monthCanIndex = (baseCanForMonth1 + (lunarMonth - 1)) % 10;
    // Chi tháng bắt đầu từ Dần (index 2) cho tháng 1
    final monthChiIndex = (2 + (lunarMonth - 1)) % 12;
    return '${thienCan[monthCanIndex]} ${diaChi[monthChiIndex]}';
  }

  // ─── Ngày dương lịch ────────────────────────────────────────────────────────
  // Dựa trên số ngày Julius

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

  static String ngayCanChi(DateTime date) {
    final jd = _dateToJd(date.day, date.month, date.year);
    // Ngày Julian 0 = Giáp Tý (theo quy ước)
    final canIndex = (jd + 40) % 10;
    final chiIndex = (jd + 12) % 12;
    return '${thienCan[canIndex]} ${diaChi[chiIndex]}';
  }

  // ─── Giờ ────────────────────────────────────────────────────────────────────
  // Mỗi Chi = 2 tiếng đồng hồ; Tý = 23:00-01:00

  static int _hourToChi(int hour) {
    // Tý: 23-1, Sửu: 1-3, Dần: 3-5, ...
    return ((hour + 1) ~/ 2) % 12;
  }

  static String gioCanChi(int hour, DateTime date) {
    final jd = _dateToJd(date.day, date.month, date.year);
    final ngayCanIndex = (jd + 40) % 10;
    final chiIndex = _hourToChi(hour);
    // Can giờ Tý phụ thuộc can ngày:
    // Giáp/Kỷ → Tý giờ = Giáp Tý
    // Ất/Canh → Tý giờ = Bính Tý
    // Bính/Tân → Tý giờ = Mậu Tý
    // Đinh/Nhâm → Tý giờ = Canh Tý
    // Mậu/Quý → Tý giờ = Nhâm Tý
    final baseGioCanForTy = [0, 2, 4, 6, 8, 0, 2, 4, 6, 8][ngayCanIndex];
    final gioCanIndex = (baseGioCanForTy + chiIndex * 2) % 10;
    return '${thienCan[gioCanIndex]} ${diaChi[chiIndex]}';
  }

  static String currentGioCanChi(DateTime now) =>
      gioCanChi(now.hour, now);

  // ─── Tên giờ (Chi) ──────────────────────────────────────────────────────────

  static String tenGio(int hour) {
    const names = [
      'Tý', 'Sửu', 'Dần', 'Mão', 'Thìn', 'Tỵ',
      'Ngọ', 'Mùi', 'Thân', 'Dậu', 'Tuất', 'Hợi',
    ];
    return names[_hourToChi(hour)];
  }

  // ─── Giờ Hoàng Đạo ─────────────────────────────────────────────────────────
  // 6 giờ hoàng đạo (tốt) trong ngày, phụ thuộc Can ngày
  // Pattern theo dân gian VN:

  static const List<List<int>> _hoangDaoPattern = [
    // Index can ngày (0=Giáp, 1=Ất, ...) → list chi index giờ hoàng đạo
    [0, 3, 5, 6, 9, 11],  // Giáp: Tý Mão Tỵ Ngọ Dậu Hợi
    [2, 3, 5, 8, 9, 11],  // Ất:  Dần Mão Tỵ Thân Dậu Hợi
    [0, 1, 4, 6, 7, 10],  // Bính: Tý Sửu Thìn Ngọ Mùi Tuất
    [0, 1, 4, 6, 7, 10],  // Đinh: Tý Sửu Thìn Ngọ Mùi Tuất
    [2, 3, 5, 8, 9, 11],  // Mậu: Dần Mão Tỵ Thân Dậu Hợi
    [0, 3, 5, 6, 9, 11],  // Kỷ:  Tý Mão Tỵ Ngọ Dậu Hợi
    [0, 1, 4, 6, 7, 10],  // Canh: Tý Sửu Thìn Ngọ Mùi Tuất
    [2, 3, 5, 8, 9, 11],  // Tân: Dần Mão Tỵ Thân Dậu Hợi
    [0, 3, 5, 6, 9, 11],  // Nhâm: Tý Mão Tỵ Ngọ Dậu Hợi
    [2, 3, 5, 8, 9, 11],  // Quý: Dần Mão Tỵ Thân Dậu Hợi
  ];

  /// Trả về list tên Chi của các giờ hoàng đạo trong ngày
  static List<String> gioHoangDao(DateTime date) {
    final jd = _dateToJd(date.day, date.month, date.year);
    final canIndex = (jd + 40) % 10;
    return _hoangDaoPattern[canIndex]
        .map((i) => diaChi[i])
        .toList();
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
    // ISO week: tuần bắt đầu từ thứ Hai
    final weekday = date.weekday; // 1=Mon…7=Sun
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

  /// Chuyển số ngày âm lịch sang Hán tự
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
