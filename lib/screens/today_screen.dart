import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../utils/lunar_converter.dart';
import '../utils/can_chi_helper.dart';
import '../widgets/event_detail_sheet.dart';
import 'add_event_screen.dart';
import 'day_view_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Cập nhật đồng hồ mỗi giây để giờ hoàng đạo realtime
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lunar = LunarConverter.solarToLunar(_now);
    final lunarYearName = LunarConverter.getLunarYearName(lunar.year);
    final hoangDao = CanChiHelper.gioHoangDao(_now);
    final isHD = CanChiHelper.isHoangDao(_now);
    final bottomInset = 72 + MediaQuery.paddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Nền kem như tờ lịch
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomInset.toDouble()),
        child: Column(
          children: [
            // ── Header tháng dương & âm ──────────────────────────────
            _buildHeader(context, theme, topInset, lunar, lunarYearName),

            // ── Thân tờ lịch ─────────────────────────────────────────
            _buildCalendarBody(context, theme, lunar, hoangDao, isHD),

            // ── Sự kiện hôm nay ──────────────────────────────────────
            _buildTodayEvents(context, theme),

            const SizedBox(height: 8),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset - 64),
        child: FloatingActionButton(
          onPressed: () => _addEvent(context),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          mini: false,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    double topInset,
    dynamic lunar,
    String lunarYearName,
  ) {
    return Container(
      color: theme.colorScheme.primary,
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dương lịch
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'vi_VN').format(_now),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Ngày ${CanChiHelper.dayOfYear(_now)}  •  Tuần ${CanChiHelper.weekOfYear(_now)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          // Âm lịch (Hán tự phong cách)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CanChiHelper.thangHanSimple[lunar.month - 1],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                ),
              ),
              Text(
                lunarYearName,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Calendar body (tờ lịch chính) ─────────────────────────────────────────

  Widget _buildCalendarBody(
    BuildContext context,
    ThemeData theme,
    dynamic lunar,
    List<String> hoangDao,
    bool isHD,
  ) {
    final screenW = MediaQuery.sizeOf(context).width;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Hoàng đạo / Hắc đạo badge + Ngày/Tuần trong năm ──────
          _buildTopBadge(theme, isHD),

          // ── Số ngày lớn (dương lịch) ──────────────────────────────
          GestureDetector(
            onTap: () => _openDayView(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_now.day}',
                style: TextStyle(
                  fontSize: screenW * 0.38,
                  fontWeight: FontWeight.w900,
                  color: _dayNumberColor(),
                  height: 1.0,
                  letterSpacing: -4,
                ),
              ),
            ),
          ),

          // ── Câu danh ngôn ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              CanChiHelper.quoteOfDay(_now),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),

          // ── Giờ hoàng đạo ─────────────────────────────────────────
          _buildHoangDaoRow(theme, hoangDao),

          const Divider(height: 1, thickness: 0.5),

          // ── Thứ hàng dưới ─────────────────────────────────────────
          _buildWeekdayRow(theme),

          const Divider(height: 1, thickness: 0.5),

          // ── Can Chi + Âm lịch ─────────────────────────────────────
          _buildBottomInfo(context, theme, lunar),
        ],
      ),
    );
  }

  // Badge hoàng đạo / hắc đạo
  Widget _buildTopBadge(ThemeData theme, bool isHD) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hoàng đạo / Hắc đạo
          Row(
            children: [
              Icon(
                isHD ? Icons.star : Icons.star_border,
                size: 14,
                color: isHD ? const Color(0xFFFFAB00) : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                isHD ? 'hoàng đạo' : 'hắc đạo',
                style: TextStyle(
                  fontSize: 12,
                  color: isHD
                      ? const Color(0xFFFFAB00)
                      : Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Ngày / Tuần
          Text(
            'NGÀY ${CanChiHelper.dayOfYear(_now)}  •  TUẦN ${CanChiHelper.weekOfYear(_now)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _dayNumberColor() {
    if (_now.weekday == DateTime.sunday) return const Color(0xFFD32F2F);
    if (_now.weekday == DateTime.saturday) return const Color(0xFF1565C0);
    return const Color(0xFF212121);
  }

  // Hàng giờ hoàng đạo
  Widget _buildHoangDaoRow(ThemeData theme, List<String> hoangDao) {
    final currentChi = CanChiHelper.diaChi[
        (((_now.hour + 1) ~/ 2)) % 12];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Text(
            'Giờ hoàng đạo:',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: hoangDao.map((chi) {
              final isCurrent = chi == currentChi;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFFFFAB00)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFFFFAB00)
                        : const Color(0xFFFFE082),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  chi,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : const Color(0xFF795548),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Hàng thứ trong tuần (3 ngôn ngữ)
  Widget _buildWeekdayRow(ThemeData theme) {
    final thu = DateFormat('EEEE', 'vi_VN').format(_now).toUpperCase();
    final thuHan = CanChiHelper.thuTrongTuanHan(_now);
    final isWeekend = _now.weekday >= 6;
    final color = isWeekend ? const Color(0xFFD32F2F) : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Thứ tiếng Việt đơn giản
          Text(
            _thuViet(_now.weekday),
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          // Thứ viết đầy đủ
          Text(
            thu,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          // Thứ tiếng Hán
          Text(
            thuHan,
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.7),
              fontFamily: 'serif',
            ),
          ),
        ],
      ),
    );
  }

  String _thuViet(int weekday) {
    const map = {
      1: 'Thứ Hai', 2: 'Thứ Ba', 3: 'Thứ Tư',
      4: 'Thứ Năm', 5: 'Thứ Sáu', 6: 'Thứ Bảy', 7: 'Chủ Nhật',
    };
    return map[weekday] ?? '';
  }

  // Phần dưới: Can Chi (trái) + Âm lịch (giữa) + Hán tự (phải)
  Widget _buildBottomInfo(BuildContext context, ThemeData theme, dynamic lunar) {
    final ngayCC = CanChiHelper.ngayCanChi(_now);
    final thangCC = CanChiHelper.thangCanChi(lunar.month, lunar.year);
    final namCC = CanChiHelper.namCanChi(lunar.year);
    final gioCC = CanChiHelper.currentGioCanChi(_now);
    final ngayHan = CanChiHelper.ngayHan(lunar.day);
    final namHan =
        '${CanChiHelper.thienCan[lunar.year % 10]}${CanChiHelper.diaChi[lunar.year % 12]}年';
    final thangHan = CanChiHelper.thangHanSimple[lunar.month - 1];

    return Container(
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cột trái: Can Chi ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _canChiItem('Giờ $gioCC'),
                  _canChiItem('Ngày $ngayCC'),
                  _canChiItem('Tháng $thangCC'),
                  _canChiItem('Năm $namCC'),
                ],
              ),
            ),

            // ── Cột giữa: Âm lịch lớn ─────────────────────────────
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Tháng ${lunar.month}${lunar.isLeapMonth ? " nhuận" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.brown[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lunar.day}',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: Colors.brown[700],
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openDayView(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Cột phải: Hán tự ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _hanItem(namHan),
                  _hanItem(thangHan),
                  const SizedBox(height: 4),
                  Text(
                    ngayHan,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                      fontFamily: 'serif',
                    ),
                  ),
                  _hanItem(CanChiHelper.ngayCanChi(_now)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canChiItem(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037)),
        ),
      );

  Widget _hanItem(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF5D4037),
          fontFamily: 'serif',
        ),
        textAlign: TextAlign.right,
      );

  // ─── Sự kiện hôm nay ────────────────────────────────────────────────────────

  Widget _buildTodayEvents(BuildContext context, ThemeData theme) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      buildWhen: (p, c) => p.events != c.events,
      builder: (context, state) {
        final key = DateTime(_now.year, _now.month, _now.day);
        final events = state.events[key] ?? [];

        if (events.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 16,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Sự kiện hôm nay (${events.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ...events.map((e) => _eventTile(context, e)),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _eventTile(BuildContext context, CalendarEvent event) {
    final isHoliday = event.type == EventType.holiday ||
        event.type == EventType.lunarHoliday;

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EventDetailSheet(event: event),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (!event.isAllDay && event.startTime != null)
                    Text(
                      event.startTime!.format(context),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    )
                  else
                    Text(
                      isHoliday ? 'Ngày lễ' : 'Cả ngày',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: event.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _openDayView(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CalendarBloc>(),
          child: DayViewScreen(initialDate: _now),
        ),
      ),
    );
  }

  void _addEvent(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CalendarBloc>(),
          child: AddEventScreen(initialDate: _now),
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      context.read<CalendarBloc>().add(LoadCalendarEvents(_now));
    });
  }
}
