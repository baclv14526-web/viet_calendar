import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/calendar_bloc.dart';
import 'calendar_screen.dart';
import 'agenda_screen.dart';
import 'holidays_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CalendarScreen(),
    AgendaScreen(),
    HolidaysScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    context.read<CalendarBloc>().add(LoadCalendarEvents(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    // bottomPadding = chiều cao gesture bar / home indicator
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      // extendBody: true → body vẽ DƯỚI NavigationBar (hiệu ứng trong suốt)
      extendBody: true,
      // extendBodyBehindAppBar: true được xử lý ở từng screen con (SliverAppBar)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        // height mặc định 80 + gesture bar padding
        height: 72 + bottomPadding,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_outlined),
            selectedIcon: Icon(Icons.format_list_bulleted),
            label: 'Sự kiện',
          ),
          NavigationDestination(
            icon: Icon(Icons.celebration_outlined),
            selectedIcon: Icon(Icons.celebration),
            label: 'Ngày lễ',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
