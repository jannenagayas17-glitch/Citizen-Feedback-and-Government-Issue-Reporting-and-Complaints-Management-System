import 'package:flutter/material.dart';

import '../../models/report_model.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/report_feedback_service.dart';
import '../../services/auth_service.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../utils/app_routes.dart';
import '../../widgets/citizen_bottom_nav.dart';
import 'citizen_home_screen.dart';
import 'citizen_notifications_screen.dart';
import 'citizen_profile_screen.dart';
import 'complaint_detail_screen.dart';
import 'submit_complaint_screen.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  late Future<List<dynamic>> _reportsFuture;
  int? _openingReportId;

  @override
  void initState() {
    super.initState();
    _reportsFuture = CitizenDataCache.getReports();
  }

  Future<void> _refresh() async {
    final future = CitizenDataCache.getReports(refresh: true);
    setState(() {
      _reportsFuture = future;
    });
    await future;
  }

  Future<void> _openHome() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CitizenHomeScreen()),
    );
  }

  Future<void> _openAlerts() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CitizenNotificationsScreen()),
    );
  }

  Future<void> _openProfile() async {
    late final Map<String, dynamic> user;
    try {
      user = await CitizenDataCache.getUser();
    } on AuthSessionExpiredException {
      _redirectToLogin();
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CitizenProfileScreen(user: user)),
    );
  }

  Future<void> _openSubmit() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
    );

    if (!mounted) {
      return;
    }

    if (created is Map<String, dynamic>) {
      CitizenDataCache.prependReport(created);
    } else if (created != null) {
      CitizenDataCache.invalidateReports();
    }

    if (created != null) {
      await _refresh();
    }
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    final reportId = CitizenReportModel.reportIdOf(report);
    if (reportId == null || _openingReportId == reportId) {
      return;
    }

    setState(() => _openingReportId = reportId);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(reportId: reportId),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingReportId = null);
        await _refresh();
      }
    }
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: citizenIsDark(context)
                ? const [
                    Color(0xFF0B1322),
                    Color(0xFF10192E),
                    Color(0xFF0E1525),
                  ]
                : const [
                    Color(0xFFF8FBFF),
                    Color(0xFFEFF5FF),
                    Color(0xFFF6F8FC),
                  ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<dynamic>>(
            future: _reportsFuture,
            initialData: CitizenDataCache.cachedReports,
            builder: (context, snapshot) {
              final contentPadding = EdgeInsets.fromLTRB(
                14,
                14,
                14,
                bottomInset + 116,
              );

              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return _ReportsLoadingState(padding: contentPadding);
              }

              if (snapshot.hasError) {
                final error = snapshot.error;
                if (error is AuthSessionExpiredException) {
                  _redirectToLogin();
                  return _ReportsLoadingState(padding: contentPadding);
                }

                return _ReportsErrorState(
                  padding: contentPadding,
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: _refresh,
                );
              }

              final reports = CitizenReportModel.normalizeReportList(
                snapshot.data ?? const <dynamic>[],
              );
              if (reports.isEmpty) {
                return _ReportsEmptyState(
                  padding: contentPadding,
                  onSubmit: _openSubmit,
                );
              }

              return ListView(
                padding: contentPadding,
                children: [
                  Row(
                    children: [
                      Text(
                        'Submitted Complaints',
                        style: TextStyle(
                          color: citizenTitleColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${reports.length} total',
                        style: TextStyle(
                          color: citizenBodyColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a complaint to view its status and details.',
                    style: TextStyle(
                      color: citizenBodyColor(context),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...reports.map(
                    (report) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CitizenReportCard(
                        report: report,
                        opening:
                            _openingReportId ==
                            CitizenReportModel.reportIdOf(report),
                        onTap: () => _openReportDetail(report),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: CitizenBottomNav(
        currentIndex: 1,
        onHomeTap: _openHome,
        onReportsTap: () {},
        onAlertsTap: _openAlerts,
        onProfileTap: _openProfile,
      ),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFF3B82F6),
          onPressed: _openSubmit,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _CitizenReportCard extends StatelessWidget {
  const _CitizenReportCard({
    required this.report,
    required this.opening,
    required this.onTap,
  });

  final Map<String, dynamic> report;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reportId = CitizenReportModel.reportIdOf(report);
    final trackingId = reportId == null
        ? 'Tracking ID pending'
        : ReportFeedbackService.buildTrackingId(reportId);
    final status = CitizenReportModel.displayStatusOf(report);
    final latestUpdate = CitizenReportModel.latestAdminRemarkOrNull(report);
    final statusColor = _statusColor(status);

    return InkWell(
      onTap: opening ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: citizenCardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: citizenBorderColor(context)),
          boxShadow: citizenIsDark(context)
              ? const []
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.tag_rounded,
                        label: trackingId,
                        accent: const Color(0xFF3B82F6),
                      ),
                      _MetaPill(
                        icon: Icons.business_outlined,
                        label: CitizenReportModel.officeNameOf(report),
                        accent: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CitizenReportModel.titleOf(report),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: citizenTitleColor(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _InlineMeta(
                  icon: Icons.category_outlined,
                  text: CitizenReportModel.categoryNameOf(report),
                ),
                _InlineMeta(
                  icon: Icons.place_outlined,
                  text: _locationLabel(report),
                ),
                _InlineMeta(
                  icon: Icons.schedule_outlined,
                  text: _submittedLabel(report),
                ),
              ],
            ),
            if (latestUpdate != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  latestUpdate,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: citizenBodyColor(context),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Open full complaint details',
                  style: TextStyle(
                    color: const Color(0xFF3B82F6),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                if (opening)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: statusColor,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: citizenMutedColor(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF22C55E);
      case 'In Progress':
        return const Color(0xFF3B82F6);
      case 'Rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  static String _locationLabel(Map<String, dynamic> report) {
    final barangay = CitizenReportModel.barangayOf(report);
    if (barangay.isNotEmpty) {
      return barangay;
    }

    return CitizenReportModel.locationOf(report);
  }

  static String _submittedLabel(Map<String, dynamic> report) {
    final createdAt = CitizenReportModel.createdAtOf(report);
    if (createdAt == null) {
      return 'Date unavailable';
    }

    return 'Submitted ${CitizenReportModel.formatDateTime(createdAt)}';
  }
}

class _ReportsLoadingState extends StatelessWidget {
  const _ReportsLoadingState({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        ...List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
            child: _placeholder(context, height: 170),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: citizenBorderColor(context)),
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({
    required this.padding,
    required this.message,
    required this.onRetry,
  });

  final EdgeInsets padding;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: citizenCardColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: citizenBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFF59E0B),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load your reports',
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: citizenBodyColor(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState({required this.padding, required this.onSubmit});

  final EdgeInsets padding;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: citizenCardColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: citizenBorderColor(context)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.inbox_outlined,
                  color: Color(0xFF3B82F6),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No complaints submitted yet',
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Submit your first concern to start tracking live complaint updates, department actions, and status changes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: citizenBodyColor(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Submit a complaint'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: citizenMutedColor(context)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: citizenBodyColor(context), fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color accent;
    switch (status) {
      case 'Resolved':
        accent = const Color(0xFF22C55E);
        break;
      case 'In Progress':
        accent = const Color(0xFF3B82F6);
        break;
      case 'Rejected':
        accent = const Color(0xFFEF4444);
        break;
      default:
        accent = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
