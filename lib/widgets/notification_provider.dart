import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// InheritedWidget để truy cập NotificationService từ bất kỳ đâu trong widget tree
class NotificationServiceProvider extends InheritedWidget {
  final NotificationService service;

  const NotificationServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  static NotificationServiceProvider of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<NotificationServiceProvider>();
    assert(provider != null, 'NotificationServiceProvider không tìm thấy trong widget tree');
    return provider!;
  }

  @override
  bool updateShouldNotify(NotificationServiceProvider oldWidget) => false;
}
