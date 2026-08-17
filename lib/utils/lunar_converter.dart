import '../models/lunar_date.dart';
import 'dart:math';

/// Chuyển đổi giữa Dương lịch và Âm lịch Việt Nam
/// Thuật toán dựa trên múi giờ GMT+7 (Việt Nam)
class LunarConverter {
  static const int _timeZone = 7; // GMT+7

  /// Chuyển ngày Julian sang dương lịch
  static Map<String, int> _jdToDate(int jd) {
    int a = jd + 32044;
    int b = (4 * a + 3) ~/ 146097;
    int c = a - (b * 146097) ~/ 4;
    int d = (4 * c + 3) ~/ 1461;
    int e = c - (1461 * d) ~/ 4;
    int m = (5 * e + 2) ~/ 153;
    int day = e - (153 * m + 2) ~/ 5 + 1;
    int month = m + 3 - 12 * (m ~/ 10);
    int year = b * 100 + d - 4800 + m ~/ 10;
    return {'day': day, 'month': month, 'year': year};
  }

  /// Chuyển dương lịch sang số ngày Julian
  static int _dateToJd(int day, int month, int year) {
    int a = (14 - month) ~/ 12;
    int y = year + 4800 - a;
    int m = month + 12 * a - 3;
    int jd = day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
    return jd;
  }

  /// Tính số ngày Julian của điểm sóc (New Moon) thứ k
  static double _newMoon(int k) {
    double T = k / 1236.85;
    double T2 = T * T;
    double T3 = T2 * T;
    double dr = pi / 180;
    double Jd1 = 2415020.75933 +
        29.53058868 * k +
        0.0001178 * T2 -
        0.000000155 * T3;
    Jd1 = Jd1 +
        0.00033 *
            sin((166.56 + 132.87 * T - 0.009173 * T2) * dr);
    double M = 359.2242 +
        29.10535608 * k -
        0.0000333 * T2 -
        0.00000347 * T3;
    double Mpr = 306.0253 +
        385.81691806 * k +
        0.0107306 * T2 +
        0.00001236 * T3;
    double F = 21.2964 +
        390.67050646 * k -
        0.0016528 * T2 -
        0.00000239 * T3;
    double C1 = (0.1734 - 0.000393 * T) * sin(M * dr) +
        0.0021 * sin(2 * dr * M);
    C1 = C1 - 0.4068 * sin(Mpr * dr) + 0.0161 * sin(dr * 2 * Mpr);
    C1 = C1 - 0.0004 * sin(dr * 3 * Mpr);
    C1 = C1 + 0.0104 * sin(dr * 2 * F) -
        0.0051 * sin(dr * (M + Mpr));
    C1 = C1 -
        0.0074 * sin(dr * (M - Mpr)) +
        0.0004 * sin(dr * (2 * F + M));
    C1 = C1 -
        0.0004 * sin(dr * (2 * F - M)) -
        0.0006 * sin(dr * (2 * F + Mpr));
    C1 = C1 +
        0.0010 * sin(dr * (2 * F - Mpr)) +
        0.0005 * sin(dr * (2 * Mpr + M));
    double deltat;
    if (T < -11) {
      deltat = 0.001 +
          0.000839 * T +
          0.0002261 * T2 -
          0.00000845 * T3 -
          0.000000081 * T * T3;
    } else {
      deltat = -0.000278 + 0.000265 * T + 0.000262 * T2;
    }
    return Jd1 + C1 - deltat;
  }

  /// Tính kinh độ mặt trời
  static double _sunLongitude(double jdn) {
    double T = (jdn - 2451545.0) / 36525;
    double T2 = T * T;
    double dr = pi / 180;
    double M = 357.5291 + 35999.0503 * T - 0.0001559 * T2 - 0.00000048 * T * T2;
    double L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2;
    double dl = 1.9146 - 0.004817 * T - 0.000014 * T2;
    dl = dl * sin(dr * M);
    dl = dl + 0.019993 - 0.000101 * T;
    dl = dl * sin(dr * 2 * M);
    dl = dl + 0.00029 * sin(dr * 3 * M);
    double theta = L0 + dl;
    double omega = 125.04 - 1934.136 * T;
    theta = theta - 0.00478 * sin(omega * dr);
    theta = theta * dr;
    theta = theta - pi * 2 * (theta / (pi * 2)).floor();
    return theta;
  }

