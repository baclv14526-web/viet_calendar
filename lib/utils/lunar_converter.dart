import '../models/lunar_date.dart';
import 'dart:math';

/// Chuyển đổi giữa Dương lịch và Âm lịch Việt Nam
/// Thuật toán dựa trên múi giờ GMT+7 (Việt Nam)
class LunarConverter {
  static const int _timeZone = 7; // GMT+7

  /// Chuyển dương lịch sang số ngày Julian
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

  /// Tính số ngày Julian của điểm sóc (New Moon) thứ k
  static double _newMoon(int k) {
    // Đặt tên theo chuẩn lowerCamelCase (t2, t3, jd1, mpr, c1)
    final t = k / 1236.85;
    final t2 = t * t;
    final t3 = t2 * t;
    const dr = pi / 180;
    var jd1 = 2415020.75933 +
        29.53058868 * k +
        0.0001178 * t2 -
        0.000000155 * t3;
    jd1 += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);

    final bigM = 359.2242 +
        29.10535608 * k -
        0.0000333 * t2 -
        0.00000347 * t3;
    final mpr = 306.0253 +
        385.81691806 * k +
        0.0107306 * t2 +
        0.00001236 * t3;
    final f = 21.2964 +
        390.67050646 * k -
        0.0016528 * t2 -
        0.00000239 * t3;

    var c1 = (0.1734 - 0.000393 * t) * sin(bigM * dr) +
        0.0021 * sin(2 * dr * bigM);
    c1 -= 0.4068 * sin(mpr * dr) - 0.0161 * sin(dr * 2 * mpr);
    c1 -= 0.0004 * sin(dr * 3 * mpr);
    c1 += 0.0104 * sin(dr * 2 * f) - 0.0051 * sin(dr * (bigM + mpr));
    c1 -= 0.0074 * sin(dr * (bigM - mpr)) -
        0.0004 * sin(dr * (2 * f + bigM));
    c1 -= 0.0004 * sin(dr * (2 * f - bigM)) +
        0.0006 * sin(dr * (2 * f + mpr));
    c1 += 0.0010 * sin(dr * (2 * f - mpr)) +
        0.0005 * sin(dr * (2 * mpr + bigM));

    final double deltat;
    if (t < -11) {
      deltat = 0.001 +
          0.000839 * t +
          0.0002261 * t2 -
          0.00000845 * t3 -
          0.000000081 * t * t3;
    } else {
      deltat = -0.000278 + 0.000265 * t + 0.000262 * t2;
    }
    return jd1 + c1 - deltat;
  }

  /// Tính kinh độ mặt trời
  static double _sunLongitude(double jdn) {
    final t = (jdn - 2451545.0) / 36525;
    final t2 = t * t;
    const dr = pi / 180;
    final bigM = 357.5291 + 35999.0503 * t - 0.0001559 * t2 -
        0.00000048 * t * t2;
    final l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    var dl = 1.9146 - 0.004817 * t - 0.000014 * t2;
    dl = dl * sin(dr * bigM);
    dl = dl + 0.019993 - 0.000101 * t;
    dl = dl * sin(dr * 2 * bigM);
    dl = dl + 0.00029 * sin(dr * 3 * bigM);
    var theta = l0 + dl;
    final omega = 125.04 - 1934.136 * t;
    theta -= 0.00478 * sin(omega * dr);
    theta *= dr;
    theta -= pi * 2 * (theta / (pi * 2)).floor();
    return theta;
  }

  static int _getSunLongitude(double jd, int timeZone) {
    return (_sunLongitude(jd - 0.5 - timeZone / 24) / pi * 6).floor();
  }

  static int _getNewMoonDay(int k, int timeZone) {
    return (_newMoon(k) + 0.5 + timeZone / 24).floor();
  }

  static int _getLunarMonth11(int yy, int timeZone) {
    final off = _dateToJd(31, 12, yy) - 2415021.0;
    final k = (off / 29.530588853).floor();
    var nm = _getNewMoonDay(k, timeZone);
    final sunLong = _getSunLongitude(nm.toDouble(), timeZone);
    if (sunLong >= 9) {
      nm = _getNewMoonDay(k - 1, timeZone);
    }
    return nm;
  }

  static int _getLeapMonthOffset(int a11, int timeZone) {
    final k =
        ((a11 - 2415021.076998695) / 29.530588853 + 0.5).floor();
    var last = 0;
    var i = 1;
    var arc = _getSunLongitude(
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
    final day = solar.day;
    final month = solar.month;
    final year = solar.year;

    final dayNumber = _dateToJd(day, month, year);
    final k =
        ((dayNumber - 2415021.076998695) / 29.530588853).floor();
    var monthStart = _getNewMoonDay(k + 1, _timeZone);
    if (monthStart > dayNumber) {
      monthStart = _getNewMoonDay(k, _timeZone);
    }
    var a11 = _getLunarMonth11(year, _timeZone);
    var b11 = a11;
    int lunarYear;
    if (a11 >= monthStart) {
      lunarYear = year;
      a11 = _getLunarMonth11(year - 1, _timeZone);
    } else {
      lunarYear = year + 1;
      b11 = _getLunarMonth11(year + 1, _timeZone);
    }
    final lunarDay = dayNumber - monthStart + 1;
    final diff = ((monthStart - a11) / 29).floor();
    var lunarLeap = false;
    var lunarMonth = diff + 11;
    if (b11 - a11 > 365) {
      final leapMonthDiff = _getLeapMonthOffset(a11, _timeZone);
      if (diff >= leapMonthDiff) {
        lunarMonth = diff + 10;
        if (diff == leapMonthDiff) lunarLeap = true;
      }
    }
    if (lunarMonth > 12) lunarMonth -= 12;
    if (lunarMonth >= 11 && diff < 4) lunarYear -= 1;

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
      'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi',
    ];
    return zodiacs[lunarYear % 12];
  }

  /// Lấy thiên can
  static String getHeavenlyStem(int lunarYear) {
    const stems = [
      'Canh', 'Tân', 'Nhâm', 'Quý', 'Giáp',
      'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ',
    ];
    return stems[lunarYear % 10];
  }

  /// Lấy tên đầy đủ năm âm lịch
  static String getLunarYearName(int lunarYear) {
    return '${getHeavenlyStem(lunarYear)} ${getZodiacYear(lunarYear)}';
  }
}
