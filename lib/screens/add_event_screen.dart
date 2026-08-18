import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/calendar_event.dart';
import '../services/calendar_bloc.dart';

class AddEventScreen extends StatefulWidget {
  final DateTime initialDate;
  final CalendarEvent? event;

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
  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  static const List<Color> _colorOptions = [
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFF4CAF50),
    Color(0xFFFF5722),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFD32F2F),
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: _color,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Sửa sự kiện' : 'Sự kiện mới',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'LƯU',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _colorPicker(),
            const SizedBox(height: 16),

            // Tiêu đề
            TextFormField(
              controller: _titleCtrl,
              autofocus: !_isEditing,
              decoration: InputDecoration(
                labelText: 'Tiêu đề sự kiện *',
                hintText: 'Nhập tên sự kiện...',
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _color, width: 2),
                ),
              ),
              style: const TextStyle(fontSize: 17),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Vui lòng nhập tiêu đề' : null,
            ),
            const SizedBox(height: 12),

            // Ghi chú
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                hintText: 'Thêm mô tả...',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _color, width: 2),
                ),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Ngày & Giờ
            _section(
              icon: Icons.calendar_today,
              title: 'Ngày & Giờ',
              child: Column(
                children: [
                  _dateTile(),
                  const Divider(height: 1),
                  SwitchListTile(
                    dense: true,
                    value: _isAllDay,
                    onChanged: (v) => setState(() => _isAllDay = v),
                    title: const Text('Cả ngày'),
                    secondary: const Icon(Icons.wb_sunny_outlined,
                        color: Colors.orange, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  if (!_isAllDay) ...[
                    const Divider(height: 1),
                    _timeTile('Giờ bắt đầu', _startTime,
                        () => _pickTime(isStart: true)),
                    const Divider(height: 1),
                    _timeTile('Giờ kết thúc', _endTime,
                        () => _pickTime(isStart: false)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Lặp lại
            _section(
              icon: Icons.repeat,
              title: 'Lặp lại',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RepeatType>(
                  value: _repeatType,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _repeatType = v!),
                  items: [
                    _ddItem(RepeatType.none, 'Không lặp', Icons.block),
                    _ddItem(RepeatType.daily, 'Hàng ngày', Icons.today),
                    _ddItem(RepeatType.weekly, 'Hàng tuần',
                        Icons.view_week_outlined),
                    _ddItem(RepeatType.monthly, 'Hàng tháng',
                        Icons.calendar_view_month_outlined),
                    _ddItem(RepeatType.yearly, 'Hàng năm',
                        Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Thông báo
            _section(
              icon: Icons.notifications_outlined,
              title: 'Nhắc nhở',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    dense: true,
                    value: _hasNotification,
                    onChanged: (v) => setState(() => _hasNotification = v),
                    title: const Text('Bật thông báo nhắc nhở'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  if (_hasNotification) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                      child: Text('Nhắc trước:',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [5, 10, 15, 30, 60, 120, 1440]
                          .map((min) => ChoiceChip(
                                label: Text(_fmtMin(min)),
                                selected: _notificationMinutes == min,
                                selectedColor: _color.withOpacity(0.2),
                                onSelected: (s) {
                                  if (s) setState(() => _notificationMinutes = min);
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Loại sự kiện
            _section(
              icon: Icons.label_outline,
              title: 'Loại sự kiện',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<EventType>(
                  value: _eventType,
                  isExpanded: true,
                  onChanged: (v) => setState(() => _eventType = v!),
                  items: [
                    _ddItem(EventType.personal, 'Cá nhân', Icons.person),
                    _ddItem(EventType.reminder, 'Nhắc nhở', Icons.alarm),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _colorPicker() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _colorOptions.length,
        itemBuilder: (_, i) {
          final c = _colorOptions[i];
          final selected = c.value == _color.value;
          return GestureDetector(
            onTap: () => setState(() => _color = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: selected ? 44 : 38,
              height: selected ? 44 : 38,
              margin: EdgeInsets.symmetric(
                  horizontal: 4, vertical: selected ? 2 : 5),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border:
                    selected ? Border.all(color: Colors.white, width: 3) : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: c.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: _color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _color,
                      fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  Widget _dateTile() {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.event, size: 20),
      title: Text(
        DateFormat('EEEE, d MMMM yyyy', 'vi_VN').format(_selectedDate),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: _pickDate,
    );
  }

  Widget _timeTile(String label, TimeOfDay? time, VoidCallback onTap) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.access_time, size: 20),
      title: Text(label),
      trailing: Text(
        time?.format(context) ?? 'Chưa chọn',
        style: TextStyle(
            color: time != null ? _color : Colors.grey,
            fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  DropdownMenuItem<T> _ddItem<T>(T value, String label, IconData icon) {
    return DropdownMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text(label),
      ]),
    );
  }

  String _fmtMin(int min) {
    if (min < 60) return '${min}p';
    if (min == 60) return '1 giờ';
    if (min == 120) return '2 giờ';
    if (min == 1440) return '1 ngày';
    return '${min ~/ 60}h';
  }

  // ─── Pickers ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2050),
      locale: const Locale('vi', 'VN'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _color),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _color),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Tự đặt giờ kết thúc = bắt đầu + 1h nếu chưa có
          if (_endTime == null) {
            final endH = (picked.hour + 1) % 24;
            _endTime = TimeOfDay(hour: endH, minute: picked.minute);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final event = CalendarEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: _titleCtrl.text.trim(),
      description:
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      date: _selectedDate,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      type: _eventType,
      repeatType: _repeatType,
      color: _color,
      hasNotification: _hasNotification,
      notificationMinutesBefore:
          _hasNotification ? _notificationMinutes : null,
      isAllDay: _isAllDay,
    );

    if (_isEditing) {
      context.read<CalendarBloc>().add(UpdateEvent(event));
    } else {
      context.read<CalendarBloc>().add(AddEvent(event));
    }

    if (mounted) Navigator.pop(context);
  }
}
