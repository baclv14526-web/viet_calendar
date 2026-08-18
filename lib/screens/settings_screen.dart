import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/notification_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifyHolidays = true;
  bool _notifyPersonal = true;
  bool _showLunarOnCalendar = true;
  int _defaultReminderMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyHolidays = prefs.getBool('notify_holidays') ?? true;
      _notifyPersonal = prefs.getBool('notify_personal') ?? true;
      _showLunarOnCalendar = prefs.getBool('show_lunar') ?? true;
      _defaultReminderMinutes = prefs.getInt('default_reminder') ?? 30;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.only(
            bottom: 72 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _header('🔔 Thông báo'),
          SwitchListTile(
            value: _notifyHolidays,
            onChanged: (v) {
              setState(() => _notifyHolidays = v);
              _save('notify_holidays', v);
            },
            title: const Text('Ngày lễ & Sự kiện quốc gia'),
            subtitle: const Text('Nhắc nhở trước các ngày lễ'),
            secondary: const Icon(Icons.celebration, color: Colors.orange),
          ),
          SwitchListTile(
            value: _notifyPersonal,
            onChanged: (v) {
              setState(() => _notifyPersonal = v);
              _save('notify_personal', v);
            },
            title: const Text('Sự kiện cá nhân'),
            subtitle: const Text('Nhắc nhở sự kiện do bạn tạo'),
            secondary: const Icon(Icons.person, color: Colors.blue),
          ),
          ListTile(
            leading: const Icon(Icons.alarm, color: Colors.purple),
            title: const Text('Thời gian nhắc mặc định'),
            subtitle: Text(_fmtMin(_defaultReminderMinutes)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showReminderPicker,
          ),
          ListTile(
            leading:
                const Icon(Icons.notifications_active, color: Colors.green),
            title: const Text('Test thông báo'),
            subtitle: const Text('Gửi thông báo thử nghiệm ngay bây giờ'),
            trailing: const Icon(Icons.send),
            onTap: () async {
              // Lưu messenger trước async gap để tránh lỗi BuildContext
              final messenger = ScaffoldMessenger.of(context);
              await NotificationServiceProvider.of(context)
                  .service
                  .showInstantNotification(
                    title: '🧧 Lịch Việt – Test thông báo',
                    body: 'Thông báo hoạt động tốt! 🎉',
                    color: theme.colorScheme.primary,
                  );
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('✅ Đã gửi thông báo thử!')),
                );
              }
            },
          ),

          _header('📅 Hiển thị lịch'),
          SwitchListTile(
            value: _showLunarOnCalendar,
            onChanged: (v) {
              setState(() => _showLunarOnCalendar = v);
              _save('show_lunar', v);
            },
            title: const Text('Hiển thị ngày âm lịch'),
            subtitle: const Text('Hiển thị ngày âm lịch trong ô lịch'),
            secondary:
                const Icon(Icons.nightlight_round, color: Colors.indigo),
          ),

          _header('ℹ️ Thông tin ứng dụng'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.blue),
            title: Text('Phiên bản'),
            subtitle: Text('1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.phone_android, color: Colors.teal),
            title: Text('Hỗ trợ'),
            subtitle: Text('Android 9+ (API 28+)'),
          ),
          const ListTile(
            leading: Icon(Icons.code, color: Colors.indigo),
            title: Text('Công nghệ'),
            subtitle: Text('Flutter 3.22 • Dart 3.3 • Material You'),
          ),
          const ListTile(
            leading: Icon(Icons.favorite, color: Colors.red),
            title: Text('Nguồn mở'),
            subtitle: Text('Made with ❤️ for Vietnam 🇻🇳'),
          ),

          _header('🏮 Ngày lễ tích hợp'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Chip('Tết Nguyên Đán 🧧'),
                _Chip('Giỗ Tổ Hùng Vương 👑'),
                _Chip('30/4 Giải phóng 🏳️'),
                _Chip('1/5 Lao động ⚙️'),
                _Chip('2/9 Quốc khánh 🇻🇳'),
                _Chip('8/3 Phụ nữ QT 🌹'),
                _Chip('20/10 Phụ nữ VN 🌸'),
                _Chip('20/11 Nhà giáo 📚'),
                _Chip('22/12 Quân đội ⭐'),
                _Chip('25/12 Giáng Sinh 🎄'),
                _Chip('Tết Trung Thu 🌕'),
                _Chip('Lễ Vu Lan 🙏'),
                _Chip('Tết Đoan Ngọ 🍚'),
                _Chip('Ngày Thần Tài 💰'),
                _Chip('Táo Quân 🔥'),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        ),  // ListView
      ),    // Builder
    );
  }

  Widget _header(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 14,
          ),
        ),
      );

  String _fmtMin(int min) {
    if (min < 60) return '$min phút';
    if (min == 60) return '1 giờ';
    if (min == 120) return '2 giờ';
    if (min == 1440) return '1 ngày';
    return '${min ~/ 60} giờ';
  }

  void _showReminderPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nhắc trước bao lâu?',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...[5, 10, 15, 30, 60, 120, 1440].map((min) => ListTile(
                title: Text(_fmtMin(min)),
                trailing: _defaultReminderMinutes == min
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _defaultReminderMinutes = min);
                  _save('default_reminder', min);
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);
  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
}
