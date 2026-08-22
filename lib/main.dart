import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/calendar_bloc.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'widgets/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale tiếng Việt cho intl / DateFormat
  await initializeDateFormatting('vi_VN', null);

  // Edge-to-edge: app vẽ dưới status bar + navigation bar
  // Hoạt động đúng trên Android 9+ (API 28+)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Chỉ hỗ trợ portrait (lịch không cần landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final notificationService = NotificationService();
  await notificationService.initialize();
  await _requestPermissions(notificationService);

  runApp(VietCalendarApp(notificationService: notificationService));
}

Future<void> _requestPermissions(NotificationService ns) async {
  // requestAllPermissions xử lý toàn bộ: notification + exactAlarm + battery
  await ns.requestAllPermissions();
}

class VietCalendarApp extends StatelessWidget {
  final NotificationService notificationService;
  const VietCalendarApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => DatabaseService()),
        RepositoryProvider(create: (_) => notificationService),
      ],
      child: BlocProvider(
        create: (ctx) => CalendarBloc(
          db: ctx.read<DatabaseService>(),
          notifications: ctx.read<NotificationService>(),
        ),
        child: MaterialApp(
          title: 'Lịch Việt',
          debugShowCheckedModeBanner: false,

          // ── Localizations: bắt buộc để showDatePicker / showTimePicker
          //    hiển thị tiếng Việt và NavigationBar render đúng
          locale: const Locale('vi', 'VN'),
          supportedLocales: const [
            Locale('vi', 'VN'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: ThemeMode.system,

          // builder: bao SafeArea + điều chỉnh MediaQuery cho edge-to-edge
          builder: (context, child) {
            // Lấy padding thực của device (notch, punch-hole, nav bar)
            final mq = MediaQuery.of(context);
            return MediaQuery(
              // Giữ nguyên padding hệ thống — các screen tự quyết định
              // dùng SafeArea hay không
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.8,
                  maxScaleFactor: 1.3, // Tránh text to quá vỡ layout
                ),
              ),
              child: child!,
            );
          },

          home: NotificationServiceProvider(
            service: notificationService,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    const primary = Color(0xFF1565C0);
    const secondary = Color(0xFFD32F2F);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.notoSansTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        // Quan trọng: systemOverlayStyle ở đây override cho mọi AppBar
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      cardTheme: const CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: const DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    const primary = Color(0xFF42A5F5);
    const secondary = Color(0xFFEF5350);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
        ),
      ),
      cardTheme: const CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: primary.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dialogTheme: const DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }
}
