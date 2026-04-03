import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../admin/complaint_management_screen.dart';

class ManageOfficesScreen extends StatefulWidget {
  const ManageOfficesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ManageOfficesScreen> createState() => _ManageOfficesScreenState();
}

class _ManageOfficesScreenState extends State<ManageOfficesScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();

  late Future<_DepartmentPayload> _payloadFuture;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadPayload();
  }

  Future<_DepartmentPayload> _loadPayload() async {
    final user = await _authService.getCurrentUser();
    final role = (user['role'] ?? '').toString().trim();
    final results = await Future.wait<dynamic>([
      _authService.getOffices(includeInactive: role == 'super_admin'),
      _reportService.getAdminReports(),
    ]);

    return _DepartmentPayload(
      user: user,
      offices: results[0] as List<dynamic>,
      reports: results[1] as List<dynamic>,
    );
  }

  Future<void> _refresh() async {
    final future = _loadPayload();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _openReportsForOffice(Map<String, dynamic> office) async {
    final officeName = (office['name'] ?? '').toString().trim();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintManagementScreen(
          initialOfficeName: officeName.isEmpty ? null : officeName,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openAddOfficeDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2234),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Add Department',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(controller: nameController, label: 'Department name'),
                const SizedBox(height: 12),
                _dialogField(controller: codeController, label: 'Short code'),
                const SizedBox(height: 12),
                _dialogField(
                  controller: descriptionController,
                  label: 'Description',
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.82)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (created != true) {
      nameController.dispose();
      codeController.dispose();
      descriptionController.dispose();
      return;
    }

    try {
      final response = await _authService.createOffice(
        name: nameController.text.trim(),
        code: codeController.text.trim(),
        description: descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Department added successfully',
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      nameController.dispose();
      codeController.dispose();
      descriptionController.dispose();
    }
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.72)),
      filled: true,
      fillColor: const Color(0xFF161D2F),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _dialogDecoration(label),
    );
  }

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final officeName = (office['name'] ?? '').toString().trim();
      if (officeName.isNotEmpty) return officeName;
    }
    final department = (user['department'] ?? '').toString().trim();
    return department.isEmpty ? 'Department' : department;
  }

  bool _isSuperAdmin(Map<String, dynamic> user) =>
      (user['role'] ?? '').toString().trim() == 'super_admin';

  List<Map<String, dynamic>> _officeRecords(List<dynamic> offices) {
    final filtered = offices
        .whereType<Map<String, dynamic>>()
        .where((office) => (office['name'] ?? '').toString().trim().isNotEmpty)
        .toList();

    filtered.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return filtered;
  }

  _OfficeMetrics _metricsForOffice(
    Map<String, dynamic> office,
    List<Map<String, dynamic>> reports,
  ) {
    final officeName = (office['name'] ?? '').toString().trim();
    final officeReports = reports.where((report) {
      final officeMap = report['office'];
      if (officeMap is Map<String, dynamic>) {
        return (officeMap['name'] ?? '').toString().trim() == officeName;
      }
      return false;
    }).toList();

    int countStatus(String status) => officeReports
        .where((report) => (report['status'] ?? '').toString().trim() == status)
        .length;

    return _OfficeMetrics(
      total: officeReports.length,
      pending: countStatus('Pending'),
      inProgress: countStatus('In Progress'),
      resolved: countStatus('Resolved'),
      rejected: countStatus('Rejected'),
      newReports: countStatus('New'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: widget.embedded || isWide
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0B1020),
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Departments'),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF4C6FFF),
          child: FutureBuilder<_DepartmentPayload>(
            future: _payloadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _messageCard(
                      title: 'Unable to load departments',
                      message: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                    ),
                  ],
                );
              }

              final payload = snapshot.data!;
              final user = payload.user;
              final currentRole = (user['role'] ?? '').toString().trim();
              final isSuperAdmin = _isSuperAdmin(user);
              final departmentName = _departmentLabel(user);
              final offices = _officeRecords(payload.offices);
              final reports = payload.reports.whereType<Map<String, dynamic>>().toList();

              return ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomSafeArea),
                children: [
                  if (!widget.embedded && isWide)
                    _topBar(
                      departmentName: departmentName,
                      adminName: (user['name'] ?? 'Admin User').toString(),
                      isSuperAdmin: isSuperAdmin,
                    ),
                  if (!widget.embedded && isWide) const SizedBox(height: 18),
                  Text(
                    'Departments',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, color: Color(0xFF36A2FF), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tacloban City Government · $departmentName',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.56),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (currentRole == 'super_admin')
                        FilledButton.icon(
                          onPressed: _openAddOfficeDialog,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Department'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (offices.isEmpty)
                    _messageCard(
                      title: 'No departments found',
                      message:
                          'Departments added in the system will appear here automatically.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1280
                            ? 3
                            : constraints.maxWidth >= 760
                                ? 2
                                : 1;
                        final cardWidth =
                            (constraints.maxWidth - ((columns - 1) * 16)) /
                            columns;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: offices.map((office) {
                            final metrics = _metricsForOffice(office, reports);
                            final isActive = office['is_active'] != false;
                            return SizedBox(
                              width: cardWidth,
                              child: _departmentCard(
                                office: office,
                                metrics: metrics,
                                isActive: isActive,
                                onViewReports: () => _openReportsForOffice(office),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar({
    required String departmentName,
    required String adminName,
    required bool isSuperAdmin,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13182A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF2557D6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            'CityTrack PH',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(width: 14),
          if (isSuperAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2018),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF6F4D2C)),
              ),
              child: const Text(
                'SUPER ADMIN',
                style: TextStyle(
                  color: Color(0xFFF0A43B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Text(
              'Admin Portal',
              style: TextStyle(color: Colors.white.withOpacity(0.34), fontSize: 12),
            ),
          const Spacer(),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1C2238),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Color(0xFFF4B04F),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 15,
            backgroundColor: isSuperAdmin
                ? const Color(0xFF6B5CF6)
                : const Color(0xFF6D5EF8),
            child: Text(
              adminName.isEmpty ? 'A' : adminName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            adminName,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _departmentCard({
    required Map<String, dynamic> office,
    required _OfficeMetrics metrics,
    required bool isActive,
    required VoidCallback onViewReports,
  }) {
    final name = (office['name'] ?? 'Unnamed office').toString();
    final description = (office['description'] ?? '').toString().trim();
    final code = (office['code'] ?? '').toString().trim();
    final accent = _accentForOffice(name);
    final icon = _iconForOffice(name);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13182A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.isNotEmpty
                          ? description
                          : (code.isNotEmpty ? code : 'Tacloban City Government'),
                      style: TextStyle(color: Colors.white.withOpacity(0.58), fontSize: 13),
                    ),
                  ],
                ),
              ),
              _statusChip(
                label: isActive ? 'Active' : 'Inactive',
                color: isActive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Total Reports',
                  '${metrics.total}',
                  '+${metrics.newReports} this month',
                  Colors.white,
                  const Color(0xFF68D9A2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  'Pending',
                  '${metrics.pending}',
                  '${metrics.pending} Pending',
                  const Color(0xFFF0B34C),
                  const Color(0xFFF0B34C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  metrics.rejected > 0 ? 'Resolved' : 'In Progress',
                  metrics.rejected > 0 ? '${metrics.resolved}' : '${metrics.inProgress}',
                  metrics.rejected > 0
                      ? '+${metrics.resolved > 0 ? metrics.resolved : 0} today'
                      : '+${metrics.inProgress > 0 ? metrics.inProgress : 0} today',
                  metrics.rejected > 0
                      ? const Color(0xFFE8857A)
                      : const Color(0xFF5F92FF),
                  metrics.rejected > 0
                      ? const Color(0xFFE8857A)
                      : const Color(0xFF68D9A2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: onViewReports,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF355CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View Reports'),
              ),
              const Spacer(),
              InkWell(
                onTap: onViewReports,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'View Reports',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.60),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(
    String title,
    String value,
    String subtitle,
    Color valueColor,
    Color subtitleColor,
  ) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171D2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.56), fontSize: 12)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _accentForOffice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('water') || lower.contains('health')) {
      return const Color(0xFF355CFF);
    }
    if (lower.contains('street') ||
        lower.contains('engineer') ||
        lower.contains('repair')) {
      return const Color(0xFFD39A4C);
    }
    if (lower.contains('electrical') || lower.contains('assessor')) {
      return const Color(0xFF6E58D9);
    }
    if (lower.contains('tourism') || lower.contains('mayor')) {
      return const Color(0xFF4F7FFF);
    }
    return const Color(0xFF355CFF);
  }

  IconData _iconForOffice(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('water') || lower.contains('health')) {
      return Icons.water_drop_rounded;
    }
    if (lower.contains('street') ||
        lower.contains('engineer') ||
        lower.contains('repair')) {
      return Icons.handyman_rounded;
    }
    if (lower.contains('electrical')) {
      return Icons.lightbulb_rounded;
    }
    if (lower.contains('tourism')) {
      return Icons.beach_access_rounded;
    }
    if (lower.contains('treasurer')) {
      return Icons.account_balance_wallet_rounded;
    }
    return Icons.apartment_rounded;
  }

  Widget _statusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Widget _messageCard({required String title, required String message}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13182A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DepartmentPayload {
  const _DepartmentPayload({
    required this.user,
    required this.offices,
    required this.reports,
  });

  final Map<String, dynamic> user;
  final List<dynamic> offices;
  final List<dynamic> reports;
}

class _OfficeMetrics {
  const _OfficeMetrics({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.resolved,
    required this.rejected,
    required this.newReports,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int resolved;
  final int rejected;
  final int newReports;
}
