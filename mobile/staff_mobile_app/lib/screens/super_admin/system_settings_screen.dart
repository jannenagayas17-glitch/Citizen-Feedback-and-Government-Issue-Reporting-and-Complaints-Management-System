import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/system_settings_service.dart';
import '../../utils/app_theme_controller.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final SystemSettingsService _settingsService = SystemSettingsService();
  final AuthService _authService = AuthService();

  late Future<Map<String, dynamic>> _payloadFuture;
  Map<String, dynamic> _currentUser = const <String, dynamic>{};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadPayload();
  }

  Future<Map<String, dynamic>> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      _authService.getCurrentUser(),
      _settingsService.getSettings(),
    ]);

    _currentUser = Map<String, dynamic>.from(results[0] as Map);

    return <String, dynamic>{
      'user': _currentUser,
      'settings': Map<String, dynamic>.from(results[1] as Map),
    };
  }

  Future<void> _save(Map<String, dynamic> settings) async {
    setState(() => _isSaving = true);
    try {
      final updated = await _settingsService.updateSettings(settings);
      if (!mounted) return;
      setState(() {
        _payloadFuture = Future.value(<String, dynamic>{
          'user': _currentUser,
          'settings': updated,
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: confirmPassword,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final body = FutureBuilder<Map<String, dynamic>>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _SettingsMessageCard(
            title: 'Unable to load settings',
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
          );
        }

        final payload = snapshot.data ?? const <String, dynamic>{};
        final user = Map<String, dynamic>.from(
          payload['user'] as Map? ?? const <String, dynamic>{},
        );
        final settings = Map<String, dynamic>.from(
          payload['settings'] as Map? ?? const <String, dynamic>{},
        );

        return _SettingsContent(
          embedded: widget.embedded,
          user: user,
          initialSettings: settings,
          isSaving: _isSaving,
          onSave: _save,
          onChangePassword: _changePassword,
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: body,
    );
  }
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent({
    required this.embedded,
    required this.user,
    required this.initialSettings,
    required this.isSaving,
    required this.onSave,
    required this.onChangePassword,
  });

  final bool embedded;
  final Map<String, dynamic> user;
  final Map<String, dynamic> initialSettings;
  final bool isSaving;
  final Future<void> Function(Map<String, dynamic> settings) onSave;
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  })
  onChangePassword;

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  static const List<int> _dueHourOptions = <int>[24, 48, 72, 96, 120];
  static const List<String> _dueUnitOptions = <String>['Hours', 'Days'];
  static const List<int> _triggerHourOptions = <int>[24, 48, 72, 96, 120, 168];
  static const List<String> _notificationOptions = <String>[
    'Email',
    'Email & In-App',
    'In-App Only',
  ];
  static const List<String> _priorityOptions = <String>[
    'Low Priority',
    'Normal Priority',
    'High Priority',
    'Critical Priority',
  ];

  late bool _enableAlerts;
  late bool _escalationNotifications;
  late bool _feedbackNotifications;
  late int _defaultDueHours;
  late String _defaultDueUnit;
  late int _triggerTimeHours;
  late String _notificationChannel;
  late String _priority;
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings != widget.initialSettings) {
      _hydrate();
    }
  }

  void _hydrate() {
    final notifications = Map<String, dynamic>.from(
      widget.initialSettings['notifications'] as Map? ??
          const <String, dynamic>{},
    );
    final reportSettings = Map<String, dynamic>.from(
      widget.initialSettings['report_settings'] as Map? ??
          const <String, dynamic>{},
    );
    final escalationSettings = Map<String, dynamic>.from(
      widget.initialSettings['escalation_settings'] as Map? ??
          const <String, dynamic>{},
    );

    _enableAlerts = notifications['enable_alerts'] != false;
    _escalationNotifications =
        notifications['escalation_notifications'] != false;
    _feedbackNotifications = notifications['feedback_notifications'] != false;
    _defaultDueHours = _sanitizeIntOption(
      int.tryParse('${reportSettings['default_due_hours'] ?? 48}') ?? 48,
      _dueHourOptions,
      48,
    );
    _defaultDueUnit = _sanitizeStringOption(
      (reportSettings['default_due_unit'] ?? 'Hours').toString(),
      _dueUnitOptions,
      'Hours',
    );
    _triggerTimeHours = _sanitizeIntOption(
      int.tryParse('${escalationSettings['trigger_time_hours'] ?? 72}') ?? 72,
      _triggerHourOptions,
      72,
    );
    _notificationChannel = _sanitizeStringOption(
      (escalationSettings['notification_channel'] ?? 'Email & In-App')
          .toString(),
      _notificationOptions,
      'Email & In-App',
    );
    _priority = _sanitizeStringOption(
      (escalationSettings['priority'] ?? 'High Priority').toString(),
      _priorityOptions,
      'High Priority',
    );
  }

  int _sanitizeIntOption(int value, List<int> options, int fallback) {
    return options.contains(value) ? value : fallback;
  }

  String _sanitizeStringOption(
    String value,
    List<String> options,
    String fallback,
  ) {
    return options.contains(value) ? value : fallback;
  }

  void _clearPasswordErrors() {
    _currentPasswordError = null;
    _newPasswordError = null;
    _confirmPasswordError = null;
  }

  Future<void> _submit() async {
    final payload = <String, dynamic>{
      'notifications': <String, dynamic>{
        'enable_alerts': _enableAlerts,
        'escalation_notifications': _escalationNotifications,
        'feedback_notifications': _feedbackNotifications,
      },
      'report_settings': <String, dynamic>{
        'default_due_hours': _defaultDueHours,
        'default_due_unit': _defaultDueUnit,
      },
      'escalation_settings': <String, dynamic>{
        'trigger_time_hours': _triggerTimeHours,
        'notification_channel': _notificationChannel,
        'priority': _priority,
      },
    };

    await widget.onSave(payload);
  }

  Future<void> _submitPasswordChange() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _clearPasswordErrors();
      if (currentPassword.isEmpty) {
        _currentPasswordError = 'Enter your current password.';
      }
      if (newPassword.isEmpty) {
        _newPasswordError = 'Enter a new password.';
      } else if (newPassword.length < 8) {
        _newPasswordError = 'New password must be at least 8 characters.';
      } else if (newPassword == currentPassword) {
        _newPasswordError =
            'New password must be different from the current password.';
      }
      if (confirmPassword.isEmpty) {
        _confirmPasswordError = 'Confirm your new password.';
      } else if (confirmPassword != newPassword) {
        _confirmPasswordError = 'Password confirmation does not match.';
      }
    });

    if (_currentPasswordError != null ||
        _newPasswordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      await widget.onChangePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        if (message.toLowerCase().contains('current password')) {
          _currentPasswordError = message;
        } else if (message.toLowerCase().contains('confirm')) {
          _confirmPasswordError = message;
        } else {
          _newPasswordError = message;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final name = (widget.user['name'] ?? 'Super Admin').toString();
    final email = (widget.user['email'] ?? 'superadmin@citytrack.local')
        .toString();
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth == double.infinity
            ? MediaQuery.of(context).size.width
            : constraints.maxWidth;
        final isWide = contentWidth >= 1080;
        final panelWidth = isWide ? (contentWidth - 18) / 2 : contentWidth;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 0 : 24,
            widget.embedded ? 0 : 20,
            widget.embedded ? 0 : 24,
            28,
          ),
          children: [
            Text(
              'Settings',
              style: TextStyle(
                color: colors.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage system settings and configurations.',
              style: TextStyle(color: colors.mutedText, fontSize: 14),
            ),
            const SizedBox(height: 18),
            _SettingsPanel(
              title: 'Appearance',
              child: _AppearanceCard(
                themeController: AppThemeScope.of(context),
              ),
            ),
            const SizedBox(height: 18),
            _SettingsPanel(
              title: 'Account Settings',
              child: Wrap(
                spacing: 18,
                runSpacing: 18,
                children: [
                  SizedBox(
                    width: panelWidth,
                    child: _AccountCard(name: name, email: email),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: _PasswordSettingsCard(
                      currentPasswordController: _currentPasswordController,
                      newPasswordController: _newPasswordController,
                      confirmPasswordController: _confirmPasswordController,
                      currentPasswordError: _currentPasswordError,
                      newPasswordError: _newPasswordError,
                      confirmPasswordError: _confirmPasswordError,
                      isSaving: _isChangingPassword,
                      obscureCurrentPassword: _obscureCurrentPassword,
                      obscureNewPassword: _obscureNewPassword,
                      obscureConfirmPassword: _obscureConfirmPassword,
                      onCurrentPasswordChanged: () {
                        if (_currentPasswordError != null) {
                          setState(() => _currentPasswordError = null);
                        }
                      },
                      onNewPasswordChanged: () {
                        if (_newPasswordError != null) {
                          setState(() => _newPasswordError = null);
                        }
                      },
                      onConfirmPasswordChanged: () {
                        if (_confirmPasswordError != null) {
                          setState(() => _confirmPasswordError = null);
                        }
                      },
                      onToggleCurrentPassword: () {
                        setState(
                          () => _obscureCurrentPassword =
                              !_obscureCurrentPassword,
                        );
                      },
                      onToggleNewPassword: () {
                        setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        );
                      },
                      onToggleConfirmPassword: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                      onSubmit: _submitPasswordChange,
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    child: _ToggleSettingsCard(
                      enableAlerts: _enableAlerts,
                      escalationNotifications: _escalationNotifications,
                      feedbackNotifications: _feedbackNotifications,
                      onEnableAlertsChanged: (value) =>
                          setState(() => _enableAlerts = value),
                      onEscalationNotificationsChanged: (value) =>
                          setState(() => _escalationNotifications = value),
                      onFeedbackNotificationsChanged: (value) =>
                          setState(() => _feedbackNotifications = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _SettingsPanel(
                    title: 'Notification Settings',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledDropdown<int>(
                                label: 'Default Due Time',
                                value: _defaultDueHours,
                                items: _dueHourOptions,
                                itemLabel: (value) => '$value',
                                onChanged: (value) =>
                                    setState(() => _defaultDueHours = value),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _LabeledDropdown<String>(
                                label: 'Unit',
                                value: _defaultDueUnit,
                                items: _dueUnitOptions,
                                itemLabel: (value) => value,
                                onChanged: (value) =>
                                    setState(() => _defaultDueUnit = value),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _LabeledDropdown<int>(
                          label: 'Escalation Trigger Time',
                          value: _triggerTimeHours,
                          trailingText: 'Hours',
                          items: _triggerHourOptions,
                          itemLabel: (value) => '$value',
                          onChanged: (value) =>
                              setState(() => _triggerTimeHours = value),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _SettingsPanel(
                    title: 'Escalation Settings',
                    child: Column(
                      children: [
                        _LabeledDropdown<String>(
                          label: 'Escalation Notification',
                          value: _notificationChannel,
                          items: _notificationOptions,
                          itemLabel: (value) => value,
                          onChanged: (value) =>
                              setState(() => _notificationChannel = value),
                        ),
                        const SizedBox(height: 16),
                        _LabeledDropdown<String>(
                          label: 'Escalation Priority',
                          value: _priority,
                          items: _priorityOptions,
                          itemLabel: (value) => value,
                          onChanged: (value) =>
                              setState(() => _priority = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: widget.isSaving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C54D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.themeController});

  final AppThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final isDark = themeController.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF111A2D), Color(0xFF17213A)]
              : const [Color(0xFFFFFFFF), Color(0xFFEAF2FF)],
        ),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDark ? const Color(0xFF243455) : const Color(0xFFDCEBFF),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? const Color(0xFFF0A43B) : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isDark
                      ? 'Comfortable low-light dashboard colors.'
                      : 'Brighter workspace for daytime monitoring.',
                  style: TextStyle(color: colors.mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            onChanged: themeController.setDarkMode,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2563EB),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF93C5FD),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final initials = name.trim().isEmpty
        ? 'SA'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0])
              .join()
              .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.softPanel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF5137CF),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(email, style: TextStyle(color: colors.mutedText)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordSettingsCard extends StatelessWidget {
  const _PasswordSettingsCard({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.currentPasswordError,
    required this.newPasswordError,
    required this.confirmPasswordError,
    required this.isSaving,
    required this.obscureCurrentPassword,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.onCurrentPasswordChanged,
    required this.onNewPasswordChanged,
    required this.onConfirmPasswordChanged,
    required this.onToggleCurrentPassword,
    required this.onToggleNewPassword,
    required this.onToggleConfirmPassword,
    required this.onSubmit,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final String? currentPasswordError;
  final String? newPasswordError;
  final String? confirmPasswordError;
  final bool isSaving;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final VoidCallback onCurrentPasswordChanged;
  final VoidCallback onNewPasswordChanged;
  final VoidCallback onConfirmPasswordChanged;
  final VoidCallback onToggleCurrentPassword;
  final VoidCallback onToggleNewPassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    InputDecoration inputDecoration({
      required String label,
      String? errorText,
      required bool obscureText,
      required VoidCallback onToggleVisibility,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.mutedText),
        errorText: errorText,
        filled: true,
        fillColor: colors.input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF2E62FF), width: 1.4),
        ),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility,
            color: colors.mutedText,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.softPanel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change Password',
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use a secure password with at least 8 characters.',
            style: TextStyle(color: colors.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: currentPasswordController,
            obscureText: obscureCurrentPassword,
            style: TextStyle(color: colors.text),
            onChanged: (_) => onCurrentPasswordChanged(),
            decoration: inputDecoration(
              label: 'Current password',
              errorText: currentPasswordError,
              obscureText: obscureCurrentPassword,
              onToggleVisibility: onToggleCurrentPassword,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newPasswordController,
            obscureText: obscureNewPassword,
            style: TextStyle(color: colors.text),
            onChanged: (_) => onNewPasswordChanged(),
            decoration: inputDecoration(
              label: 'New password',
              errorText: newPasswordError,
              obscureText: obscureNewPassword,
              onToggleVisibility: onToggleNewPassword,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmPasswordController,
            obscureText: obscureConfirmPassword,
            style: TextStyle(color: colors.text),
            onChanged: (_) => onConfirmPasswordChanged(),
            decoration: inputDecoration(
              label: 'Confirm new password',
              errorText: confirmPasswordError,
              obscureText: obscureConfirmPassword,
              onToggleVisibility: onToggleConfirmPassword,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: isSaving ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF163FCB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSettingsCard extends StatelessWidget {
  const _ToggleSettingsCard({
    required this.enableAlerts,
    required this.escalationNotifications,
    required this.feedbackNotifications,
    required this.onEnableAlertsChanged,
    required this.onEscalationNotificationsChanged,
    required this.onFeedbackNotificationsChanged,
  });

  final bool enableAlerts;
  final bool escalationNotifications;
  final bool feedbackNotifications;
  final ValueChanged<bool> onEnableAlertsChanged;
  final ValueChanged<bool> onEscalationNotificationsChanged;
  final ValueChanged<bool> onFeedbackNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return Column(
      children: [
        _SwitchTile(
          label: 'Enable Alerts',
          value: enableAlerts,
          onChanged: onEnableAlertsChanged,
        ),
        Divider(color: colors.border, height: 18),
        _SwitchTile(
          label: 'Escalation Notifications',
          value: escalationNotifications,
          onChanged: onEscalationNotificationsChanged,
        ),
        Divider(color: colors.border, height: 18),
        _SwitchTile(
          label: 'Feedback Notifications',
          value: feedbackNotifications,
          onChanged: onFeedbackNotificationsChanged,
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colors.text, fontSize: 15),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF2E62FF),
        ),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.trailingText,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Text(trailingText!, style: TextStyle(color: colors.mutedText)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.input,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: colors.panel,
              style: TextStyle(color: colors.text),
              iconEnabledColor: colors.mutedText,
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsMessageCard extends StatelessWidget {
  const _SettingsMessageCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.settings_outlined,
              color: Color(0xFF7B8CC2),
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsColors {
  const _SettingsColors({
    required this.background,
    required this.panel,
    required this.softPanel,
    required this.input,
    required this.border,
    required this.text,
    required this.mutedText,
  });

  final Color background;
  final Color panel;
  final Color softPanel;
  final Color input;
  final Color border;
  final Color text;
  final Color mutedText;

  static _SettingsColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return _SettingsColors(
        background: const Color(0xFF0B1020),
        panel: const Color(0xFF121A2B),
        softPanel: Colors.white.withValues(alpha: 0.02),
        input: const Color(0xFF0F1524),
        border: Colors.white.withValues(alpha: 0.08),
        text: Colors.white,
        mutedText: Colors.white.withValues(alpha: 0.64),
      );
    }

    return _SettingsColors(
      background: const Color(0xFFF5F8FC),
      panel: Colors.white,
      softPanel: const Color(0xFFF1F6FF),
      input: const Color(0xFFF8FAFC),
      border: const Color(0xFFDDE7F5),
      text: const Color(0xFF0F172A),
      mutedText: const Color(0xFF64748B),
    );
  }
}
