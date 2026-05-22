import 'package:flutter/material.dart';

import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/report_feedback_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/citizen_bottom_nav.dart';
import 'citizen_home_screen.dart';
import 'citizen_profile_screen.dart';
import 'my_complaints_screen.dart';
import 'submit_complaint_screen.dart';

class CitizenNotificationsScreen extends StatefulWidget {
  const CitizenNotificationsScreen({super.key});

  @override
  State<CitizenNotificationsScreen> createState() =>
      _CitizenNotificationsScreenState();
}

class _CitizenNotificationsScreenState
    extends State<CitizenNotificationsScreen> {
  late Future<List<dynamic>> _reportsFuture;

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

  Future<void> _openReports() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MyComplaintsScreen()),
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

    if (!mounted) return;
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

    if (!mounted) return;
    if (created != null) {
      if (created is Map<String, dynamic>) {
        CitizenDataCache.prependReport(created);
      } else {
        CitizenDataCache.invalidateReports();
      }
      await _refresh();
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
    final bottomPadding = MediaQuery.of(context).padding.bottom + 116;

    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        elevation: 0,
        title: const Text('Updates'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _reportsFuture,
          initialData: CitizenDataCache.cachedReports,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
                children: List.generate(
                  4,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 124,
                      decoration: BoxDecoration(
                        color: citizenCardColor(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: citizenBorderColor(context)),
                      ),
                    ),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              if (error is AuthSessionExpiredException) {
                _redirectToLogin();
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
                  children: List.generate(
                    4,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 124,
                        decoration: BoxDecoration(
                          color: citizenCardColor(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: citizenBorderColor(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
                children: [
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(color: citizenTitleColor(context)),
                  ),
                ],
              );
            }

            final reports = snapshot.data ?? const [];
            if (reports.isEmpty) {
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
                children: const [_NotificationsEmptyState()],
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = Map<String, dynamic>.from(
                  reports[index] as Map<String, dynamic>,
                );
                final reportId = CitizenReportModel.reportIdOf(report);
                final trackingId = reportId == null
                    ? 'Tracking pending'
                    : ReportFeedbackService.buildTrackingId(reportId);
                final title = CitizenReportModel.titleOf(report);
                final status = CitizenReportModel.displayStatusOf(report);
                final location = CitizenReportModel.locationOf(report);
                final barangay = CitizenReportModel.barangayOf(report);
                final createdAt = CitizenReportModel.createdAtOf(report);
                final updatedAt = CitizenReportModel.updatedAtOf(report);
                final officeName = CitizenReportModel.officeNameOf(report);
                final updateMessage =
                    CitizenReportModel.latestAdminRemarkOrNull(report) ??
                    _statusMessage(status, updatedAt ?? createdAt);
                final assignedStaff = CitizenReportModel.assignedStaffNameOf(
                  report,
                );
                final priority = _priorityLabel(report);
                final actionNeeded = status == 'Rejected';
                final expectedReturnAt =
                    CitizenReportModel.expectedReturnAtOf(report);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: citizenCardColor(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: citizenBorderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _statusColor(
                                status,
                              ).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _statusIcon(status),
                              color: _statusColor(status),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: citizenTitleColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  trackingId,
                                  style: TextStyle(
                                    color: citizenPrimaryActionColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusBadge(status: status),
                              const SizedBox(height: 8),
                              _InfoChip(
                                label: priority,
                                color: _priorityColor(priority),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: citizenInputColor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: citizenBorderColor(context)),
                        ),
                        child: Text(
                          updateMessage,
                          style: TextStyle(
                            color: citizenTitleColor(context),
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _DetailPill(
                            icon: Icons.apartment_outlined,
                            value: officeName,
                          ),
                          if (barangay.isNotEmpty)
                            _DetailPill(
                              icon: Icons.map_outlined,
                              value: barangay,
                            ),
                          _DetailPill(
                            icon: Icons.location_on_outlined,
                            value: location,
                          ),
                          _DetailPill(
                            icon: Icons.schedule_rounded,
                            value: _formatDate(updatedAt ?? createdAt),
                          ),
                          if (assignedStaff != 'Awaiting assignment')
                            _DetailPill(
                              icon: Icons.support_agent_rounded,
                              value: assignedStaff,
                            ),
                          if (expectedReturnAt != null)
                            _DetailPill(
                              icon: Icons.event_repeat_rounded,
                              value:
                                  'Follow-up ${_formatDate(expectedReturnAt)}',
                            ),
                        ],
                      ),
                      if (actionNeeded) ...[
                        const SizedBox(height: 12),
                        _ActionBanner(
                          message:
                              'Action needed: review the latest remarks and resubmit if the office asked for more details.',
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: CitizenBottomNav(
        currentIndex: 3,
        onHomeTap: _openHome,
        onReportsTap: _openReports,
        onUpdatesTap: () {},
        onProfileTap: _openProfile,
      ),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: citizenPrimaryActionColor(context),
          onPressed: _openSubmit,
          child: Icon(
            Icons.add,
            color: citizenOnPrimaryActionColor(context),
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  String _statusMessage(String status, DateTime? createdAt) {
    final dateLabel = _formatDate(createdAt);
    switch (status) {
      case 'Submitted':
        return 'Submitted on $dateLabel and waiting for office review.';
      case 'In Progress':
        return 'Your complaint is now being handled by the assigned office.';
      case 'Resolved':
        return 'Marked resolved. You may now review the service experience.';
      case 'Rejected':
        return 'The office returned this complaint for clarification or correction.';
      default:
        return 'A new update is available for this complaint.';
    }
  }

  String _priorityLabel(Map<String, dynamic> report) {
    final value = (report['priority'] ?? 'Normal').toString().trim();
    return value.isEmpty ? 'Normal' : value;
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return CitizenAppPalette.error;
      case 'High':
        return citizenHighlightColor(context);
      case 'Low':
        return CitizenAppPalette.slate;
      default:
        return citizenPrimaryActionColor(context);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Submitted':
        return CitizenAppPalette.mauve;
      case 'In Progress':
        return CitizenAppPalette.slate;
      case 'Resolved':
        return citizenPrimaryActionColor(context);
      case 'Rejected':
        return CitizenAppPalette.error;
      default:
        return citizenHighlightColor(context);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Submitted':
        return Icons.check_circle_rounded;
      case 'Under Review':
        return Icons.fact_check_rounded;
      case 'In Progress':
        return Icons.sync_rounded;
      case 'Resolved':
        return Icons.task_alt_rounded;
      case 'Rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'an unknown date';
    const months = <String>[
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Submitted':
        color = CitizenAppPalette.mauve;
        break;
      case 'Under Review':
        color = citizenHighlightColor(context);
        break;
      case 'In Progress':
        color = CitizenAppPalette.slate;
        break;
      case 'Resolved':
        color = citizenPrimaryActionColor(context);
        break;
      case 'Rejected':
        color = CitizenAppPalette.error;
        break;
      default:
        color = citizenMutedColor(context);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38, maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: citizenMutedColor(context)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: citizenBodyColor(context),
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF8A5B14).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE1B158).withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFE1B158)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: citizenTitleColor(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  const _NotificationsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Text(
        'No complaint updates yet. Submit a report first so status changes appear here.',
        style: TextStyle(color: citizenBodyColor(context), height: 1.5),
      ),
    );
  }
}
