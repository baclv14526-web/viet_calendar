import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';

class EventDetailSheet extends StatelessWidget {
  final CalendarEvent event;
  const EventDetailSheet({super.key, required this.event});

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
                  decoration:
                      BoxDecoration(color: event.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            _row(Icons.calendar_today, 'Ngày',
                DateFormat('EEEE, d/M/yyyy', 'vi_VN').format(event.date)),
            if (event.startTime != null)
              _row(
                Icons.access_time,
                'Giờ',
                '${event.startTime!.format(context)}'
                    '${event.endTime != null ? ' - ${event.endTime!.format(context)}' : ''}',
              ),
            if (event.description?.isNotEmpty == true)
              _row(Icons.notes, 'Ghi chú', event.description!),
            _row(Icons.label, 'Loại', _typeName(event.type)),
            if (event.hasNotification)
              _row(Icons.notifications_active, 'Nhắc nhở',
                  '${event.notificationMinutesBefore} phút trước'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _typeName(EventType type) => switch (type) {
        EventType.personal => 'Cá nhân',
        EventType.holiday => 'Ngày lễ quốc gia',
        EventType.lunarHoliday => 'Ngày lễ âm lịch',
        EventType.reminder => 'Nhắc nhở',
      };
}
