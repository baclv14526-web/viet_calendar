import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings toàn cục dùng ValueNotifier để các screen lắng nghe thay đổi tức thì
class AppSettings {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  final ValueNotifier<bool> showLunar = ValueNotifier(true);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showLunar.value = prefs.getBool('show_lunar') ?? true;
  }

  Future<void> setShowLunar(bool value) async {
    showLunar.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_lunar', value);
  }
}
