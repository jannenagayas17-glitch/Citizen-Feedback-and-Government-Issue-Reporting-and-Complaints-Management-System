import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  String _scope = 'global';
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    await _loadForScope(_scope);
  }

  Future<void> loadForUser(Map<String, dynamic> user) async {
    final nextScope = _scopeForUser(user);
    if (_scope == nextScope) {
      return;
    }

    _scope = nextScope;
    await _loadForScope(_scope);
    notifyListeners();
  }

  Future<void> _loadForScope(String scope) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final savedMode =
        prefs.getString(_scopedThemeModeKey(scope)) ??
        prefs.getString(_themeModeKey);
    _themeMode = savedMode == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) {
      return;
    }

    _themeMode = nextMode;
    notifyListeners();

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(
      _scopedThemeModeKey(_scope),
      enabled ? 'dark' : 'light',
    );
  }

  String _scopedThemeModeKey(String scope) => '${_themeModeKey}_$scope';

  String _scopeForUser(Map<String, dynamic> user) {
    final id = (user['id'] ?? '').toString().trim();
    if (id.isNotEmpty) {
      return 'user_$id';
    }

    final email = (user['email'] ?? '').toString().trim().toLowerCase();
    if (email.isNotEmpty) {
      return 'email_$email';
    }

    return 'global';
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
    assert(scope != null, 'AppThemeScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}
