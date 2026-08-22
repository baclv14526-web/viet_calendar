import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/notification_provider.dart';
import '../services/calendar_bloc.dart';
import 'manage_events_screen.dart';

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
            _header('📋 Sự kiện của tôi'),
          ListTile(
            leading:
                const Icon(Icons.event_note, color: Colors.blue),
            title: const Text('Quản lý sự kiện'),
            subtitle: const Text(
                'Xem, sửa và xóa sự kiện đã tạo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<CalendarBloc>(),
                  child: const ManageEventsScreen(),
                ),
              ),
            ),
          ),

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
            title: const Text('Kiểm tra & cài đặt thông báo'),
            subtitle: const Text(
                'Xem trạng thái quyền, test thông báo lên lịch'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showNotificationDiagnostic(context),
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

  Future<void> _showNotificationDiagnostic(BuildContext context) async {
    final ns = NotificationServiceProvider.of(context).service;
    final perms = await ns.checkPermissions();
    final pending = await ns.getPendingNotifications();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔔 Chẩn đoán Thông báo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _permRow('Quyền hiển thị thông báo', perms['notification'] ?? false),
            _permRow('Đặt lịch chính xác (Alarm)', perms['exactAlarm'] ?? false),
            _permRow('Bỏ qua tối ưu pin (Doze)', perms['battery'] ?? false),
            const Divider(height: 20),
            Row(children: [
              const Icon(Icons.pending_actions, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              Text('Thông báo đang chờ: ${pending.length}'),
            ]),
            const SizedBox(height: 16),

            // Xin lại quyền
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.security),
                label: const Text('Xin lại tất cả quyền'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ns.requestAllPermissions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã yêu cầu quyền')));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // Test instant
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Test tức thì'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ns.showInstantNotification(
                    title: '🧧 Lịch Việt – Test tức thì',
                    body: 'Thông báo tức thì hoạt động! ✅',
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Test scheduled 5 giây
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.alarm),
                label: const Text('Test lên lịch (sau 5 giây) ← quan trọng'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ns.scheduleTestIn5Seconds();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                        '⏱ Chờ 5 giây — nếu không thấy thông báo: '
                        'quyền Báo thức hoặc Pin chưa được cấp!',
                      ),
                      duration: Duration(seconds: 9),
                    ));
                  }
                },
              ),
            ),

            if (perms['battery'] == false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Text(
                  '⚠️ Vào Cài đặt → Ứng dụng → Lịch Việt → Pin → '
                  'Chọn "Không hạn chế" để thông báo hoạt động khi màn hình tắt.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (perms['exactAlarm'] == false) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Text(
                  '⚠️ Vào Cài đặt → Ứng dụng → Quyền đặc biệt → '
                  'Báo thức & nhắc nhở → Bật Lịch Việt.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.cancel,
            size: 18, color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(ok ? 'OK' : 'Thiếu',
            style: TextStyle(
                color: ok ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
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
