import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/vietnamese_holidays.dart';
import '../widgets/event_card.dart';

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
          // Tập hợp tất cả sự kiện từ tháng này và năm tới
          final now = DateTime.now();
          final allHolidays = [
            ...VietnameseHolidays.getHolidaysForYear(now.year),
            ...VietnameseHolidays.getHolidaysForYear(now.year + 1),
          ];

          // Lọc sự kiện từ hôm nay trở đi
          final upcoming = <CalendarEvent>[];
          for (final events in state.events.values) {
            for (final e in events) {
              if (!e.date.isBefore(DateTime(now.year, now.month, now.day))) {
                upcoming.add(e);
              }
            }
          }
          for (final h in allHolidays) {
            if (!h.date.isBefore(DateTime(now.year, now.month, now.day))) {
              // Check nếu chưa có trong upcoming
              if (!upcoming.any((e) => e.id == h.id)) {
                upcoming.add(h);
              }
            }
          }

          upcoming.sort((a, b) => a.date.compareTo(b.date));

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
              final prevEvent = index > 0 ? upcoming[index - 1] : null;

              // Thêm header ngày
              final showDateHeader = prevEvent == null ||
                  !_isSameDay(prevEvent.date, event.date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) _buildDateHeader(context, event.date),
                  EventCard(event: event),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final isTomorrow = _isSameDay(
        date, now.add(const Duration(days: 1)));

    String label;
    if (isToday) {
      label = 'Hôm nay • ${DateFormat('d MMMM', 'vi_VN').format(date)}';
    } else if (isTomorrow) {
      label = 'Ngày mai • ${DateFormat('d MMMM', 'vi_VN').format(date)}';
    } else {
      label = DateFormat('EEEE, d MMMM yyyy', 'vi_VN').format(date);
    }

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
