import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/vietnamese_holidays.dart';
import '../widgets/event_card.dart';
import '../widgets/event_detail_sheet.dart';
import 'add_event_screen.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sự kiện sắp tới'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Thu thập sự kiện người dùng từ state.events
          final userEvents = <CalendarEvent>[];
          for (final evList in state.events.values) {
            for (final e in evList) {
              if (e.type == EventType.personal || e.type == EventType.reminder) {
                final d = DateTime(e.date.year, e.date.month, e.date.day);
                if (!d.isBefore(today)) userEvents.add(e);
              }
            }
          }

          // Thêm ngày lễ từ 2 năm
          final holidays = <CalendarEvent>[
            ...VietnameseHolidays.getHolidaysForYear(now.year),
            ...VietnameseHolidays.getHolidaysForYear(now.year + 1),
          ]
              .where((h) {
                final d = DateTime(h.date.year, h.date.month, h.date.day);
                return !d.isBefore(today);
              })
              .where((h) => !userEvents.any((e) => e.id == h.id))
              .toList();

          final upcoming = [...userEvents, ...holidays]
            ..sort((a, b) => a.date.compareTo(b.date));

          if (upcoming.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Không có sự kiện sắp tới',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: upcoming.length,
            padding: const EdgeInsets.only(bottom: 20),
            itemBuilder: (context, index) {
              final event = upcoming[index];
              final prev = index > 0 ? upcoming[index - 1] : null;
              final showHeader = prev == null || !_sameDay(prev.date, event.date);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) _dateHeader(context, event.date),
                  EventCard(
                    event: event,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EventDetailSheet(event: event),
                    ),
                    onDelete: event.type == EventType.personal
                        ? () {
                            context
                                .read<CalendarBloc>()
                                .add(DeleteEvent(event.id));
                          }
                        : null,
                    onEdit: event.type == EventType.personal
                        ? () async {
                            final result =
                                await Navigator.push<CalendarEvent?>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddEventScreen(
                                  initialDate: event.date,
                                  event: event,
                                ),
                              ),
                            );
                            if (context.mounted) {
                              final targetDate = result?.date ?? event.date;
                              context
                                  .read<CalendarBloc>()
                                  .add(LoadCalendarEvents(targetDate));
                            }
                          }
                        : null,
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<CalendarEvent?>(
            context,
            MaterialPageRoute(
              builder: (_) => AddEventScreen(initialDate: DateTime.now()),
            ),
          );
          if (context.mounted) {
            final targetDate = result?.date ?? DateTime.now();
            context
                .read<CalendarBloc>()
                .add(LoadCalendarEvents(targetDate));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;

  Widget _dateHeader(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = _sameDay(date, now);
    final isTomorrow =
        _sameDay(date, now.add(const Duration(days: 1)));

    final label = isToday
        ? 'Hôm nay • ${DateFormat('d MMMM', 'vi_VN').format(date)}'
        : isTomorrow
            ? 'Ngày mai • ${DateFormat('d MMMM', 'vi_VN').format(date)}'
            : DateFormat('EEEE, d MMMM yyyy', 'vi_VN').format(date);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primary
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isToday
              ? Colors.white
              : theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
