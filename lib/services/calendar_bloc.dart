import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/calendar_event.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/vietnamese_holidays.dart';

// ============ EVENTS ============
abstract class CalendarBlocEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCalendarEvents extends CalendarBlocEvent {
  final DateTime month;
  LoadCalendarEvents(this.month);
  @override
  List<Object?> get props => [month];
}

class SelectDate extends CalendarBlocEvent {
  final DateTime date;
  SelectDate(this.date);
  @override
  List<Object?> get props => [date];
}

class AddEvent extends CalendarBlocEvent {
  final CalendarEvent event;
  AddEvent(this.event);
  @override
  List<Object?> get props => [event];
}

class UpdateEvent extends CalendarBlocEvent {
  final CalendarEvent event;
  UpdateEvent(this.event);
  @override
  List<Object?> get props => [event];
}

class DeleteEvent extends CalendarBlocEvent {
  final String eventId;
  DeleteEvent(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

class ChangeViewMode extends CalendarBlocEvent {
  final CalendarViewMode mode;
  ChangeViewMode(this.mode);
  @override
  List<Object?> get props => [mode];
}

// ============ STATE ============
enum CalendarViewMode { month, week, day }

class CalendarState extends Equatable {
  final DateTime selectedDate;
  // focusedMonth chỉ dùng để track tháng hiện tại cho header title
  // KHÔNG dùng để drive TableCalendar.focusedDay (tránh giật)
  final DateTime focusedMonth;
  final Map<DateTime, List<CalendarEvent>> events;
  final List<CalendarEvent> selectedDateEvents;
  final CalendarViewMode viewMode;
  // Bỏ isLoading khỏi state → không emit loading state giữa animation
  final String? error;

  const CalendarState({
    required this.selectedDate,
    required this.focusedMonth,
    this.events = const {},
    this.selectedDateEvents = const [],
    this.viewMode = CalendarViewMode.month,
    this.error,
  });

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedMonth,
    Map<DateTime, List<CalendarEvent>>? events,
    List<CalendarEvent>? selectedDateEvents,
    CalendarViewMode? viewMode,
    String? error,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      events: events ?? this.events,
      selectedDateEvents: selectedDateEvents ?? this.selectedDateEvents,
      viewMode: viewMode ?? this.viewMode,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        selectedDate,
        focusedMonth,
        events,
        selectedDateEvents,
        viewMode,
        error,
      ];
}

// ============ BLOC ============
class CalendarBloc extends Bloc<CalendarBlocEvent, CalendarState> {
  final DatabaseService _db;
  final NotificationService _notifications;

  // Cache events theo tháng để không reload khi lướt qua lại
  final Map<String, Map<DateTime, List<CalendarEvent>>> _cache = {};

  CalendarBloc({
    required DatabaseService db,
    required NotificationService notifications,
  })  : _db = db,
        _notifications = notifications,
        super(CalendarState(
          selectedDate: DateTime.now(),
          focusedMonth: DateTime.now(),
        )) {
    on<LoadCalendarEvents>(_onLoadEvents);
    on<SelectDate>(_onSelectDate);
    on<AddEvent>(_onAddEvent);
    on<UpdateEvent>(_onUpdateEvent);
    on<DeleteEvent>(_onDeleteEvent);
    on<ChangeViewMode>(_onChangeViewMode);
  }

  String _cacheKey(int year, int month) => '$year-$month';

