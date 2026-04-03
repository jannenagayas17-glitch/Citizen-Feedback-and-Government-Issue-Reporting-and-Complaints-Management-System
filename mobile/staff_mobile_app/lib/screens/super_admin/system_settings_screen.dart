import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/system_settings_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({
    super.key,
    this.embedded = false,
  });

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

  @override
  Widget build(BuildContext context) {
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
        );
      },
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1020),
        foregroundColor: Colors.white,
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
  });

  final bool embedded;
  final Map<String, dynamic> user;
  final Map<String, dynamic> initialSettings;
  final bool isSaving;
  final Future<void> Function(Map<String, dynamic> settings) onSave;

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

  @override
  void initState() {
    super.initState();
    _hydrate();
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
      widget.initialSettings['notifications'] as Map? ?? const <String, dynamic>{},
    );
    final reportSettings = Map<String, dynamic>.from(
      widget.initialSettings['report_settings'] as Map? ?? const <String, dynamic>{},
    );
    final escalationSettings = Map<String, dynamic>.from(
      widget.initialSettings['escalation_settings'] as Map? ?? const <String, dynamic>{},
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

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['name'] ?? 'Super Admin').toString();
    final email = (widget.user['email'] ?? 'superadmin@citytrack.local').toString();
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
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage system settings and configurations.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 14,
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
                    child: _AccountCard(
                      name: name,
                      email: email,
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
                          onChanged: (value) => setState(() => _priority = value),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
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
  const _SettingsPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'SA'
        : name.trim().split(RegExp(r'\s+')).take(2).map((part) => part[0]).join().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                    ),
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
    return Column(
      children: [
        _SwitchTile(
          label: 'Enable Alerts',
          value: enableAlerts,
          onChanged: onEnableAlertsChanged,
        ),
        const Divider(color: Color(0x1AFFFFFF), height: 18),
        _SwitchTile(
          label: 'Escalation Notifications',
          value: escalationNotifications,
          onChanged: onEscalationNotificationsChanged,
        ),
        const Divider(color: Color(0x1AFFFFFF), height: 18),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1524),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A2337),
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white70,
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
  const _SettingsMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF121A2B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
