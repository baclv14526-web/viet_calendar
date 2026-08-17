import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/lunar_converter.dart';
import '../widgets/event_card.dart';
import '../widgets/lunar_info_widget.dart';
import 'add_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabController;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final bloc = context.read<CalendarBloc>();
    bloc.add(LoadCalendarEvents(DateTime.now()));
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
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
              SliverToBoxAdapter(
                child: _buildCalendar(context, state),
              ),
              SliverToBoxAdapter(
                child: LunarInfoWidget(date: state.selectedDate),
              ),
              SliverToBoxAdapter(
                child: _buildEventListHeader(context, state),
              ),
              _buildEventList(context, state),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          );
        },
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lịch Việt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'vi_VN').format(state.focusedMonth),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.today, color: Colors.white),
          tooltip: 'Hôm nay',
          onPressed: () {
            context.read<CalendarBloc>().add(SelectDate(DateTime.now()));
          },
        ),
        PopupMenuButton<CalendarViewMode>(
          icon: const Icon(Icons.view_agenda_outlined, color: Colors.white),
          onSelected: (mode) {
            context.read<CalendarBloc>().add(ChangeViewMode(mode));
          },
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
          onPressed: () => _showNotificationSettings(context),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        onDaySelected: (selectedDay, focusedDay) {
          context.read<CalendarBloc>().add(SelectDate(selectedDay));
        },
        onPageChanged: (focusedDay) {
          context.read<CalendarBloc>().add(LoadCalendarEvents(focusedDay));
        },
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          weekendTextStyle: const TextStyle(color: Color(0xFFE53935)),
          markerDecoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
          markerSize: 6,
          cellMargin: const EdgeInsets.all(4),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) =>
              _buildDayCell(context, day, state, false),
          todayBuilder: (context, day, focusedDay) =>
              _buildDayCell(context, day, state, false, isToday: true),
          selectedBuilder: (context, day, focusedDay) =>
              _buildDayCell(context, day, state, true),
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
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left, color: theme.colorScheme.primary),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: const TextStyle(
            color: Color(0xFFE53935),
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
    final isWeekend = day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday;
    final dayKey = DateTime(day.year, day.month, day.day);
    final dayEvents = state.events[dayKey] ?? [];
    final hasHoliday = dayEvents
        .any((e) => e.type == EventType.holiday || e.type == EventType.lunarHoliday);

    Color textColor = isWeekend || hasHoliday
        ? const Color(0xFFE53935)
        : theme.colorScheme.onSurface;

    if (isSelected) textColor = Colors.white;

    return Container(
      margin: const EdgeInsets.all(2),
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
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight:
                  isToday || isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            lunar.day == 1 ? '${lunar.day}/${lunar.month}' : '${lunar.day}',
            style: TextStyle(
              color: isSelected
                  ? Colors.white70
                  : textColor.withOpacity(0.6),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventMarkers(List<CalendarEvent> events) {
    final colors = events
        .take(3)
        .map((e) => e.color)
        .toSet()
        .take(3)
        .toList();

    return Positioned(
      bottom: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: colors
            .map((c) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildEventListHeader(BuildContext context, CalendarState state) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEEE, d MMMM', 'vi_VN').format(state.selectedDate);
    final count = state.selectedDateEvents.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            dateStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          const Spacer(),
          if (state.selectedDateEvents.isEmpty)
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Thêm sự kiện'),
              onPressed: () => _navigateToAddEvent(context, state.selectedDate),
            ),
        ],
      ),
    );
  }

  Widget _buildEventList(BuildContext context, CalendarState state) {
    if (state.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.selectedDateEvents.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(context),
      );
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

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Không có sự kiện nào',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Tạo sự kiện mới'),
            onPressed: () =>
                _navigateToAddEvent(context, context.read<CalendarBloc>().state.selectedDate),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToAddEvent(
        context,
        context.read<CalendarBloc>().state.selectedDate,
      ),
      icon: const Icon(Icons.add),
      label: const Text('Sự kiện'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
    );
  }

  void _navigateToAddEvent(BuildContext context, DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(initialDate: date),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<CalendarBloc>().add(LoadCalendarEvents(date));
      }
    });
  }

  void _editEvent(BuildContext context, CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEventScreen(initialDate: event.date, event: event),
      ),
    ).then((_) {
      if (context.mounted) {
        context.read<CalendarBloc>().add(
              LoadCalendarEvents(event.date),
            );
      }
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
            child: const Text('Hủy'),
          ),
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
      builder: (ctx) => _EventDetailSheet(event: event),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.notifications, color: Colors.blue),
          SizedBox(width: 8),
          Text('Thông báo'),
        ]),
        content: const Text(
          'Ứng dụng sẽ gửi thông báo nhắc nhở các sự kiện của bạn và các ngày lễ Việt Nam.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Test notification
              await context.read<NotificationServiceProvider>()
                  .service
                  .showInstantNotification(
                    title: '🧧 Thông báo thử nghiệm',
                    body: 'Hệ thống thông báo hoạt động tốt!',
                  );
            },
            child: const Text('Test thông báo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

// Provider để truy cập NotificationService
class NotificationServiceProvider extends InheritedWidget {
  final NotificationService service;

  const NotificationServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  static NotificationServiceProvider of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotificationServiceProvider>()!;
  }

  @override
  bool updateShouldNotify(NotificationServiceProvider oldWidget) => false;
}

// ============ Event Detail Sheet ============
class _EventDetailSheet extends StatelessWidget {
  final CalendarEvent event;

  const _EventDetailSheet({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            _infoRow(Icons.calendar_today, 'Ngày',
                DateFormat('EEEE, d/M/yyyy', 'vi_VN').format(event.date)),
            if (event.startTime != null)
              _infoRow(Icons.access_time, 'Giờ',
                  '${event.startTime!.format(context)}${event.endTime != null ? ' - ${event.endTime!.format(context)}' : ''}'),
            if (event.description?.isNotEmpty == true)
              _infoRow(Icons.notes, 'Ghi chú', event.description!),
            _infoRow(
              Icons.label,
              'Loại',
              _getTypeName(event.type),
            ),
            if (event.hasNotification)
              _infoRow(
                Icons.notifications_active,
                'Nhắc nhở',
                '${event.notificationMinutesBefore} phút trước',
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  String _getTypeName(EventType type) {
    return switch (type) {
      EventType.personal => 'Cá nhân',
      EventType.holiday => 'Ngày lễ quốc gia',
      EventType.lunarHoliday => 'Ngày lễ âm lịch',
      EventType.reminder => 'Nhắc nhở',
    };
  }
}
