import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../utils/vietnamese_holidays.dart';
import '../utils/lunar_converter.dart';

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key});

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final int _year = DateTime.now().year;
  late List<CalendarEvent> _allHolidays;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allHolidays = VietnameseHolidays.getHolidaysForYear(_year);
    _allHolidays.sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final national =
        _allHolidays.where((h) => h.type == EventType.holiday).toList();
    final lunar =
        _allHolidays.where((h) => h.type == EventType.lunarHoliday).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Ngày lễ $_year'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: '🇻🇳 Dương lịch (${national.length})'),
            Tab(text: '🌙 Âm lịch (${lunar.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHolidayList(national),
          _buildHolidayList(lunar, showLunar: true),
        ],
      ),
    );
  }

  Widget _buildHolidayList(List<CalendarEvent> holidays,
      {bool showLunar = false}) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: holidays.length,
      itemBuilder: (context, index) {
        final h = holidays[index];
        final lunar = showLunar ? null : LunarConverter.solarToLunar(h.date);
        final now = DateTime.now();
        final daysDiff = h.date.difference(now).inDays;
        final isPast = h.date.isBefore(now);
        final isToday = h.date.day == now.day &&
            h.date.month == now.month &&
            h.date.year == now.year;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          color: isPast && !isToday
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: h.color.withOpacity(isPast ? 0.3 : 0.15),
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: h.color, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${h.date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPast ? Colors.grey : h.color,
                    ),
                  ),
                  Text(
                    DateFormat('MMM', 'vi_VN').format(h.date),
                    style: TextStyle(
                      fontSize: 10,
                      color: isPast ? Colors.grey : h.color,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              h.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isPast && !isToday ? Colors.grey : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (h.description != null)
                  Text(
                    h.description!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (lunar != null)
                  Text(
                    '🌙 ${lunar.day}/${lunar.month} âm lịch',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
              ],
            ),
            trailing: isToday
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: h.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Hôm nay',
                        style:
                            TextStyle(color: Colors.white, fontSize: 11)),
                  )
                : isPast
                    ? const Icon(Icons.check_circle, color: Colors.grey, size: 20)
                    : Text(
                        daysDiff == 0
                            ? 'Hôm nay'
                            : 'còn $daysDiff ngày',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysDiff <= 7 ? Colors.red : Colors.grey,
                          fontWeight: daysDiff <= 7
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
          ),
        );
      },
    );
  }
}
