import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/lunar_converter.dart';
import '../widgets/event_detail_sheet.dart';
import 'add_event_screen.dart';

class DayViewScreen extends StatefulWidget {
  final DateTime initialDate;

  const DayViewScreen({super.key, required this.initialDate});

  @override
  State<DayViewScreen> createState() => _DayViewScreenState();
}

class _DayViewScreenState extends State<DayViewScreen> {
  late PageController _pageController;
  late DateTime _currentDate;

  // Trục thời gian: 5:00 → 23:00 + allday section
  static const int _startHour = 0;
  static const int _endHour = 24;
  static const double _hourHeight = 64.0; // px mỗi giờ
  static const double _timeColumnWidth = 52.0;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
    // PageController với page = ngày offset từ epoch
    _pageController = PageController(
      initialPage: _dayIndex(_currentDate),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _dayIndex(DateTime d) =>
      DateTime(d.year, d.month, d.day)
          .difference(DateTime(2000, 1, 1))
          .inDays;

  DateTime _dateFromIndex(int index) =>
      DateTime(2000, 1, 1).add(Duration(days: index));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = 72 + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(context, theme),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        buildWhen: (p, c) =>
            p.events != c.events || p.selectedDate != c.selectedDate,
        builder: (context, state) {
          return PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final newDate = _dateFromIndex(index);
              setState(() => _currentDate = newDate);
              context.read<CalendarBloc>().add(SelectDate(newDate));
              // Load tháng nếu sang tháng mới
              if (newDate.month != state.selectedDate.month ||
                  newDate.year != state.selectedDate.year) {
                context
                    .read<CalendarBloc>()
                    .add(LoadCalendarEvents(newDate));
              }
            },
            itemBuilder: (context, index) {
              final date = _dateFromIndex(index);
              final key = DateTime(date.year, date.month, date.day);
              final events = state.events[key] ?? [];
              return _buildDayPage(context, date, events, bottomInset);
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset - 64),
        child: FloatingActionButton(
          onPressed: () => _addEvent(context, _currentDate),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────

  AppBar _buildAppBar(BuildContext context, ThemeData theme) {
    final lunar = LunarConverter.solarToLunar(_currentDate);
    final lunarYear = LunarConverter.getLunarYearName(lunar.year);
    final isToday = _isToday(_currentDate);

    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                DateFormat('EEEE', 'vi_VN').format(_currentDate),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Hôm nay',
                      style: TextStyle(fontSize: 10)),
                ),
              ],
            ],
          ),
          Text(
            '${_currentDate.day} tháng ${_currentDate.month}, ${_currentDate.year}'
            '  •  ${lunar.day}/${lunar.month} $lunarYear',
            style:
                const TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        // Nút qua ngày trước
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Ngày trước',
          onPressed: () => _goToDay(
              _currentDate.subtract(const Duration(days: 1))),
        ),
        // Nút hôm nay
        TextButton(
          onPressed: () => _goToDay(DateTime.now()),
          child: const Text('Hôm nay',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        // Nút ngày sau
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Ngày sau',
          onPressed: () =>
              _goToDay(_currentDate.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  void _goToDay(DateTime date) {
    _pageController.animateToPage(
      _dayIndex(date),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ─── Day page ─────────────────────────────────────────────────────────────

  Widget _buildDayPage(
    BuildContext context,
    DateTime date,
    List<CalendarEvent> events,
    double bottomInset,
  ) {
    final allDayEvents =
        events.where((e) => e.isAllDay).toList();
    final timedEvents =
        events.where((e) => !e.isAllDay).toList();

    // Scroll đến giờ hiện tại nếu là hôm nay
    final scrollController = ScrollController(
      initialScrollOffset: _isToday(date)
          ? (DateTime.now().hour - 1).clamp(0, 22) * _hourHeight
          : 8 * _hourHeight, // scroll đến 8h mặc định
    );

    return Column(
      children: [
        // ── Thanh ngày trong tuần (swipe indicator) ────────────────
        _buildWeekStrip(context, date),

        // ── Section sự kiện cả ngày ────────────────────────────────
        if (allDayEvents.isNotEmpty)
          _buildAllDaySection(context, allDayEvents),

        // ── Timeline theo giờ ──────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset + 80),
            child: SizedBox(
              height: (_endHour - _startHour) * _hourHeight,
              child: Stack(
                children: [
                  // Lưới giờ
                  _buildTimeGrid(context),
                  // Đường "bây giờ"
                  if (_isToday(date)) _buildNowIndicator(context),
                  // Các sự kiện có giờ
                  ..._buildTimedEventTiles(
                      context, timedEvents, date),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Week strip ──────────────────────────────────────────────────────────

  Widget _buildWeekStrip(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    // Lấy thứ 2 của tuần chứa date
    final monday =
        date.subtract(Duration(days: date.weekday - 1));
    final days =
        List.generate(7, (i) => monday.add(Duration(days: i)));
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      color: theme.colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Row(
        children: List.generate(7, (i) {
          final d = days[i];
          final isSelected = isSameDay(d, date);
          final isTod = _isToday(d);
          final isWeekend = d.weekday >= 6;

          return Expanded(
            child: GestureDetector(
              onTap: () => _goToDay(d),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: isWeekend
                          ? Colors.red[200]
                          : Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : isTod
                              ? Colors.white24
                              : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isTod
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : isWeekend
                                ? Colors.red[200]
                                : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;

  bool _isToday(DateTime d) => isSameDay(d, DateTime.now());

  // ─── All-day section ─────────────────────────────────────────────────────

  Widget _buildAllDaySection(
      BuildContext context, List<CalendarEvent> events) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
            bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            SizedBox(
              width: _timeColumnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 6, horizontal: 6),
                child: Text(
                  'Cả ngày',
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            // Events
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: events
                      .map((e) => _allDayChip(context, e))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allDayChip(BuildContext context, CalendarEvent event) {
    return GestureDetector(
      onTap: () => _showDetail(context, event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: event.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: event.color, width: 3)),
        ),
        child: Text(
          event.title,
          style: TextStyle(
              fontSize: 12,
              color: event.color,
              fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ─── Time grid ───────────────────────────────────────────────────────────

  Widget _buildTimeGrid(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outline.withOpacity(0.15);
    final labelColor = theme.colorScheme.onSurface.withOpacity(0.45);

    return Column(
      children: List.generate(_endHour - _startHour, (i) {
        final hour = _startHour + i;
        return SizedBox(
          height: _hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nhãn giờ
              SizedBox(
                width: _timeColumnWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Text(
                    hour == 0
                        ? ''
                        : '${hour.toString().padLeft(2, '0')}:00',
                    style:
                        TextStyle(fontSize: 10, color: labelColor),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              // Đường kẻ ngang
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: dividerColor, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Now indicator ───────────────────────────────────────────────────────

  Widget _buildNowIndicator(BuildContext context) {
    final now = DateTime.now();
    final topOffset = ((now.hour - _startHour) +
            now.minute / 60.0) *
        _hourHeight;
    return Positioned(
      top: topOffset - 1,
      left: _timeColumnWidth - 5,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Timed event tiles ───────────────────────────────────────────────────

  List<Widget> _buildTimedEventTiles(
    BuildContext context,
    List<CalendarEvent> events,
    DateTime date,
  ) {
    // Nhóm các events chồng chéo để tính cột
    final columns = _layoutEvents(events);
    final totalColumns = columns.isEmpty ? 1 : columns.length;

    final widgets = <Widget>[];
    for (int col = 0; col < columns.length; col++) {
      for (final event in columns[col]) {
        final tile = _buildEventTile(
          context,
          event,
          col,
          totalColumns,
        );
        if (tile != null) widgets.add(tile);
      }
    }
    return widgets;
  }

  /// Phân chia events thành các cột không chồng chéo
  List<List<CalendarEvent>> _layoutEvents(List<CalendarEvent> events) {
    if (events.isEmpty) return [];
    final sorted = [...events]..sort((a, b) {
        final aStart = _eventStartMinutes(a);
        final bStart = _eventStartMinutes(b);
        return aStart.compareTo(bStart);
      });

    final columns = <List<CalendarEvent>>[];
    for (final event in sorted) {
      bool placed = false;
      for (final col in columns) {
        // Kiểm tra có chồng với event cuối cùng trong cột không
        final last = col.last;
        if (_eventEndMinutes(last) <= _eventStartMinutes(event)) {
          col.add(event);
          placed = true;
          break;
        }
      }
      if (!placed) columns.add([event]);
    }
    return columns;
  }

  int _eventStartMinutes(CalendarEvent e) {
    if (e.startTime == null) return 0;
    return e.startTime!.hour * 60 + e.startTime!.minute;
  }

  int _eventEndMinutes(CalendarEvent e) {
    if (e.endTime != null) {
      return e.endTime!.hour * 60 + e.endTime!.minute;
    }
    // Mặc định 1 giờ nếu không có giờ kết thúc
    return _eventStartMinutes(e) + 60;
  }

  Widget? _buildEventTile(
    BuildContext context,
    CalendarEvent event,
    int col,
    int totalCols,
  ) {
    if (event.startTime == null) return null;

    final startMin = _eventStartMinutes(event);
    final endMin = _eventEndMinutes(event);
    final durationMin = (endMin - startMin).clamp(15, 24 * 60);

    final top = ((startMin / 60.0) - _startHour) * _hourHeight;
    final height = (durationMin / 60.0) * _hourHeight;

    final colWidth =
        1.0 / totalCols; // phần trăm chiều rộng mỗi cột

    return Positioned(
      top: top,
      left: _timeColumnWidth +
          (MediaQuery.of(context).size.width - _timeColumnWidth) *
              col *
              colWidth +
          2,
      width: (MediaQuery.of(context).size.width - _timeColumnWidth) *
              colWidth -
          4,
      height: height.clamp(20, double.infinity),
      child: GestureDetector(
        onTap: () => _showDetail(context, event),
        child: Container(
          decoration: BoxDecoration(
            color: event.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border:
                Border(left: BorderSide(color: event.color, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: TextStyle(
                  fontSize: height > 30 ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: event.color,
                ),
                maxLines: height > 40 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (height > 36 && event.startTime != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${event.startTime!.format(context)}'
                  '${event.endTime != null ? ' – ${event.endTime!.format(context)}' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: event.color.withOpacity(0.8),
                  ),
                ),
              ],
              if (height > 56 &&
                  event.description?.isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  event.description!,
                  style: TextStyle(
                    fontSize: 10,
                    color: event.color.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  void _showDetail(BuildContext context, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: event),
    );
  }

  void _addEvent(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CalendarBloc>(),
          child: AddEventScreen(initialDate: date),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      final bloc = context.read<CalendarBloc>();
      bloc.add(LoadCalendarEvents(bloc.state.focusedMonth));
    });
  }
}
