import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  static const String _globalKey = 'citizen_theme_mode';
  static const String _userKeyPrefix = 'citizen_theme_mode_user_';

  ThemeMode _themeMode = ThemeMode.dark;
  String? _activeStorageKey;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    _activeStorageKey = _globalKey;
    await _loadFromKey(_globalKey);
  }

  Future<void> loadForUser(Map<String, dynamic> user) async {
    final userKey = _storageKeyForUser(user);
    _activeStorageKey = userKey;
    await _loadFromKey(userKey);
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) {
      return;
    }

    _themeMode = nextMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _activeStorageKey ?? _globalKey,
      enabled ? 'dark' : 'light',
    );
  }

  Future<void> _loadFromKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key) ?? prefs.getString(_globalKey);
    final nextMode = stored == 'light' ? ThemeMode.light : ThemeMode.dark;

    if (_themeMode != nextMode) {
      _themeMode = nextMode;
      notifyListeners();
    }
  }

  String _storageKeyForUser(Map<String, dynamic> user) {
    final id = user['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return '$_userKeyPrefix$id';
    }

    final email = user['email']?.toString().trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      return '$_userKeyPrefix$email';
    }

    return _globalKey;
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'AppThemeScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}
