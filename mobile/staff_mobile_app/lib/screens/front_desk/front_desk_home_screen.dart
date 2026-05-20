import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/app_routes.dart';
import '../../utils/file_download.dart';
import '../admin/report_detail_dialog.dart';
import 'walk_in_complaint_screen.dart';

String _formatDateTime(dynamic raw) {
  final parsed = DateTime.tryParse((raw ?? '').toString())?.toLocal();
  if (parsed == null) {
    return 'To be confirmed';
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} - $hour:$minute $suffix';
}

class FrontDeskHomeScreen extends StatefulWidget {
  const FrontDeskHomeScreen({super.key});

  @override
  State<FrontDeskHomeScreen> createState() => _FrontDeskHomeScreenState();
}

class _FrontDeskHomeScreenState extends State<FrontDeskHomeScreen> {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final TextEditingController _searchController = TextEditingController();

  late Future<_FrontDeskHomeData> _homeFuture;
  Map<String, dynamic>? _currentUser;
  String _statusFilter = 'All Status';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHome();
  }

  Future<_FrontDeskHomeData> _loadHome() async {
    final results = await Future.wait<dynamic>([
      _authService.getCurrentUser(),
      _dashboardService.getDashboardStats(),
      _reportService.getFrontDeskReportsPage(
        page: _page,
        status: _statusFilter == 'All Status' ? null : _statusFilter,
        search: _searchController.text.trim(),
      ),
    ]);

    final user = Map<String, dynamic>.from(results[0] as Map);
    _currentUser = user;

    return _FrontDeskHomeData(
      user: user,
      stats: Map<String, dynamic>.from(results[1] as Map),
      reportsPage: results[2] as AdminReportPage,
    );
  }

  Future<void> _refresh() async {
    final future = _loadHome();
    setState(() => _homeFuture = future);
    await future;
  }

  Future<void> _applySearch() async {
    setState(() {
      _page = 1;
      _homeFuture = _loadHome();
    });
    await _homeFuture;
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _openNewWalkInComplaint() async {
    final createdReport = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const WalkInComplaintScreen()),
    );

    if (!mounted || createdReport == null) {
      return;
    }

    await _refresh();
    if (!mounted) {
      return;
    }

    await _showClaimSlipDialog(createdReport);
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    final reportId = _reportId(report);
    if (reportId == null) {
      return;
    }

    await showAdminReportDetailDialog(context: context, reportId: reportId);
    await _refresh();
  }

  Future<void> _showClaimSlipDialog(Map<String, dynamic> report) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _ClaimSlipDialog(
        report: report,
        frontDeskUser: _currentUser ?? const <String, dynamic>{},
        onDownload: () => _downloadClaimSlip(report),
      ),
    );
  }

  Future<void> _downloadClaimSlip(Map<String, dynamic> report) async {
    final html = _buildClaimSlipHtml(report, _currentUser ?? const {});
    final referenceNumber =
        (report['printable_reference_number'] ?? 'walk-in-claim-slip')
            .toString()
            .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '-');

    try {
      await downloadFile(
        bytes: utf8.encode(html),
        fileName: '$referenceNumber.html',
        mimeType: 'text/html;charset=utf-8',
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printable claim slip downloaded.')),
      );
    } on UnsupportedError {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Printable HTML download is currently available on the web portal build.',
          ),
        ),
      );
    }
  }

  String _buildClaimSlipHtml(
    Map<String, dynamic> report,
    Map<String, dynamic> user,
  ) {
    final escape = const HtmlEscape();
    String safe(Object? value) => escape.convert((value ?? '').toString());

    final category = _categoryLabel(report);
    final office = _officeLabel(report);
    final complainant = _complainantName(report);
    final address = _complainantAddress(report);
    final submittedAt = _formatDateTime(report['created_at']);
    final expectedReturnAt = _formatDateTime(report['expected_return_at']);
    final status = (report['status'] ?? 'New').toString();
    final referenceNumber =
        (report['printable_reference_number'] ?? 'Pending reference').toString();
    final frontDeskName = (user['name'] ?? 'Front Desk Staff').toString();
    final title = (report['title'] ?? 'Walk-in complaint').toString();

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${safe(referenceNumber)} Claim Slip</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f5f7fb; color: #0b1d51; margin: 0; padding: 32px; }
    .sheet { max-width: 760px; margin: 0 auto; background: #ffffff; border: 2px solid #0b1d51; border-radius: 18px; padding: 28px; }
    .header { border-bottom: 2px solid #d1c6ad; padding-bottom: 18px; margin-bottom: 20px; }
    .title { font-size: 28px; font-weight: 800; margin: 0 0 6px; }
    .subtitle { color: #797596; margin: 0; }
    .badge { display: inline-block; padding: 8px 14px; border-radius: 999px; background: #0b1d51; color: white; font-weight: 700; margin-top: 14px; }
    .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; margin: 18px 0; }
    .card { background: #f8f3ea; border: 1px solid #d1c6ad; border-radius: 14px; padding: 14px; }
    .label { color: #797596; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 6px; }
    .value { color: #0b1d51; font-size: 15px; font-weight: 700; line-height: 1.4; }
    .message { margin-top: 22px; padding: 16px; border-radius: 14px; background: #edf2fb; border: 1px solid #bbada0; color: #0b1d51; line-height: 1.6; }
    .footer { margin-top: 24px; color: #797596; font-size: 12px; }
    @media print { body { background: white; padding: 0; } .sheet { border-radius: 0; margin: 0; box-shadow: none; } }
  </style>
</head>
<body>
  <div class="sheet">
    <div class="header">
      <div class="title">Citizen Walk-in Claim Slip</div>
      <p class="subtitle">Tacloban City Citizen Feedback and Complaint Assistance</p>
      <div class="badge">${safe(referenceNumber)}</div>
    </div>
    <div class="grid">
      <div class="card"><div class="label">Complainant</div><div class="value">${safe(complainant)}</div></div>
      <div class="card"><div class="label">Category / Title</div><div class="value">${safe(category)}<br>${safe(title)}</div></div>
      <div class="card"><div class="label">Assigned Department</div><div class="value">${safe(office)}</div></div>
      <div class="card"><div class="label">Status</div><div class="value">${safe(status)}</div></div>
      <div class="card"><div class="label">Address / Barangay</div><div class="value">${safe(address)}</div></div>
      <div class="card"><div class="label">Submitted</div><div class="value">${safe(submittedAt)}</div></div>
      <div class="card"><div class="label">Expected Return</div><div class="value">${safe(expectedReturnAt)}</div></div>
      <div class="card"><div class="label">Assisted By</div><div class="value">${safe(frontDeskName)}</div></div>
    </div>
    <div class="message">
      Please keep this slip and return on the scheduled date for a status update. The assigned department may contact you sooner if clarification or additional evidence is needed.
    </div>
    <div class="footer">
      This receipt confirms that your complaint was received through the city front desk assistance process.
    </div>
  </div>
</body>
</html>
''';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text('Front Desk Assistance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.backgroundGradient),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: colors.primary,
          child: FutureBuilder<_FrontDeskHomeData>(
            future: _homeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _Panel(
                      colors: colors,
                      child: Text(
                        snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        style: TextStyle(color: colors.text),
                      ),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final reports = data.reportsPage.reports;
              final stats = data.stats;
              final user = data.user;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _HeroBanner(
                    colors: colors,
                    staffName: (user['name'] ?? 'Front Desk Staff').toString(),
                    department:
                        (user['department'] ?? 'Assigned Department').toString(),
                    onCreateComplaint: _openNewWalkInComplaint,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        colors: colors,
                        label: 'Assisted Reports',
                        value: '${stats['total_reports'] ?? 0}',
                        icon: Icons.assignment_outlined,
                      ),
                      _StatCard(
                        colors: colors,
                        label: 'Pending Follow-up',
                        value: '${stats['pending'] ?? 0}',
                        icon: Icons.schedule_outlined,
                      ),
                      _StatCard(
                        colors: colors,
                        label: 'Resolved',
                        value: '${stats['resolved'] ?? 0}',
                        icon: Icons.verified_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Walk-in Complaints',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Only complaints assisted by your front desk account appear here.',
                          style: TextStyle(color: colors.mutedText),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: colors.text),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search reference, complainant, or title',
                                  hintStyle: TextStyle(
                                    color: colors.mutedText,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: colors.mutedText,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: 'Search',
                                    onPressed: _applySearch,
                                    icon: Icon(
                                      Icons.arrow_forward_rounded,
                                      color: colors.mutedText,
                                    ),
                                  ),
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
                                onSubmitted: (_) => _applySearch(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<String>(
                                initialValue: _statusFilter,
                                dropdownColor: colors.panel,
                                style: TextStyle(color: colors.text),
                                decoration: InputDecoration(
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
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All Status',
                                    child: Text('All Status'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'New',
                                    child: Text('New'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Pending',
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In Progress',
                                    child: Text('In Progress'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Resolved',
                                    child: Text('Resolved'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _statusFilter = value ?? 'All Status';
                                    _page = 1;
                                    _homeFuture = _loadHome();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (reports.isEmpty)
                          Text(
                            'No assisted complaints match your filters yet.',
                            style: TextStyle(color: colors.mutedText),
                          )
                        else
                          ...reports.map((report) => _ReportCard(
                            colors: colors,
                            report: report,
                            onView: () => _openReportDetail(report),
                            onSlip: () => _showClaimSlipDialog(report),
                          )),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Page ${data.reportsPage.currentPage} of ${data.reportsPage.lastPage}',
                              style: TextStyle(color: colors.mutedText),
                            ),
                            const Spacer(),
                            _PagerButton(
                              label: 'Previous',
                              enabled: data.reportsPage.hasPreviousPage,
                              onTap: data.reportsPage.hasPreviousPage
                                  ? () {
                                      setState(() {
                                        _page =
                                            data.reportsPage.currentPage - 1;
                                        _homeFuture = _loadHome();
                                      });
                                    }
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            _PagerButton(
                              label: 'Next',
                              enabled: data.reportsPage.hasNextPage,
                              onTap: data.reportsPage.hasNextPage
                                  ? () {
                                      setState(() {
                                        _page =
                                            data.reportsPage.currentPage + 1;
                                        _homeFuture = _loadHome();
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  int? _reportId(Map<String, dynamic> report) {
    final raw = report['id'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse('$raw');
  }

  String _complainantName(Map<String, dynamic> report) {
    return (report['complainant_name'] ??
            report['reporter_name'] ??
            report['user']?['name'] ??
            'Walk-in complainant')
        .toString();
  }

  String _complainantAddress(Map<String, dynamic> report) {
    return (report['complainant_address'] ??
            report['reporter_address'] ??
            report['barangay'] ??
            report['location'] ??
            'Address not provided')
        .toString();
  }

  String _categoryLabel(Map<String, dynamic> report) {
    return (report['category']?['name'] ?? report['category_name'] ?? 'General')
        .toString();
  }

  String _officeLabel(Map<String, dynamic> report) {
    return (report['office']?['name'] ?? 'Assigned Department').toString();
  }

  String _formatDateTime(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (parsed == null) {
      return 'To be confirmed';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · $hour:$minute $suffix';
  }
}

class _FrontDeskHomeData {
  const _FrontDeskHomeData({
    required this.user,
    required this.stats,
    required this.reportsPage,
  });

  final Map<String, dynamic> user;
  final Map<String, dynamic> stats;
  final AdminReportPage reportsPage;
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.colors,
    required this.staffName,
    required this.department,
    required this.onCreateComplaint,
  });

  final AdminThemeColors colors;
  final String staffName;
  final String department;
  final VoidCallback onCreateComplaint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Walk-in Complaint Assistance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome, $staffName. Submit assisted complaints for citizens who cannot use the mobile app, then print a clean claim slip with the expected return date.',
            style: const TextStyle(
              color: Color(0xDDEAF4FF),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Pill(label: department),
              const _Pill(label: 'Front Desk Access'),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateComplaint,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.primary,
            ),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Start New Assisted Complaint'),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.colors, required this.child});

  final AdminThemeColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.colors,
    required this.label,
    required this.value,
    required this.icon,
  });

  final AdminThemeColors colors;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: colors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.colors,
    required this.report,
    required this.onView,
    required this.onSlip,
  });

  final AdminThemeColors colors;
  final Map<String, dynamic> report;
  final VoidCallback onView;
  final VoidCallback onSlip;

  @override
  Widget build(BuildContext context) {
    final referenceNumber =
        (report['printable_reference_number'] ?? 'Pending reference')
            .toString();
    final complainantName =
        (report['complainant_name'] ??
                report['reporter_name'] ??
                report['user']?['name'] ??
                'Walk-in complainant')
            .toString();
    final office = (report['office']?['name'] ?? 'Assigned Department')
        .toString();
    final status = (report['status'] ?? 'New').toString();
    final category =
        (report['category']?['name'] ?? report['category_name'] ?? 'General')
            .toString();
    final expectedReturn = _formatDateTime(report['expected_return_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  referenceNumber,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (report['title'] ?? 'Walk-in complaint').toString(),
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$complainantName • $category',
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: 6),
          Text(
            '$office • Return: $expectedReturn',
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('View Details'),
              ),
              FilledButton.icon(
                onPressed: onSlip,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Claim Slip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.border),
      ),
      child: Text(label),
    );
  }

  // ignore: unused_element
  String _formatDateTime(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (parsed == null) {
      return 'To be confirmed';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · $hour:$minute $suffix';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ClaimSlipDialog extends StatelessWidget {
  const _ClaimSlipDialog({
    required this.report,
    required this.frontDeskUser,
    required this.onDownload,
  });

  final Map<String, dynamic> report;
  final Map<String, dynamic> frontDeskUser;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final complainantName =
        (report['complainant_name'] ?? 'Walk-in complainant').toString();
    final referenceNumber =
        (report['printable_reference_number'] ?? 'Pending reference')
            .toString();
    final department =
        (report['office']?['name'] ?? 'Assigned Department').toString();
    final title = (report['title'] ?? 'Walk-in complaint').toString();
    final category =
        (report['category']?['name'] ?? report['category_name'] ?? 'General')
            .toString();
    final address =
        (report['complainant_address'] ??
                report['barangay'] ??
                report['location'] ??
                'Address not provided')
            .toString();
    final status = (report['status'] ?? 'New').toString();
    final frontDeskName =
        (frontDeskUser['name'] ?? 'Front Desk Staff').toString();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printable Claim Slip',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use this when giving the citizen their return schedule.',
                  style: TextStyle(color: colors.mutedText),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.panelAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        referenceNumber,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SlipLine(
                        label: 'Complainant',
                        value: complainantName,
                      ),
                      _SlipLine(
                        label: 'Category / Title',
                        value: '$category • $title',
                      ),
                      _SlipLine(
                        label: 'Assigned Department',
                        value: department,
                      ),
                      _SlipLine(label: 'Address / Barangay', value: address),
                      _SlipLine(
                        label: 'Submitted',
                        value: _formatDateTime(report['created_at']),
                      ),
                      _SlipLine(
                        label: 'Expected Return',
                        value: _formatDateTime(report['expected_return_at']),
                      ),
                      _SlipLine(label: 'Current Status', value: status),
                      _SlipLine(
                        label: 'Front Desk Staff',
                        value: frontDeskName,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Reminder',
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please keep this slip and return on the scheduled date for an update. The assigned department may contact you earlier if they need clarification or supporting evidence.',
                        style: TextStyle(
                          color: colors.mutedText,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        await onDownload();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Print / Download'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString())?.toLocal();
    if (parsed == null) {
      return 'To be confirmed';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · $hour:$minute $suffix';
  }
}

class _SlipLine extends StatelessWidget {
  const _SlipLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
