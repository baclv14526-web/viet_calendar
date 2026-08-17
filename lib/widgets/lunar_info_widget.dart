import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/lunar_converter.dart';

class LunarInfoWidget extends StatelessWidget {
  final DateTime date;

  const LunarInfoWidget({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunar = LunarConverter.solarToLunar(date);
    final isToday = _isToday(date);
    final yearName = LunarConverter.getLunarYearName(lunar.year);
    final zodiac = LunarConverter.getZodiacYear(lunar.year);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Moon icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getMoonPhaseEmoji(lunar.day),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Lunar info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Âm lịch: ',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer
                            .withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Ngày ${lunar.day} tháng ${lunar.month}${lunar.isLeapMonth ? " (nhuận)" : ""} năm $yearName',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _tag(context, '🐉 $zodiac', theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    if (isToday)
                      _tag(context, '• Hôm nay',
                          theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    _tag(
                      context,
                      '🗓 ${DateFormat('d/M/y').format(date)}',
                      Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day &&
        date.month == now.month &&
        date.year == now.year;
  }

  String _getMoonPhaseEmoji(int lunarDay) {
    if (lunarDay == 1) return '🌑'; // New moon
    if (lunarDay <= 7) return '🌒'; // Waxing crescent
    if (lunarDay == 8) return '🌓'; // First quarter
    if (lunarDay <= 14) return '🌔'; // Waxing gibbous
    if (lunarDay == 15) return '🌕'; // Full moon
    if (lunarDay <= 22) return '🌖'; // Waning gibbous
    if (lunarDay == 23) return '🌗'; // Last quarter
    return '🌘'; // Waning crescent
  }
}
