class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool isLeapMonth;
  final String? heavenlyStem;
  final String? earthlyBranch;

  const LunarDate({
    required this.day,
    required this.month,
    required this.year,
    this.isLeapMonth = false,
    this.heavenlyStem,
    this.earthlyBranch,
  });

  String get monthName => _lunarMonths[month - 1];
  String get yearName => _getYearName();
  String get fullYearName => '$heavenlyStem $earthlyBranch';

  static const List<String> _lunarMonths = [
    'Giêng', 'Hai', 'Ba', 'Tư', 'Năm', 'Sáu',
    'Bảy', 'Tám', 'Chín', 'Mười', 'Một', 'Chạp',
  ];

  static const List<String> _heavenlyStems = [
    'Canh', 'Tân', 'Nhâm', 'Quý', 'Giáp',
    'Ất', 'Bính', 'Đinh', 'Mậu', 'Kỷ',
  ];

  static const List<String> _earthlyBranches = [
    'Thân', 'Dậu', 'Tuất', 'Hợi', 'Tý', 'Sửu',
    'Dần', 'Mão', 'Thìn', 'Tỵ', 'Ngọ', 'Mùi',
  ];

  String _getYearName() {
    final stem = _heavenlyStems[year % 10];
    final branch = _earthlyBranches[year % 12];
    return '$stem $branch';
  }

  @override
  String toString() =>
      '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year${isLeapMonth ? " (nhuận)" : ""}';
}
