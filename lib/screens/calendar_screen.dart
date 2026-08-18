import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/lunar_converter.dart';
import '../widgets/event_card.dart';
import '../widgets/event_detail_sheet.dart';
import '../widgets/lunar_info_widget.dart';
import '../widgets/notification_provider.dart';
import 'add_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CalendarBloc>().add(LoadCalendarEvents(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = 72 + MediaQuery.paddingOf(context).bottom;

    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, state),
              SliverToBoxAdapter(child: _buildCalendar(context, state)),
              SliverToBoxAdapter(
                  child: LunarInfoWidget(date: state.selectedDate)),
              SliverToBoxAdapter(
                  child: _buildEventListHeader(context, state)),
              _buildEventList(context, state),
              SliverPadding(
                  padding: EdgeInsets.only(bottom: bottomInset + 72)),
            ],
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: bottomInset - 64),
            child: FloatingActionButton.extended(
              onPressed: () =>
                  _navigateToAddEvent(context, state.selectedDate),
              icon: const Icon(Icons.add),
              label: const Text('Sự kiện'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 0,
      floating: false,
      pinned: true,
      elevation: 2,
      backgroundColor: theme.colorScheme.primary,
      title: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Lịch Việt',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('MMMM yyyy', 'vi_VN').format(state.focusedMonth),
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.today, color: Colors.white),
          tooltip: 'Hôm nay',
          onPressed: () =>
              context.read<CalendarBloc>().add(SelectDate(DateTime.now())),
        ),
        PopupMenuButton<CalendarViewMode>(
          icon: const Icon(Icons.view_week_outlined, color: Colors.white),
          onSelected: (mode) =>
              context.read<CalendarBloc>().add(ChangeViewMode(mode)),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: CalendarViewMode.month,
              child: Row(children: [
                Icon(Icons.calendar_view_month),
                SizedBox(width: 8),
                Text('Tháng'),
              ]),
            ),
            const PopupMenuItem(
              value: CalendarViewMode.week,
              child: Row(children: [
                Icon(Icons.calendar_view_week),
                SizedBox(width: 8),
                Text('Tuần'),
              ]),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => _showNotificationTest(context),
        ),
      ],
    );
  }

  // ─── Calendar ──────────────────────────────────────────────────────────────

  Widget _buildCalendar(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TableCalendar<CalendarEvent>(
          locale: 'vi_VN',
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2050, 12, 31),
          focusedDay: state.focusedMonth,
          selectedDayPredicate: (day) => isSameDay(day, state.selectedDate),
          calendarFormat: state.viewMode == CalendarViewMode.week
              ? CalendarFormat.week
              : CalendarFormat.month,
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return state.events[key] ?? [];
          },
          onDaySelected: (selectedDay, _) =>
              context.read<CalendarBloc>().add(SelectDate(selectedDay)),
          onPageChanged: (focusedDay) =>
              context.read<CalendarBloc>().add(LoadCalendarEvents(focusedDay)),
          // Cell builder tùy chỉnh — bọc trong Stack để hiển thị lunar + dot
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (ctx, day, _) =>
                _dayCell(ctx, day, state, false, false),
            todayBuilder: (ctx, day, _) =>
                _dayCell(ctx, day, state, false, true),
            selectedBuilder: (ctx, day, _) =>
                _dayCell(ctx, day, state, true, false),
            // markerBuilder trả về null — dots được vẽ trong _dayCell luôn
            markerBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            // Tắt decoration mặc định để _dayCell kiểm soát hoàn toàn
            defaultDecoration: const BoxDecoration(),
            todayDecoration: const BoxDecoration(),
            selectedDecoration: const BoxDecoration(),
            weekendTextStyle: const TextStyle(),
            defaultTextStyle: const TextStyle(),
            todayTextStyle: const TextStyle(),
            selectedTextStyle: const TextStyle(),
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold),
            leftChevronIcon:
                Icon(Icons.chevron_left, color: theme.colorScheme.primary),
            rightChevronIcon:
                Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            headerPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600),
            weekendStyle: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          rowHeight: 58,
        ),
      ),
    );
  }

  /// Ô ngày tùy chỉnh — tự vẽ tất cả: nền, số DL, số ÂL, dots sự kiện
  Widget _dayCell(BuildContext context, DateTime day, CalendarState state,
      bool isSelected, bool isToday) {
    final theme = Theme.of(context);
    final lunar = LunarConverter.solarToLunar(day);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final key = DateTime(day.year, day.month, day.day);
    final dayEvents = state.events[key] ?? [];
    final hasHoliday = dayEvents.any((e) =>
        e.type == EventType.holiday || e.type == EventType.lunarHoliday);

    // Màu chữ số dương lịch
    Color numColor;
    if (isSelected) {
      numColor = Colors.white;
    } else if (isWeekend || hasHoliday) {
      numColor = const Color(0xFFE53935);
    } else {
      numColor = theme.colorScheme.onSurface;
    }

    // Dots sự kiện (tối đa 3)
    final dotColors = dayEvents.take(3).map((e) => e.color).toList();

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary
            : isToday
                ? theme.colorScheme.primary.withOpacity(0.12)
                : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Số dương lịch
          Text(
            '${day.day}',
            style: TextStyle(
              color: numColor,
              fontSize: 14,
              fontWeight: isSelected || isToday
                  ? FontWeight.bold
                  : FontWeight.normal,
              height: 1.1,
            ),
          ),
          // Số âm lịch
          Text(
            lunar.day == 1
                ? '${lunar.day}/${lunar.month}'
                : '${lunar.day}',
            style: TextStyle(
              color: isSelected
                  ? Colors.white.withOpacity(0.75)
                  : numColor.withOpacity(0.55),
              fontSize: 7.5,
              height: 1.1,
            ),
          ),
          // Dots sự kiện
          if (dotColors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: dotColors
                    .map((c) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white70 : c,
                            shape: BoxShape.circle,
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Event list ────────────────────────────────────────────────────────────

  Widget _buildEventListHeader(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('EEEE, d MMMM', 'vi_VN').format(state.selectedDate),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (state.selectedDateEvents.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${state.selectedDateEvents.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildEventList(BuildContext context, CalendarState state) {
    if (state.isLoading) {
      return const SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())));
    }
    if (state.selectedDateEvents.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState(context, state));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final event = state.selectedDateEvents[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 300),
            child: SlideAnimation(
              verticalOffset: 30,
              child: FadeInAnimation(
                child: EventCard(
                  event: event,
                  onTap: () => _showEventDetail(context, event),
                  onDelete: event.type == EventType.personal
                      ? () => _deleteEvent(context, event)
                      : null,
                  onEdit: event.type == EventType.personal
                      ? () => _editEvent(context, event)
                      : null,
                ),
              ),
            ),
          );
        },
        childCount: state.selectedDateEvents.length,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, CalendarState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.event_note,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            'Không có sự kiện',
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline, fontSize: 15),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Thêm sự kiện mới'),
            onPressed: () =>
                _navigateToAddEvent(context, state.selectedDate),
          ),
        ],
      ),
    );
  }

  // ─── Navigation & Actions ──────────────────────────────────────────────────

  void _navigateToAddEvent(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BlocProvider.value(
                value: context.read<CalendarBloc>(),
                child: AddEventScreen(initialDate: date),
              )),
    ).then((_) {
      if (!mounted) return;
      // Reload đúng tháng đang xem sau khi thêm/sửa
      final bloc = context.read<CalendarBloc>();
      bloc.add(LoadCalendarEvents(bloc.state.focusedMonth));
    });
  }

  void _editEvent(BuildContext context, CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BlocProvider.value(
                value: context.read<CalendarBloc>(),
                child: AddEventScreen(
                    initialDate: event.date, event: event),
              )),
    ).then((_) {
      if (!mounted) return;
      final bloc = context.read<CalendarBloc>();
      bloc.add(LoadCalendarEvents(bloc.state.focusedMonth));
    });
  }

  void _deleteEvent(BuildContext context, CalendarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện'),
        content: Text('Bạn có chắc muốn xóa "${event.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CalendarBloc>().add(DeleteEvent(event.id));
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showEventDetail(BuildContext context, CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: event),
    );
  }

  void _showNotificationTest(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.notifications_active, color: Colors.blue),
          SizedBox(width: 8),
          Text('Test thông báo'),
        ]),
        content:
            const Text('Gửi thông báo thử để kiểm tra hệ thống nhắc nhở.'),
        actions: [
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await NotificationServiceProvider.of(context)
                  .service
                  .showInstantNotification(
                    title: '🧧 Lịch Việt - Test',
                    body: 'Thông báo hoạt động bình thường! 🎉',
                  );
            },
            child: const Text('Gửi test'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng')),
        ],
      ),
    );
  }
}
