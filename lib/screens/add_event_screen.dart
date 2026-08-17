import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/calendar_event.dart';
import '../services/calendar_bloc.dart';

class AddEventScreen extends StatefulWidget {
  final DateTime initialDate;
  final CalendarEvent? event; // null = add mode

  const AddEventScreen({
    super.key,
    required this.initialDate,
    this.event,
  });

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  EventType _eventType = EventType.personal;
  RepeatType _repeatType = RepeatType.none;
  Color _color = const Color(0xFF2196F3);
  bool _hasNotification = true;
  int _notificationMinutes = 30;
  bool _isAllDay = false;

  bool get _isEditing => widget.event != null;

  final List<Color> _colorOptions = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFFE91E63), // Pink
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFF5722), // Deep Orange
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFF9800), // Orange
    const Color(0xFF795548), // Brown
    const Color(0xFF607D8B), // Blue Grey
    const Color(0xFFD32F2F), // Red
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _selectedDate = e?.date ?? widget.initialDate;
    _startTime = e?.startTime;
    _endTime = e?.endTime;
    _eventType = e?.type ?? EventType.personal;
    _repeatType = e?.repeatType ?? RepeatType.none;
    _color = e?.color ?? const Color(0xFF2196F3);
    _hasNotification = e?.hasNotification ?? true;
    _notificationMinutes = e?.notificationMinutesBefore ?? 30;
    _isAllDay = e?.isAllDay ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa sự kiện' : 'Sự kiện mới'),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('LƯU',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Color picker strip
            _buildColorPicker(),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Tiêu đề sự kiện *',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontSize: 18),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Date
            _buildSection(
              icon: Icons.calendar_today,
              title: 'Ngày & Giờ',
              child: Column(
                children: [
                  _buildDateTile(),
                  SwitchListTile(
                    value: _isAllDay,
                    onChanged: (v) => setState(() => _isAllDay = v),
                    title: const Text('Cả ngày'),
                    secondary:
                        const Icon(Icons.wb_sunny_outlined, color: Colors.orange),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!_isAllDay) ...[
                    _buildTimeTile(
                      label: 'Giờ bắt đầu',
                      time: _startTime,
                      onTap: () => _pickTime(isStart: true),
                    ),
                    _buildTimeTile(
                      label: 'Giờ kết thúc',
                      time: _endTime,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Repeat
            _buildSection(
              icon: Icons.repeat,
              title: 'Lặp lại',
              child: DropdownButtonFormField<RepeatType>(
                value: _repeatType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                items: [
                  _repeatItem(RepeatType.none, 'Không lặp'),
                  _repeatItem(RepeatType.daily, 'Hàng ngày'),
                  _repeatItem(RepeatType.weekly, 'Hàng tuần'),
                  _repeatItem(RepeatType.monthly, 'Hàng tháng'),
                  _repeatItem(RepeatType.yearly, 'Hàng năm'),
                ],
                onChanged: (v) => setState(() => _repeatType = v!),
              ),
            ),
            const SizedBox(height: 12),

            // Notification
            _buildSection(
              icon: Icons.notifications_outlined,
              title: 'Thông báo',
              child: Column(
                children: [
                  SwitchListTile(
                    value: _hasNotification,
                    onChanged: (v) => setState(() => _hasNotification = v),
                    title: const Text('Bật nhắc nhở'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_hasNotification) ...[
                    const Divider(),
                    const Text('Nhắc trước:',
                        style: TextStyle(color: Colors.grey)),
                    Wrap(
                      spacing: 8,
                      children: [5, 10, 15, 30, 60, 120, 1440]
                          .map((min) => ChoiceChip(
                                label: Text(_formatMinutes(min)),
                                selected: _notificationMinutes == min,
                                onSelected: (s) {
                                  if (s) {
                                    setState(
                                        () => _notificationMinutes = min);
                                  }
                                },
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Type
            _buildSection(
              icon: Icons.label_outline,
              title: 'Loại sự kiện',
              child: DropdownButtonFormField<EventType>(
                value: _eventType,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                items: [
                  _typeItem(EventType.personal, 'Cá nhân', Icons.person),
                  _typeItem(EventType.reminder, 'Nhắc nhở', Icons.alarm),
                ],
                onChanged: (v) => setState(() => _eventType = v!),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _colorOptions.length,
        itemBuilder: (context, index) {
          final c = _colorOptions[index];
          final isSelected = c.value == _color.value;
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 44 : 36,
              height: isSelected ? 44 : 36,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.black38, width: 3)
                    : null,
                boxShadow: isSelected
                    ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: _color),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _color)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(
        DateFormat('EEEE, d MMMM yyyy', 'vi_VN').format(_selectedDate),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _pickDate,
    );
  }

  Widget _buildTimeTile({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time),
      title: Text(label),
      trailing: Text(
        time?.format(context) ?? 'Chưa chọn',
        style: TextStyle(
          color: time != null ? _color : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  DropdownMenuItem<RepeatType> _repeatItem(RepeatType type, String label) {
    return DropdownMenuItem(value: type, child: Text(label));
  }

  DropdownMenuItem<EventType> _typeItem(
      EventType type, String label, IconData icon) {
    return DropdownMenuItem(
      value: type,
      child: Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ]),
    );
  }

  String _formatMinutes(int min) {
    if (min < 60) return '${min}p';
    if (min == 60) return '1 giờ';
    if (min == 120) return '2 giờ';
    if (min == 1440) return '1 ngày';
    return '${min ~/ 60}h';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final event = CalendarEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      date: _selectedDate,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      type: _eventType,
      repeatType: _repeatType,
      color: _color,
      hasNotification: _hasNotification,
      notificationMinutesBefore: _hasNotification ? _notificationMinutes : null,
      isAllDay: _isAllDay,
    );

    final bloc = context.read<CalendarBloc>();
    if (_isEditing) {
      bloc.add(UpdateEvent(event));
    } else {
      bloc.add(AddEvent(event));
    }

    Navigator.pop(context);
  }
}
