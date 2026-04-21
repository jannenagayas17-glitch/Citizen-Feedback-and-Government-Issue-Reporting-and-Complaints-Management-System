import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
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
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _AddDepartmentDialog(authService: _authService),
    );

    if (created == true) {
      await _refresh();
    }
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

  List<Map<String, dynamic>> _officeRecords(
    List<dynamic> offices,
    Map<String, dynamic> user,
  ) {
    final isSuperAdmin = _isSuperAdmin(user);
    final assignedDepartment = _departmentLabel(user);
    final filtered = offices
        .whereType<Map<String, dynamic>>()
        .where((office) => (office['name'] ?? '').toString().trim().isNotEmpty)
        .where((office) {
          if (isSuperAdmin) return true;
          return (office['name'] ?? '').toString().trim() == assignedDepartment;
        })
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
    final colors = AdminThemeColors.of(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.embedded || isWide
          ? null
          : AppBar(
              backgroundColor: colors.background,
              foregroundColor: colors.text,
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
                      message: snapshot.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                    ),
                  ],
                );
              }

              final payload = snapshot.data!;
              final user = payload.user;
              final currentRole = (user['role'] ?? '').toString().trim();
              final isSuperAdmin = _isSuperAdmin(user);
              final departmentName = _departmentLabel(user);
              final offices = _officeRecords(payload.offices, user);
              final reports = payload.reports
                  .whereType<Map<String, dynamic>>()
                  .toList();

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
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF36A2FF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentRole == 'super_admin'
                              ? 'Tacloban City Government - All Offices and Departments'
                              : 'Tacloban City Government - $departmentName',
                          style: TextStyle(
                            color: colors.mutedText,
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
                                onViewReports: () =>
                                    _openReportsForOffice(office),
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
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.22),
        ),
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
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'CityTrack PH',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
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
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.34),
                fontSize: 12,
              ),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            adminName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
    final colors = AdminThemeColors.of(context);
    final name = (office['name'] ?? 'Unnamed office').toString();
    final description = (office['description'] ?? '').toString().trim();
    final code = (office['code'] ?? '').toString().trim();
    final accent = _accentForOffice(name);
    final icon = _iconForOffice(name);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
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
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description.isNotEmpty
                          ? description
                          : (code.isNotEmpty
                                ? code
                                : 'Tacloban City Government'),
                      style: TextStyle(color: colors.mutedText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _statusChip(
                label: isActive ? 'Active' : 'Inactive',
                color: isActive
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
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
                  colors.text,
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
                  metrics.rejected > 0
                      ? '${metrics.resolved}'
                      : '${metrics.inProgress}',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View Reports',
                        style: TextStyle(
                          color: colors.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.mutedText,
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
    final colors = AdminThemeColors.of(context);
    return Container(
      width: 185,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: colors.mutedText, fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _messageCard({required String title, required String message}) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: colors.mutedText, height: 1.4)),
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

class _AddDepartmentDialog extends StatefulWidget {
  const _AddDepartmentDialog({required this.authService});

  final AuthService authService;

  @override
  State<_AddDepartmentDialog> createState() => _AddDepartmentDialogState();
}

class _AddDepartmentDialogState extends State<_AddDepartmentDialog> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      return 'Department name is required.';
    }

    if (name.length < 3) {
      return 'Department name must be at least 3 characters.';
    }

    if (!RegExp(r"^[A-Za-z0-9 ,.&'()/-]+$").hasMatch(name)) {
      return 'Department name contains unsupported characters.';
    }

    if (code.isNotEmpty && !RegExp(r'^[A-Za-z0-9-]{2,16}$').hasMatch(code)) {
      return 'Short code must be 2 to 16 letters, numbers, or hyphens.';
    }

    if (description.length > 180) {
      return 'Description must be 180 characters or fewer.';
    }

    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _formError = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final response = await widget.authService.createOffice(
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Department added successfully.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: colors.panel,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(colors),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_formError != null) ...[
                          _errorBanner(colors, _formError!),
                          const SizedBox(height: 16),
                        ],
                        _field(
                          controller: _nameController,
                          label: 'Department Name',
                          hint: 'Example: City Health Office',
                          icon: Icons.apartment_rounded,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _codeController,
                          label: 'Short Code',
                          hint: 'Example: CHO',
                          icon: Icons.tag_rounded,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: 'Short purpose or service scope',
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 18),
                        _previewCard(colors),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.text,
                                  side: BorderSide(color: colors.border),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_business_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  _saving ? 'Creating...' : 'Create Department',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AdminThemeColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: const Icon(Icons.add_business_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Department',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Register a new city office so reports and staff can be linked correctly.',
                  style: TextStyle(color: Color(0xDDEAF4FF), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(AdminThemeColors colors, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFEF4444),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    final colors = AdminThemeColors.of(context);
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: colors.mutedText),
        hintStyle: TextStyle(color: colors.mutedText.withValues(alpha: 0.68)),
        prefixIcon: Icon(icon, color: colors.mutedText, size: 20),
        filled: true,
        fillColor: colors.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
        ),
      ),
    );
  }

  Widget _previewCard(AdminThemeColors colors) {
    final name = _nameController.text.trim().isEmpty
        ? 'New City Department'
        : _nameController.text.trim();
    final code = _codeController.text.trim().isEmpty
        ? 'Department code'
        : _codeController.text.trim().toUpperCase();
    final description = _descriptionController.text.trim().isEmpty
        ? 'This department will appear in report routing, admin registration, and citizen office selections.'
        : _descriptionController.text.trim();

    return AnimatedBuilder(
      animation: Listenable.merge([
        _nameController,
        _codeController,
        _descriptionController,
      ]),
      builder: (context, _) {
        final liveName = _nameController.text.trim().isEmpty
            ? name
            : _nameController.text.trim();
        final liveCode = _codeController.text.trim().isEmpty
            ? code
            : _codeController.text.trim().toUpperCase();
        final liveDescription = _descriptionController.text.trim().isEmpty
            ? description
            : _descriptionController.text.trim();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.input,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.apartment_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            liveName,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            liveCode,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      liveDescription,
                      style: TextStyle(color: colors.mutedText, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
