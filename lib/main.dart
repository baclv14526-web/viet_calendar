import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'services/calendar_bloc.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('vi_VN', null);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final notificationService = NotificationService();
  await notificationService.initialize();
  await _requestPermissions(notificationService);

  runApp(VietCalendarApp(notificationService: notificationService));
}

Future<void> _requestPermissions(NotificationService ns) async {
  // Xin quyền thông báo (chỉ cần thiết trên Android 13+ và iOS)
  await ns.requestPermission();

  // SCHEDULE_EXACT_ALARM chỉ có trên Android 12+ (API 31+)
  // Android 9 không có permission này → skip để tránh crash
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    final sdkInt = info.version.sdkInt;
    debugPrint('[Main] Android SDK: $sdkInt');

    if (sdkInt >= 31) {
      // Android 12+: xin exact alarm permission
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
    // Android 9, 10, 11 (API 28-30): exact alarm tự động OK, không cần xin
  }
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
        create: (context) => CalendarBloc(
          db: context.read<DatabaseService>(),
          notifications: context.read<NotificationService>(),
        ),
        child: MaterialApp(
          title: 'Lịch Việt',
          debugShowCheckedModeBanner: false,
          locale: const Locale('vi', 'VN'),
          supportedLocales: const [
            Locale('vi', 'VN'),
            Locale('en', 'US'),
          ],
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: ThemeMode.system,
          home: NotificationServiceProvider(
            service: notificationService,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF1565C0);
    const secondaryColor = Color(0xFFD32F2F);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.notoSansTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF42A5F5);
    const secondaryColor = Color(0xFFEF5350);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
