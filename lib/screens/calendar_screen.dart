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

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    context.read<CalendarBloc>().add(LoadCalendarEvents(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, state),
              SliverToBoxAdapter(child: _buildCalendar(context, state)),
              SliverToBoxAdapter(
                  child: LunarInfoWidget(date: state.selectedDate)),
              SliverToBoxAdapter(
                  child: _buildEventListHeader(context, state)),
              _buildEventList(context, state),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEvent(
          context,
          context.read<CalendarBloc>().state.selectedDate,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Sự kiện'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    return SliverAppBar(
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.primary,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lịch Việt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('MMMM yyyy', 'vi_VN').format(state.focusedMonth),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
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
          icon: const Icon(Icons.view_agenda_outlined, color: Colors.white),
          onSelected: (mode) =>
              context.read<CalendarBloc>().add(ChangeViewMode(mode)),
          itemBuilder: (context) => [
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

  Widget _buildCalendar(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TableCalendar<CalendarEvent>(
          locale: 'vi_VN',
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2050, 12, 31),
          focusedDay: state.focusedMonth,
          rowHeight: 48,
          daysOfWeekHeight: 24,
          selectedDayPredicate: (day) => isSameDay(day, state.selectedDate),
          calendarFormat: state.viewMode == CalendarViewMode.week
              ? CalendarFormat.week
              : CalendarFormat.month,
          eventLoader: (day) {
            final key = DateTime(day.year, day.month, day.day);
            return state.events[key] ?? [];
          },
          onDaySelected: (selectedDay, focusedDay) =>
              context.read<CalendarBloc>().add(SelectDate(selectedDay)),
          onPageChanged: (focusedDay) =>
              context.read<CalendarBloc>().add(LoadCalendarEvents(focusedDay)),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, _) =>
                _buildDayCell(context, day, state, false),
            todayBuilder: (context, day, _) =>
                _buildDayCell(context, day, state, false, isToday: true),
            selectedBuilder: (context, day, _) =>
                _buildDayCell(context, day, state, true),
            outsideBuilder: (context, day, _) => const SizedBox.shrink(),
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              return _buildEventMarkers(events);
            },
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
            headerPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600),
            weekendStyle: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    CalendarState state,
    bool isSelected, {
    bool isToday = false,
  }) {
    final theme = Theme.of(context);
    final lunar = LunarConverter.solarToLunar(day);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final dayKey = DateTime(day.year, day.month, day.day);
    final dayEvents = state.events[dayKey] ?? [];
    final hasHoliday = dayEvents.any((e) =>
        e.type == EventType.holiday || e.type == EventType.lunarHoliday);

    Color textColor = isWeekend || hasHoliday
        ? const Color(0xFFE53935)
        : theme.colorScheme.onSurface;
    if (isSelected) textColor = Colors.white;

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : isToday
                  ? theme.colorScheme.primary.withOpacity(0.15)
                  : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                height: 1.1,
                fontWeight: isToday || isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
            Text(
              lunar.day == 1
                  ? '${lunar.day}/${lunar.month}'
                  : '${lunar.day}',
              style: TextStyle(
                color: isSelected
                    ? Colors.white70
                    : textColor.withOpacity(0.6),
                fontSize: 8,
                height: 1.1,
                fontWeight: lunar.day == 1 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventMarkers(List<CalendarEvent> events) {
    final colors = events.take(3).map((e) => e.color).toSet().take(3).toList();
    return Positioned(
      bottom: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: colors
            .map((c) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration:
                      BoxDecoration(color: c, shape: BoxShape.circle),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildEventListHeader(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    final dateStr =
        DateFormat('EEEE, d MMMM', 'vi_VN').format(state.selectedDate);
    final count = state.selectedDateEvents.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateStr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildEventList(BuildContext context, CalendarState state) {
    if (state.isLoading) {
      return const SliverToBoxAdapter(
          child: Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          )));
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
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50,
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.event_available,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('Không có sự kiện nào',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 16)),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tạo sự kiện mới'),
            onPressed: () =>
                _navigateToAddEvent(context, state.selectedDate),
          ),
        ],
      ),
    );
  }

  void _navigateToAddEvent(BuildContext context, DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEventScreen(initialDate: date)),
    );
    if (context.mounted) {
      context.read<CalendarBloc>().add(LoadCalendarEvents(date));
    }
  }

  void _editEvent(BuildContext context, CalendarEvent event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddEventScreen(initialDate: event.date, event: event)),
    );
    if (context.mounted) {
      context.read<CalendarBloc>().add(LoadCalendarEvents(event.date));
    }
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => EventDetailSheet(event: event),
    );
  }

  void _showNotificationTest(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.notifications, color: Colors.blue),
          SizedBox(width: 8),
          Text('Test thông báo'),
        ]),
        content: const Text(
            'Gửi thông báo thử nghiệm ngay bây giờ để kiểm tra hệ thống.'),
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
