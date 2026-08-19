import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/lunar_converter.dart';

class YearViewScreen extends StatefulWidget {
  final int initialYear;

  const YearViewScreen({super.key, required this.initialYear});

  @override
  State<YearViewScreen> createState() => _YearViewScreenState();
}

class _YearViewScreenState extends State<YearViewScreen> {
  late int _year;
  late PageController _pageController;

  // Year 2000 = page 0
  static const int _baseYear = 2000;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _pageController = PageController(
      initialPage: _year - _baseYear,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunar = LunarConverter.solarToLunar(DateTime(_year, 1, 1));
    final lunarYearName = LunarConverter.getLunarYearName(lunar.year);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Năm $_year',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              '🐉 Năm $lunarYearName',
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Nút năm trước
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Năm trước',
            onPressed: () => _animateToYear(_year - 1),
          ),
          // Nút năm nay
          TextButton(
            onPressed: () => _animateToYear(DateTime.now().year),
            child: const Text('Năm nay',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          // Nút năm sau
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Năm sau',
            onPressed: () => _animateToYear(_year + 1),
          ),
        ],
      ),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        buildWhen: (p, c) => p.events != c.events,
        builder: (context, state) {
          return PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              final newYear = _baseYear + page;
              setState(() => _year = newYear);
            },
            itemBuilder: (context, page) {
              final year = _baseYear + page;
              return _YearGrid(
                year: year,
                events: state.events,
                onMonthTap: (month) => _onMonthTap(context, year, month),
                onDayTap: (date) => _onDayTap(context, date),
              );
            },
          );
        },
      ),
    );
  }

  void _animateToYear(int year) {
    _pageController.animateToPage(
      year - _baseYear,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onMonthTap(BuildContext context, int year, int month) {
    // Nhảy về calendar screen ở tháng đó
    final date = DateTime(year, month, 1);
    context.read<CalendarBloc>().add(SelectDate(date));
    context.read<CalendarBloc>().add(LoadCalendarEvents(date));
    Navigator.pop(context);
  }

  void _onDayTap(BuildContext context, DateTime date) {
    context.read<CalendarBloc>().add(SelectDate(date));
    context.read<CalendarBloc>().add(LoadCalendarEvents(date));
    Navigator.pop(context);
  }
}

// ─── Year grid widget ─────────────────────────────────────────────────────────

class _YearGrid extends StatelessWidget {
  final int year;
  final Map<DateTime, List<CalendarEvent>> events;
  final void Function(int month) onMonthTap;
  final void Function(DateTime date) onDayTap;

  const _YearGrid({
    required this.year,
    required this.events,
    required this.onMonthTap,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = 72 + MediaQuery.paddingOf(context).bottom;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset.toDouble()),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.78,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return _MiniMonth(
          year: year,
          month: index + 1,
          events: events,
          onMonthTap: () => onMonthTap(index + 1),
          onDayTap: onDayTap,
        );
      },
    );
  }
}

// ─── Mini month widget ────────────────────────────────────────────────────────

class _MiniMonth extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, List<CalendarEvent>> events;
  final VoidCallback onMonthTap;
  final void Function(DateTime) onDayTap;

  const _MiniMonth({
    required this.year,
    required this.month,
    required this.events,
    required this.onMonthTap,
    required this.onDayTap,
  });

  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isCurrentMonth =
        year == now.year && month == now.month;

    // Tên tháng
    final monthName =
        DateFormat('MMMM', 'vi_VN').format(DateTime(year, month));

    return GestureDetector(
      onTap: onMonthTap,
      child: Card(
        elevation: isCurrentMonth ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isCurrentMonth
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tháng
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  monthName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCurrentMonth
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),

              // Labels T2–CN
              Row(
                children: _dayLabels.map((d) {
                  final isWeekend =
                      d == 'T7' || d == 'CN';
                  return Expanded(
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: isWeekend
                            ? Colors.red[400]
                            : theme.colorScheme.onSurface
                                .withOpacity(0.45),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 2),

              // Grid các ngày
              Expanded(child: _buildDayGrid(context, theme, now)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayGrid(
      BuildContext context, ThemeData theme, DateTime now) {
    final firstDay = DateTime(year, month, 1);
    // Thứ 2 = 1, CN = 7. Offset = (weekday-1) để ô đầu tuần là T2
    final startOffset = firstDay.weekday - 1;
    final daysInMonth =
        DateUtils.getDaysInMonth(year, month);
    final totalCells = startOffset + daysInMonth;
    // Làm tròn lên bội của 7
    final cellCount = ((totalCells / 7).ceil()) * 7;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(year, month, dayNum);
        return _DayCell(
          date: date,
          events: events[date] ?? [],
          isToday: date.year == now.year &&
              date.month == now.month &&
              date.day == now.day,
          theme: theme,
          onTap: () => onDayTap(date),
        );
      },
    );
  }
}

// ─── Single day cell ──────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final bool isToday;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DayCell({
    required this.date,
    required this.events,
    required this.isToday,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend =
        date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;

    final hasHoliday = events.any((e) =>
        e.type == EventType.holiday ||
        e.type == EventType.lunarHoliday);

    final hasPersonal = events.any((e) =>
        e.type == EventType.personal ||
        e.type == EventType.reminder);

    // Màu số ngày
    Color textColor;
    if (isWeekend || hasHoliday) {
      textColor = Colors.red;
    } else {
      textColor = theme.colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primary
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 9,
                fontWeight:
                    isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Colors.white : textColor,
                height: 1,
              ),
            ),
            // Dot sự kiện cá nhân — góc dưới phải
            if (hasPersonal && !isToday)
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
