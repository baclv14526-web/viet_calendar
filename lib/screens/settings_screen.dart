import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_settings.dart';
import '../services/notification_service.dart';
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
              AppSettings().setShowLunar(v); // cập nhật ValueNotifier ngay lập tức
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

  void _showNotificationDiagnostic(BuildContext context) {
    final ns = NotificationServiceProvider.of(context).service;
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifDiagnosticSheet(ns: ns, messenger: messenger),
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

// ─── Notification Diagnostic Sheet ───────────────────────────────────────────
// StatefulWidget để có thể reload permission status nhiều lần,
// mở lại bình thường sau khi user quay về từ Settings hệ thống.

class _NotifDiagnosticSheet extends StatefulWidget {
  final NotificationService ns;
  final ScaffoldMessengerState messenger;

  const _NotifDiagnosticSheet({
    required this.ns,
    required this.messenger,
  });

  @override
  State<_NotifDiagnosticSheet> createState() => _NotifDiagnosticSheetState();
}

class _NotifDiagnosticSheetState extends State<_NotifDiagnosticSheet>
    with WidgetsBindingObserver {
  Map<String, bool> _perms = {
    'notification': true,
    'exactAlarm': true,
    'battery': true,
  };
  List<PendingNotificationRequest> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Lắng nghe khi user quay về từ Settings hệ thống → tự reload
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Tự động reload khi app resumed (user quay về từ Settings hệ thống)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final perms = await widget.ns.checkPermissions();
    final pending = await widget.ns.getPendingNotifications();
    if (mounted) {
      setState(() {
        _perms = perms;
        _pending = pending;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allOk = _perms.values.every((v) => v);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text('🔔 Chẩn đoán Thông báo',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Kiểm tra lại',
                    onPressed: _reload,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Status tổng quan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: allOk
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: allOk
                        ? Colors.green.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    allOk ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: allOk ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    allOk
                        ? 'Tất cả quyền đã được cấp'
                        : 'Một số quyền chưa được cấp',
                    style: TextStyle(
                      color: allOk ? Colors.green[700] : Colors.orange[800],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Chi tiết từng quyền với nút mở Settings riêng lẻ
            _permissionTile(
              label: 'Hiển thị thông báo',
              granted: _perms['notification'] ?? false,
              onGrant: () async {
                await widget.ns.requestAllPermissions();
                _reload();
              },
              onOpenSettings: () async {
                await openAppSettings();
                // reload tự động qua didChangeAppLifecycleState
              },
            ),
            _permissionTile(
              label: 'Đặt báo thức chính xác',
              granted: _perms['exactAlarm'] ?? false,
              hint: 'Settings → Ứng dụng → Quyền đặc biệt → Báo thức & nhắc nhở',
              onGrant: () async {
                await widget.ns.requestAllPermissions();
                _reload();
              },
              onOpenSettings: () async {
                await openAppSettings();
              },
            ),
            _permissionTile(
              label: 'Bỏ qua tối ưu pin (Doze)',
              granted: _perms['battery'] ?? false,
              hint: 'Settings → Pin → Tối ưu hóa pin → Lịch Việt → Không tối ưu',
              onGrant: () async {
                await widget.ns.requestAllPermissions();
                _reload();
              },
              onOpenSettings: () async {
                await openAppSettings();
              },
            ),

            const Divider(height: 20),

            // Số thông báo đang chờ
            Row(children: [
              const Icon(Icons.pending_actions, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Text('Thông báo đang chờ: ${_pending.length}',
                  style: const TextStyle(fontSize: 13)),
              const Spacer(),
              if (_pending.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await widget.ns.cancelAllNotifications();
                    _reload();
                  },
                  child: const Text('Xóa hết',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
            ]),

            const SizedBox(height: 12),

            // Test buttons — KHÔNG đóng sheet, hiện kết quả inline
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Test ngay', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await widget.ns.showInstantNotification(
                        title: '🧧 Lịch Việt – Test tức thì',
                        body: 'Thông báo tức thì hoạt động! ✅',
                      );
                      if (mounted) {
                        widget.messenger.showSnackBar(const SnackBar(
                          content: Text('Đã gửi thông báo tức thì'),
                        ));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.alarm, size: 16),
                    label: const Text('Test 5 giây', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await widget.ns.scheduleTestIn5Seconds();
                      await _reload();
                      if (mounted) {
                        widget.messenger.showSnackBar(const SnackBar(
                          content: Text(
                              '⏱ Chờ 5 giây... nếu không thấy → thiếu quyền pin/báo thức!'),
                          duration: Duration(seconds: 7),
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _permissionTile({
    required String label,
    required bool granted,
    String? hint,
    required VoidCallback onGrant,
    required VoidCallback onOpenSettings,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: granted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                if (!granted && hint != null)
                  Text(hint,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
          if (!granted)
            TextButton(
              onPressed: onOpenSettings,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('Mở cài đặt',
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('OK',
                  style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