  Future<void> _onLoadEvents(
    LoadCalendarEvents event,
    Emitter<CalendarState> emit,
  ) async {
    final year = event.month.year;
    final month = event.month.month;
    final key = _cacheKey(year, month);

    // Nếu đã cache → emit ngay, không show loading, không giật
    if (_cache.containsKey(key)) {
      final cached = _cache[key]!;
      final selectedDay = DateTime(
        state.selectedDate.year,
        state.selectedDate.month,
        state.selectedDate.day,
      );
      emit(state.copyWith(
        events: cached,
        selectedDateEvents: cached[selectedDay] ?? [],
        focusedMonth: event.month,
      ));
      return;
    }

    // Chưa cache → load ngầm (KHÔNG emit isLoading để tránh giật)
    try {
      final dbEvents = await _db.getEventsForMonth(year, month);
      final holidays = VietnameseHolidays.getHolidaysForYear(year);

      final eventMap = <DateTime, List<CalendarEvent>>{};
      void addToMap(CalendarEvent e) {
        final day = DateTime(e.date.year, e.date.month, e.date.day);
        eventMap.putIfAbsent(day, () => []).add(e);
      }
      for (final e in dbEvents) { addToMap(e); }
      for (final h in holidays) { addToMap(h); }

      // Lưu cache
      _cache[key] = eventMap;

      // Cũng load tháng kề (prefetch) để lướt qua không lag
      _prefetchAdjacentMonths(year, month);

      final selectedDay = DateTime(
        state.selectedDate.year,
        state.selectedDate.month,
        state.selectedDate.day,
      );
      emit(state.copyWith(
        events: eventMap,
        selectedDateEvents: eventMap[selectedDay] ?? [],
        focusedMonth: event.month,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Prefetch 2 tháng kề (trước + sau) ngầm, không emit state
  void _prefetchAdjacentMonths(int year, int month) {
    final prevMonth = month == 1 ? 12 : month - 1;
    final prevYear = month == 1 ? year - 1 : year;
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;

    for (final ym in [(prevYear, prevMonth), (nextYear, nextMonth)]) {
      final key = _cacheKey(ym.$1, ym.$2);
      if (!_cache.containsKey(key)) {
        _loadMonthToCache(ym.$1, ym.$2);
      }
    }
  }

  Future<void> _loadMonthToCache(int year, int month) async {
    final key = _cacheKey(year, month);
    if (_cache.containsKey(key)) return;
    try {
      final dbEvents = await _db.getEventsForMonth(year, month);
      final holidays = VietnameseHolidays.getHolidaysForYear(year);
      final eventMap = <DateTime, List<CalendarEvent>>{};
      void addToMap(CalendarEvent e) {
        final day = DateTime(e.date.year, e.date.month, e.date.day);
        eventMap.putIfAbsent(day, () => []).add(e);
      }
      for (final e in dbEvents) { addToMap(e); }
      for (final h in holidays) { addToMap(h); }
      _cache[key] = eventMap;
    } catch (_) {
      // Prefetch fail → bỏ qua, sẽ load lại khi cần
    }
  }

  /// Xóa cache của tháng khi có thay đổi (thêm/sửa/xóa event)
  void _invalidateMonth(int year, int month) {
    _cache.remove(_cacheKey(year, month));
  }

  Future<void> _onSelectDate(
    SelectDate event,
    Emitter<CalendarState> emit,
  ) async {
    final day =
        DateTime(event.date.year, event.date.month, event.date.day);

    // Merge events hiện tại với tháng mới nếu cần
    final needsLoad = event.date.month != state.focusedMonth.month ||
        event.date.year != state.focusedMonth.year;

    if (needsLoad) {
      // Cập nhật selectedDate ngay (không đợi load)
      emit(state.copyWith(
        selectedDate: event.date,
        selectedDateEvents: const [],
        focusedMonth: event.date,
      ));
      // Load tháng mới
      add(LoadCalendarEvents(event.date));
    } else {
      emit(state.copyWith(
        selectedDate: event.date,
        selectedDateEvents: state.events[day] ?? [],
      ));
    }
  }

  Future<void> _onAddEvent(
    AddEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      await _db.insertEvent(event.event);
      await _notifications.scheduleEventNotification(event.event);
      // Xóa cache tháng liên quan để force reload
      _invalidateMonth(event.event.date.year, event.event.date.month);
      add(LoadCalendarEvents(state.focusedMonth));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateEvent(
    UpdateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      await _db.updateEvent(event.event);
      await _notifications.cancelEventNotification(event.event.id);
      await _notifications.scheduleEventNotification(event.event);
      _invalidateMonth(event.event.date.year, event.event.date.month);
      add(LoadCalendarEvents(state.focusedMonth));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteEvent(
    DeleteEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      await _db.deleteEvent(event.eventId);
      await _notifications.cancelEventNotification(event.eventId);
      _invalidateMonth(
        state.focusedMonth.year,
        state.focusedMonth.month,
      );
      add(LoadCalendarEvents(state.focusedMonth));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onChangeViewMode(
    ChangeViewMode event,
    Emitter<CalendarState> emit,
  ) {
    emit(state.copyWith(viewMode: event.mode));
  }
}
