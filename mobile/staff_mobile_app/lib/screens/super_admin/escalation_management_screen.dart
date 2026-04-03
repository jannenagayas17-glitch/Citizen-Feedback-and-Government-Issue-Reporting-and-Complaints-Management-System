import 'package:flutter/material.dart';

import '../../services/escalation_service.dart';

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
      barangay:
          _selectedBarangay == 'All Barangays' ? null : _selectedBarangay,
      priority:
          _selectedPriority == 'All Priorities' ? null : _selectedPriority,
    );
  }

  Future<void> _refresh() async {
    final future = _loadPayload();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _applyStatus(
    Map<String, dynamic> item,
    String status,
  ) async {
    final controller = TextEditingController(
      text: (item['escalation'] as Map?)?['notes']?.toString() ?? '',
    );

    final notes = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '$status Escalation',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add action notes',
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.42)),
              filled: true,
              fillColor: const Color(0xFF0E1526),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Escalation marked as $status.')),
      );
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
        final summary = Map<String, dynamic>.from(
          payload['summary'] as Map? ?? const <String, dynamic>{},
        );
        final items = (payload['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();

        final barangays = <String>{
          'All Barangays',
          ...items
              .map((item) => (item['barangay'] ?? '').toString().trim())
              .where((value) => value.isNotEmpty),
        }.toList()
          ..sort((a, b) {
            if (a == 'All Barangays') return -1;
            if (b == 'All Barangays') return 1;
            return a.compareTo(b);
          });

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
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 0 : 24,
              widget.embedded ? 0 : 20,
              widget.embedded ? 0 : 24,
              28,
            ),
            children: [
              const Text(
                'Escalations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage overdue reports that exceeded the configured escalation threshold.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.66),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _filterButton(
                    label: _selectedStatus,
                    onTap: () async {
                      final selected = await _showPicker(
                        title: 'Escalation Status',
                        options: const [
                          'All Escalations',
                          'Open',
                          'Acknowledged',
                          'Intervened',
                          'Dismissed',
                        ],
                        value: _selectedStatus,
                      );
                      if (selected == null) return;
                      setState(() => _selectedStatus = selected);
                      await _refresh();
                    },
                  ),
                  _filterButton(
                    label: _selectedBarangay,
                    onTap: () async {
                      final selected = await _showPicker(
                        title: 'Barangay',
                        options: barangays,
                        value: _selectedBarangay,
                      );
                      if (selected == null) return;
                      setState(() => _selectedBarangay = selected);
                      await _refresh();
                    },
                  ),
                  _filterButton(
                    label: _selectedPriority,
                    onTap: () async {
                      final selected = await _showPicker(
                        title: 'Priority',
                        options: const [
                          'All Priorities',
                          'Low',
                          'Normal',
                          'High',
                          'Urgent',
                        ],
                        value: _selectedPriority,
                      );
                      if (selected == null) return;
                      setState(() => _selectedPriority = selected);
                      await _refresh();
                    },
                  ),
                  _EscalationInfoChip(
                    label:
                        'Trigger: ${settings['trigger_time_hours'] ?? 72} hours',
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              if (items.isEmpty)
                const _EscalationMessageCard(
                  title: 'No escalations right now',
                  message:
                      'Reports that exceed the escalation threshold will appear here automatically.',
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _EscalationItemCard(
                      item: item,
                      onAction: _applyStatus,
                    ),
                  ),
                ),
            ],
          ),
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
        title: const Text('Escalations'),
      ),
      body: body,
    );
  }

  Future<String?> _showPicker({
    required String title,
    required List<String> options,
    required String value,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF161E30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => ListTile(
                    title: Text(
                      option,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: option == value
                        ? const Icon(Icons.check, color: Color(0xFF4C6FFF))
                        : null,
                    onTap: () => Navigator.pop(context, option),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterButton({
    required String label,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF121A2B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

class _EscalationItemCard extends StatelessWidget {
  const _EscalationItemCard({
    required this.item,
    required this.onAction,
  });

  final Map<String, dynamic> item;
  final Future<void> Function(Map<String, dynamic> item, String status) onAction;

  @override
  Widget build(BuildContext context) {
    final escalation =
        Map<String, dynamic>.from(item['escalation'] as Map? ?? const {});
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
        color: const Color(0xFF121A2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item['tracking_id'] ?? ''} • ${(item['office'] ?? '').toString()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              _EscalationInfoChip(label: 'Barangay: ${item['barangay'] ?? '-'}'),
              _EscalationInfoChip(label: 'Priority: $priority'),
              _EscalationInfoChip(label: 'Age: ${item['age_hours'] ?? 0}h'),
              _EscalationInfoChip(
                label: 'Assigned: ${(item['assigned_to'] ?? 'Unassigned').toString()}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Location: ${(item['location'] ?? '-').toString()}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
            ),
          ),
          if ((escalation['notes'] ?? '').toString().trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                (escalation['notes'] ?? '').toString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.4,
                ),
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
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tint.withValues(alpha: 0.22),
            tint.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: tint,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF182031),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.74),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _EscalationMessageCard extends StatelessWidget {
  const _EscalationMessageCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
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
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
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
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
