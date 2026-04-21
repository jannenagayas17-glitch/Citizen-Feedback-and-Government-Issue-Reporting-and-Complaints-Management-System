import 'package:flutter/material.dart';

import '../../services/escalation_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/tacloban_barangays.dart';

class EscalationManagementScreen extends StatefulWidget {
  const EscalationManagementScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<EscalationManagementScreen> createState() =>
      _EscalationManagementScreenState();
}

class _EscalationManagementScreenState
    extends State<EscalationManagementScreen> {
  final EscalationService _escalationService = EscalationService();

  late Future<Map<String, dynamic>> _payloadFuture;
  String _selectedStatus = 'All Escalations';
  String _selectedBarangay = 'All Barangays';
  String _selectedPriority = 'All Priorities';

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadPayload();
  }

  Future<Map<String, dynamic>> _loadPayload() {
    return _escalationService.getEscalations(
      escalationStatus: _selectedStatus == 'All Escalations'
          ? null
          : _selectedStatus,
      priority: _selectedPriority == 'All Priorities'
          ? null
          : _selectedPriority,
    );
  }

  Future<void> _refresh() async {
    final future = _loadPayload();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _applyStatus(Map<String, dynamic> item, String status) async {
    final controller = TextEditingController(
      text: (item['escalation'] as Map?)?['notes']?.toString() ?? '',
    );

    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = AdminThemeColors.of(dialogContext);
        return AlertDialog(
          backgroundColor: colors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '$status Escalation',
            style: TextStyle(color: colors.text),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            style: TextStyle(color: colors.text),
            decoration: InputDecoration(
              hintText: 'Add action notes',
              hintStyle: TextStyle(color: colors.mutedText),
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: colors.mutedText)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (notes == null) return;

    try {
      await _escalationService.updateEscalation(
        reportId: int.tryParse('${item['report_id']}') ?? 0,
        status: status,
        notes: notes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Escalation marked as $status.')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final body = FutureBuilder<Map<String, dynamic>>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _EscalationMessageCard(
            title: 'Unable to load escalations',
            message: snapshot.error.toString().replaceFirst('Exception: ', ''),
          );
        }

        final payload = snapshot.data ?? const <String, dynamic>{};
        final settings = Map<String, dynamic>.from(
          payload['settings'] as Map? ?? const <String, dynamic>{},
        );
        final items = (payload['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
        final barangays = _barangayOptions(items);
        final filteredItems = _filterByBarangay(items);
        final summary = _summaryForItems(filteredItems);

        if (!barangays.contains(_selectedBarangay)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _selectedBarangay = 'All Barangays');
            }
          });
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final horizontalPadding = widget.embedded ? 0.0 : 24.0;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  widget.embedded ? 0 : 20,
                  horizontalPadding,
                  28,
                ),
                children: [
                  Text(
                    'Escalations',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage overdue reports that exceeded the configured escalation threshold.',
                    style: TextStyle(color: colors.mutedText, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  if (isWide)
                    Row(
                      children: [
                        Expanded(child: _buildStatusFilter()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBarangayFilter(barangays)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildPriorityFilter()),
                        const SizedBox(width: 12),
                        _EscalationInfoChip(
                          label:
                              'Trigger: ${settings['trigger_time_hours'] ?? 72} hours',
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatusFilter(),
                        _buildBarangayFilter(barangays),
                        _buildPriorityFilter(),
                        _EscalationInfoChip(
                          label:
                              'Trigger: ${settings['trigger_time_hours'] ?? 72} hours',
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (isWide)
                    Row(
                      children: [
                        Expanded(
                          child: _EscalationMetricCard(
                            label: 'Open Escalations',
                            value: '${summary['open'] ?? 0}',
                            tint: const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _EscalationMetricCard(
                            label: 'Acknowledged',
                            value: '${summary['acknowledged'] ?? 0}',
                            tint: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _EscalationMetricCard(
                            label: 'Intervened',
                            value: '${summary['intervened'] ?? 0}',
                            tint: const Color(0xFF22C55E),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _EscalationMetricCard(
                            label: 'Dismissed',
                            value: '${summary['dismissed'] ?? 0}',
                            tint: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _EscalationMetricCard(
                          label: 'Open Escalations',
                          value: '${summary['open'] ?? 0}',
                          tint: const Color(0xFFEF4444),
                        ),
                        _EscalationMetricCard(
                          label: 'Acknowledged',
                          value: '${summary['acknowledged'] ?? 0}',
                          tint: const Color(0xFFF59E0B),
                        ),
                        _EscalationMetricCard(
                          label: 'Intervened',
                          value: '${summary['intervened'] ?? 0}',
                          tint: const Color(0xFF22C55E),
                        ),
                        _EscalationMetricCard(
                          label: 'Dismissed',
                          value: '${summary['dismissed'] ?? 0}',
                          tint: const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  if (filteredItems.isEmpty)
                    _EscalationEmptyState(
                      triggerHours:
                          int.tryParse(
                            '${settings['trigger_time_hours'] ?? 72}',
                          ) ??
                          72,
                    )
                  else
                    ...filteredItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _EscalationItemCard(
                          item: item,
                          onAction: _applyStatus,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
        title: const Text('Escalations'),
      ),
      body: body,
    );
  }

  List<String> _barangayOptions(List<Map<String, dynamic>> items) {
    final values = <String, String>{};

    void addValue(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      values.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }

    for (final barangay in taclobanBarangays) {
      addValue(barangay);
    }

    for (final item in items) {
      addValue((item['barangay'] ?? '').toString());
    }

    final sortedValues = values.values.toList()..sort(_compareBarangays);
    return ['All Barangays', ...sortedValues];
  }

  List<Map<String, dynamic>> _filterByBarangay(
    List<Map<String, dynamic>> items,
  ) {
    if (_selectedBarangay == 'All Barangays') {
      return items;
    }

    return items.where((item) {
      return _matchesBarangay(
        (item['barangay'] ?? '').toString(),
        _selectedBarangay,
      );
    }).toList();
  }

  Map<String, int> _summaryForItems(List<Map<String, dynamic>> items) {
    int countStatus(String status) => items.where((item) {
      final escalation = item['escalation'];
      if (escalation is Map) {
        return (escalation['status'] ?? 'Open').toString() == status;
      }
      return status == 'Open';
    }).length;

    return {
      'total': items.length,
      'open': countStatus('Open'),
      'acknowledged': countStatus('Acknowledged'),
      'intervened': countStatus('Intervened'),
      'dismissed': countStatus('Dismissed'),
    };
  }

  int _compareBarangays(String a, String b) {
    final aNumber = _barangayNumber(a);
    final bNumber = _barangayNumber(b);
    if (aNumber != null && bNumber != null && aNumber != bNumber) {
      return aNumber.compareTo(bNumber);
    }
    if (aNumber != null && bNumber == null) return -1;
    if (aNumber == null && bNumber != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  double? _barangayNumber(String value) {
    final match = RegExp(
      r'^barangay\s+(\d+)(?:-([a-z]))?',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    final suffix = match.group(2);
    if (suffix == null) return number;
    return number + ((suffix.toLowerCase().codeUnitAt(0) - 96) / 10);
  }

  bool _matchesBarangay(String reportBarangay, String selectedBarangay) {
    if (reportBarangay.trim().toLowerCase() ==
        selectedBarangay.trim().toLowerCase()) {
      return true;
    }

    final reportNumber = _barangayNumber(reportBarangay);
    final selectedNumber = _barangayNumber(selectedBarangay);
    return reportNumber != null &&
        selectedNumber != null &&
        reportNumber == selectedNumber;
  }

  Widget _buildStatusFilter() {
    return _filterDropdown(
      value: _selectedStatus,
      items: const [
        'All Escalations',
        'Open',
        'Acknowledged',
        'Intervened',
        'Dismissed',
      ],
      onChanged: (selected) {
        if (selected == null) return;
        setState(() => _selectedStatus = selected);
        _refresh();
      },
    );
  }

  Widget _buildBarangayFilter(List<String> barangays) {
    return _filterDropdown(
      value: _selectedBarangay,
      items: barangays,
      onChanged: (selected) {
        if (selected == null) return;
        setState(() => _selectedBarangay = selected);
      },
    );
  }

  Widget _buildPriorityFilter() {
    return _filterDropdown(
      value: _selectedPriority,
      items: const ['All Priorities', 'Low', 'Normal', 'High', 'Urgent'],
      onChanged: (selected) {
        if (selected == null) return;
        setState(() => _selectedPriority = selected);
        _refresh();
      },
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final colors = AdminThemeColors.of(context);
    return SizedBox(
      width: 320,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        isExpanded: true,
        menuMaxHeight: 360,
        dropdownColor: colors.panel,
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.panel,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ),
        iconEnabledColor: colors.mutedText,
        style: TextStyle(color: colors.text, fontSize: 14),
        selectedItemBuilder: (context) => items
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text, fontSize: 14),
                ),
              ),
            )
            .toList(),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text, fontSize: 14),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _EscalationItemCard extends StatelessWidget {
  const _EscalationItemCard({required this.item, required this.onAction});

  final Map<String, dynamic> item;
  final Future<void> Function(Map<String, dynamic> item, String status)
  onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final escalation = Map<String, dynamic>.from(
      item['escalation'] as Map? ?? const {},
    );
    final status = (escalation['status'] ?? 'Open').toString();
    final priority = (item['priority'] ?? 'Normal').toString();
    final statusColor = switch (status) {
      'Acknowledged' => const Color(0xFFF59E0B),
      'Intervened' => const Color(0xFF22C55E),
      'Dismissed' => const Color(0xFF94A3B8),
      _ => const Color(0xFFEF4444),
    };

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['title'] ?? 'Escalated report').toString(),
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item['tracking_id'] ?? ''} • ${(item['office'] ?? '').toString()}',
                      style: TextStyle(color: colors.mutedText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _EscalationInfoChip(
                label: 'Barangay: ${item['barangay'] ?? '-'}',
              ),
              _EscalationInfoChip(label: 'Priority: $priority'),
              _EscalationInfoChip(label: 'Age: ${item['age_hours'] ?? 0}h'),
              _EscalationInfoChip(
                label:
                    'Assigned: ${(item['assigned_to'] ?? 'Unassigned').toString()}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Location: ${(item['location'] ?? '-').toString()}',
            style: TextStyle(color: colors.mutedText, fontSize: 13),
          ),
          if ((escalation['notes'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                (escalation['notes'] ?? '').toString(),
                style: TextStyle(color: colors.mutedText, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionButton(
                label: 'Acknowledge',
                color: const Color(0xFFF59E0B),
                onTap: () => onAction(item, 'Acknowledged'),
              ),
              _actionButton(
                label: 'Intervene',
                color: const Color(0xFF2563EB),
                onTap: () => onAction(item, 'Intervened'),
              ),
              _actionButton(
                label: 'Dismiss',
                color: const Color(0xFF94A3B8),
                onTap: () => onAction(item, 'Dismissed'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(label),
    );
  }
}

class _EscalationMetricCard extends StatelessWidget {
  const _EscalationMetricCard({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint.withValues(alpha: 0.22), tint.withValues(alpha: 0.10)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tint,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: TextStyle(
              color: tint,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EscalationInfoChip extends StatelessWidget {
  const _EscalationInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.mutedText, fontSize: 13),
      ),
    );
  }
}

class _EscalationEmptyState extends StatelessWidget {
  const _EscalationEmptyState({required this.triggerHours});

  final int triggerHours;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No escalations right now',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reports that stay unresolved for more than $triggerHours hours will appear here automatically for super admin review.',
                      style: TextStyle(color: colors.mutedText, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _EscalationInfoChip(label: 'Auto-detected from overdue reports'),
              _EscalationInfoChip(label: 'Tracks intervention status'),
              _EscalationInfoChip(label: 'Follows settings trigger threshold'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EscalationMessageCard extends StatelessWidget {
  const _EscalationMessageCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
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
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
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
              style: TextStyle(color: colors.mutedText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
