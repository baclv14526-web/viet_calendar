import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../services/calendar_bloc.dart';
import '../models/calendar_event.dart';
import '../services/database_service.dart';
import 'add_event_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CalendarEvent> _allEvents = [];
  List<CalendarEvent> _filteredEvents = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final events = await DatabaseService().getAllEvents();
    // Chỉ hiển thị sự kiện cá nhân (không phải ngày lễ hệ thống)
    events.sort((a, b) => a.date.compareTo(b.date));
    if (mounted) {
      setState(() {
        _allEvents = events;
        _filteredEvents = events;
        _loading = false;
      });
    }
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      _filteredEvents = _allEvents
          .where((e) =>
              e.title.toLowerCase().contains(query.toLowerCase()) ||
              (e.description
                      ?.toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false))
          .toList();
    });
  }

  // Sự kiện sắp tới (từ hôm nay trở đi)
  List<CalendarEvent> get _upcoming {
    final today = DateTime.now();
    return _filteredEvents
        .where((e) => !e.date.isBefore(DateTime(today.year, today.month, today.day)))
        .toList();
  }

  // Sự kiện đã qua
  List<CalendarEvent> get _past {
    final today = DateTime.now();
    return _filteredEvents
        .where((e) => e.date.isBefore(DateTime(today.year, today.month, today.day)))
        .toList()
        .reversed
        .toList(); // mới nhất lên đầu
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: _selectionMode
            ? Text('Đã chọn ${_selectedIds.length}',
                style: const TextStyle(fontSize: 16))
            : const Text('Quản lý sự kiện'),
        actions: [
          if (_selectionMode) ...[
            // Chọn tất cả
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIds.length == _filteredEvents.length
                    ? 'Bỏ chọn tất cả'
                    : 'Chọn tất cả',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            // Xóa đã chọn
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Xóa đã chọn',
              onPressed:
                  _selectedIds.isEmpty ? null : _deleteSelected,
            ),
            // Thoát chọn
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  setState(() {
                    _selectionMode = false;
                    _selectedIds.clear();
                  }),
            ),
          ] else ...[
            // Bật chọn nhiều
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Chọn nhiều để xóa',
              onPressed: () => setState(() => _selectionMode = true),
            ),
            // Xóa tất cả sự kiện đã qua
            IconButton(
              icon: const Icon(Icons.auto_delete_outlined),
              tooltip: 'Xóa sự kiện đã qua',
              onPressed: _past.isEmpty ? null : _deletePastEvents,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm sự kiện...',
                    hintStyle:
                        const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white54, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white54, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _filter('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white12,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Sắp tới (${_upcoming.length})'),
                  Tab(text: 'Đã qua (${_past.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_upcoming, isPast: false),
                _buildList(_past, isPast: true),
              ],
            ),
    );
  }

  // ─── List ─────────────────────────────────────────────────────────────────

  Widget _buildList(List<CalendarEvent> events, {required bool isPast}) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPast
                  ? Icons.history
                  : Icons.event_available,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              isPast
                  ? 'Không có sự kiện đã qua'
                  : 'Không có sự kiện sắp tới',
              style: TextStyle(color: Colors.grey[400], fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Group theo tháng
    final grouped = <String, List<CalendarEvent>>{};
    for (final e in events) {
      final key = DateFormat('MMMM yyyy', 'vi_VN').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: 72 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: grouped.length,
      itemBuilder: (context, i) {
        final month = grouped.keys.elementAt(i);
        final monthEvents = grouped[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _monthHeader(month),
            ...monthEvents.map((e) => _eventTile(e, isPast)),
          ],
        );
      },
    );
  }

  Widget _monthHeader(String month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        month.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _eventTile(CalendarEvent event, bool isPast) {
    final isSelected = _selectedIds.contains(event.id);
    final theme = Theme.of(context);

    return Slidable(
      key: ValueKey(event.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _editEvent(event),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Sửa',
          ),
          SlidableAction(
            onPressed: (_) => _confirmDelete(event),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Xóa',
          ),
        ],
      ),
      child: InkWell(
        onTap: _selectionMode
            ? () => _toggleSelect(event.id)
            : () => _editEvent(event),
        onLongPress: () {
          if (!_selectionMode) {
            setState(() {
              _selectionMode = true;
              _selectedIds.add(event.id);
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Checkbox khi selection mode
              if (_selectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Icon(Icons.check_circle,
                            color: theme.colorScheme.primary,
                            key: const ValueKey('checked'))
                        : Icon(Icons.radio_button_unchecked,
                            color: Colors.grey[400],
                            key: const ValueKey('unchecked')),
                  ),
                ),

              // Color dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isPast
                      ? event.color.withOpacity(0.4)
                      : event.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isPast
                            ? Colors.grey[500]
                            : theme.colorScheme.onSurface,
                        decoration: isPast
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('EEE, dd/MM/yyyy', 'vi_VN')
                              .format(event.date),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                        if (event.startTime != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 11, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(
                            event.startTime!.format(context),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                    if (event.description?.isNotEmpty == true)
                      Text(
                        event.description!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Notification icon
              if (event.hasNotification && !isPast)
                Icon(Icons.notifications_active,
                    size: 16,
                    color: event.color.withOpacity(0.7)),

              // Arrow khi không phải selection mode
              if (!_selectionMode)
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredEvents.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_filteredEvents.map((e) => e.id));
      }
    });
  }

  void _editEvent(CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<CalendarBloc>(),
          child: AddEventScreen(
              initialDate: event.date, event: event),
        ),
      ),
    ).then((_) => _loadEvents());
  }

  void _confirmDelete(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện'),
        content: Text('Xóa "${event.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteOne(event);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOne(CalendarEvent event) async {
    context.read<CalendarBloc>().add(DeleteEvent(event.id));
    await _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${event.title}"'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    final count = ids.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sự kiện'),
        content: Text('Xóa $count sự kiện đã chọn?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xóa $count'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final id in ids) {
      context.read<CalendarBloc>().add(DeleteEvent(id));
    }

    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });

    await _loadEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa $count sự kiện')),
      );
    }
  }

  Future<void> _deletePastEvents() async {
    final pastCount = _past.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.auto_delete, color: Colors.orange),
          SizedBox(width: 8),
          Text('Dọn dẹp'),
        ]),
        content: Text(
            'Xóa $pastCount sự kiện đã qua?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xóa $pastCount'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    for (final e in _past) {
      context.read<CalendarBloc>().add(DeleteEvent(e.id));
    }

    await _loadEvents();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Đã xóa $pastCount sự kiện đã qua')),
      );
    }
  }
}
