import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/calendar_event.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'viet_calendar.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            startTimeHour INTEGER,
            startTimeMinute INTEGER,
            endTimeHour INTEGER,
            endTimeMinute INTEGER,
            type INTEGER NOT NULL DEFAULT 0,
            repeatType INTEGER NOT NULL DEFAULT 0,
            color INTEGER NOT NULL,
            hasNotification INTEGER NOT NULL DEFAULT 1,
            notificationMinutesBefore INTEGER,
            isAllDay INTEGER NOT NULL DEFAULT 0,
            isLunarBased INTEGER NOT NULL DEFAULT 0,
            lunarDay INTEGER,
            lunarMonth INTEGER
          )
        ''');
      },
    );
  }

  Future<void> insertEvent(CalendarEvent event) async {
    final db = await database;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final db = await database;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> deleteEvent(String id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final maps = await db.query(
      'events',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return maps.map((m) => CalendarEvent.fromMap(m)).toList();
  }

  Future<List<CalendarEvent>> getAllEvents() async {
    final db = await database;
    final maps = await db.query('events', orderBy: 'date ASC');
    return maps.map((m) => CalendarEvent.fromMap(m)).toList();
  }

  Future<List<CalendarEvent>> getEventsForMonth(int year, int month) async {
    final db = await database;
    final startOfMonth = DateTime(year, month, 1).toIso8601String();
    final endOfMonth =
        DateTime(year, month + 1, 0, 23, 59, 59, 999).toIso8601String();

    final maps = await db.query(
      'events',
      where: '(date >= ? AND date <= ?) OR repeatType != 0',
      whereArgs: [startOfMonth, endOfMonth],
      orderBy: 'date ASC',
    );
    return maps.map((m) => CalendarEvent.fromMap(m)).toList();
  }
}