  /// Tính số ngày Julian của điểm sóc đầu tiên trong năm âm lịch
  static int _getSunLongitude(double jd, int timeZone) {
    return (_sunLongitude(jd - 0.5 - timeZone / 24) / pi * 6).floor();
  }

  /// Tính điểm sóc thứ k (Julian)
  static int _getNewMoonDay(int k, int timeZone) {
    return (_newMoon(k) + 0.5 + timeZone / 24).floor();
  }

  /// Tìm tháng 11 âm lịch chứa điểm đông chí
  static int _getLunarMonth11(int yy, int timeZone) {
    double off = _dateToJd(31, 12, yy) - 2415021.0;
    int k = (off / 29.530588853).floor();
    int nm = _getNewMoonDay(k, timeZone);
    int sunLong = _getSunLongitude(nm.toDouble(), timeZone);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1, timeZone);
    }
    return nm;
  }

  /// Xác định xem năm có tháng nhuận không
  static int _getLeapMonthOffset(int a11, int timeZone) {
    int k = ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    int last = 0;
    int i = 1;
    int arc = _getSunLongitude(
        _getNewMoonDay(k + i, timeZone).toDouble(), timeZone);
    do {
      last = arc;
      i++;
      arc = _getSunLongitude(
          _getNewMoonDay(k + i, timeZone).toDouble(), timeZone);
    } while (arc != last && i < 14);
    return i - 1;
  }

  /// Chuyển dương lịch sang âm lịch
  static LunarDate solarToLunar(DateTime solar) {
    int day = solar.day;
    int month = solar.month;
    int year = solar.year;

    int dayNumber = _dateToJd(day, month, year);
    int k = ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    int monthStart = _getNewMoonDay(k + 1, _timeZone);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k, _timeZone);
    }
    int a11 = _getLunarMonth11(year, _timeZone);
    int b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = year;
      a11 = _getLunarMonth11(year - 1, _timeZone);
    } else {
      lunarYear = year + 1;
      b11 = _getLunarMonth11(year + 1, _timeZone);
    }
    int lunarDay = dayNumber - monthStart + 1;
    int diff = ((monthStart - a11) / 29).floor();
    bool lunarLeap = false;
    int lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      int leapMonthDiff = _getLeapMonthOffset(a11, _timeZone);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) {
          lunarLeap = true;
        }
      }
    }
    if (lunarMonth > 12) {
      lunarMonth = lunarMonth - 12;
    }
    if (lunarMonth >= 11 && diff < 4) {
      lunarYear -= 1;
    }

    return LunarDate(
      day: lunarDay,
      month: lunarMonth,
      year: lunarYear,
      isLeapMonth: lunarLeap,
    );
  }

  /// Lấy tên con giáp của năm
  static String getZodiacYear(int lunarYear) {
    const zodiacs = [
      'Thân', 'Dậu', 'Tuất', 'Hợi', 'Tý', 'Sửu',
      'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi'
    ];
    return zodiacs[lunarYear % 12];
  }

  /// Lấy thiên can
  static String getHeavenlyStem(int lunarYear) {
    const stems = [
      'Canh', 'Tân', 'Nhâm', 'Quý', 'Giáp',
      'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ'
    ];
    return stems[lunarYear % 10];
  }

  /// Lấy tên đầy đủ năm âm lịch
  static String getLunarYearName(int lunarYear) {
    return '${getHeavenlyStem(lunarYear)} ${getZodiacYear(lunarYear)}';
  }
}
