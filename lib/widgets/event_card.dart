import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/calendar_event.dart';

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHoliday = event.type == EventType.holiday ||
        event.type == EventType.lunarHoliday;

    return Slidable(
      enabled: !isHoliday,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit?.call(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Sửa',
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Xóa',
              borderRadius: isHoliday || onEdit == null
                  ? const BorderRadius.horizontal(left: Radius.circular(12))
                  : BorderRadius.zero,
            ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: isHoliday
                ? Border(left: BorderSide(color: event.color, width: 4))
                : null,
          ),
          child: Row(
            children: [
              // Color indicator
              if (!isHoliday)
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: event.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: event.color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getEventIcon(event.type),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (event.description?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Text(
                                event.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (!event.isAllDay && event.startTime != null)
                              Text(
                                '${event.startTime!.format(context)}${event.endTime != null ? ' - ${event.endTime!.format(context)}' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: event.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Badge
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (event.isAllDay)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: event.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Cả ngày',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: event.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          if (event.hasNotification && !isHoliday)
                            Icon(Icons.notifications_active,
                                size: 14, color: event.color.withOpacity(0.7)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEventIcon(EventType type) {
    return switch (type) {
      EventType.personal => '📅',
      EventType.holiday => '🇻🇳',
      EventType.lunarHoliday => '🌙',
      EventType.reminder => '⏰',
    };
  }
}
