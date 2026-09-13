import 'package:flutter/material.dart';
import '../utils/app_preferences.dart';

class NavigationProvider extends ChangeNotifier {
  String _navigationMode = 'collapsed_sidebar';

  String get navigationMode => _navigationMode;

  NavigationProvider() {
    _load();
  }

  Future<void> _load() async {
    _navigationMode = await AppPreferences.getNavigationMode();
    notifyListeners();
  }

  Future<void> reload() => _load();

  Future<void> setNavigationMode(String mode) async {
    if (_navigationMode == mode) return;
    _navigationMode = mode;
    await AppPreferences.setNavigationMode(mode);
    notifyListeners();
  }
}
