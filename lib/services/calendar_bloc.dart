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
enum CalendarViewMode { month, week, day, agenda }

class CalendarState extends Equatable {
  final DateTime selectedDate;
  final DateTime focusedMonth;
  final Map<DateTime, List<CalendarEvent>> events;
  final List<CalendarEvent> selectedDateEvents;
  final List<CalendarEvent> holidays;
  final CalendarViewMode viewMode;
  final bool isLoading;
  final String? error;

  const CalendarState({
    required this.selectedDate,
    required this.focusedMonth,
    this.events = const {},
    this.selectedDateEvents = const [],
    this.holidays = const [],
    this.viewMode = CalendarViewMode.month,
    this.isLoading = false,
    this.error,
  });

  CalendarState copyWith({
    DateTime? selectedDate,
    DateTime? focusedMonth,
    Map<DateTime, List<CalendarEvent>>? events,
    List<CalendarEvent>? selectedDateEvents,
    List<CalendarEvent>? holidays,
    CalendarViewMode? viewMode,
    bool? isLoading,
    String? error,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      events: events ?? this.events,
      selectedDateEvents: selectedDateEvents ?? this.selectedDateEvents,
      holidays: holidays ?? this.holidays,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        selectedDate,
        focusedMonth,
        events,
        selectedDateEvents,
        holidays,
        viewMode,
        isLoading,
        error,
      ];
}

// ============ BLOC ============
class CalendarBloc extends Bloc<CalendarBlocEvent, CalendarState> {
  final DatabaseService _db;
  final NotificationService _notifications;

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

  Future<void> _onLoadEvents(
    LoadCalendarEvents event,
    Emitter<CalendarState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      // Tải sự kiện cá nhân từ DB
      final dbEvents = await _db.getEventsForMonth(
        event.month.year,
        event.month.month,
      );

      // Tải ngày lễ
      final holidays = VietnameseHolidays.getHolidaysForYear(event.month.year);

      // Gộp tất cả vào map theo ngày
      final eventMap = <DateTime, List<CalendarEvent>>{};

      void addToMap(CalendarEvent e) {
        final day = DateTime(e.date.year, e.date.month, e.date.day);
        eventMap.putIfAbsent(day, () => []).add(e);
      }

      for (final e in dbEvents) {
        addToMap(e);
      }
      for (final h in holidays) {
        addToMap(h);
      }

      // Sự kiện của ngày được chọn
      final selectedDay = DateTime(
        state.selectedDate.year,
        state.selectedDate.month,
        state.selectedDate.day,
      );
      final selectedEvents = eventMap[selectedDay] ?? [];

      emit(state.copyWith(
        events: eventMap,
        selectedDateEvents: selectedEvents,
        holidays: holidays,
        focusedMonth: event.month,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onSelectDate(
    SelectDate event,
    Emitter<CalendarState> emit,
  ) async {
    final day = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    final selectedEvents = state.events[day] ?? [];

    // Nếu sang tháng khác thì load lại
    if (event.date.month != state.focusedMonth.month ||
        event.date.year != state.focusedMonth.year) {
      add(LoadCalendarEvents(event.date));
    }

    emit(state.copyWith(
      selectedDate: event.date,
      selectedDateEvents: selectedEvents,
      focusedMonth: event.date,
    ));
  }

  Future<void> _onAddEvent(
    AddEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      await _db.insertEvent(event.event);
      await _notifications.scheduleEventNotification(event.event);

      // Reload
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
