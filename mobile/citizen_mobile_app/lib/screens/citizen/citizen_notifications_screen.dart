import 'package:flutter/material.dart';

import '../../services/citizen_data_cache.dart';
import '../../services/report_feedback_service.dart';
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
    final user = await CitizenDataCache.getUser();
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
      setState(() {
        _reportsFuture = CitizenDataCache.getReports();
      });
      CitizenDataCache.getReports(refresh: true).then((reports) {
        if (!mounted) return;
        setState(() => _reportsFuture = Future.value(reports));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        elevation: 0,
        title: const Text('Complaint Updates'),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(color: citizenTitleColor(context)),
                  ),
                ],
              );
            }

            final reports = snapshot.data ?? const [];
            if (reports.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: const [_NotificationsEmptyState()],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = reports[index] as Map<String, dynamic>;
                final rawId = report['id'];
                final reportId = rawId is int ? rawId : int.tryParse('$rawId');
                final trackingId = reportId == null
                    ? 'Tracking pending'
                    : ReportFeedbackService.buildTrackingId(reportId);
                final title = (report['title'] ?? 'Untitled report').toString();
                final rawStatus = (report['status'] ?? 'New').toString();
                final status = _normalizedStatus(rawStatus);
                final location =
                    (report['location'] ?? report['barangay'] ?? 'No location')
                        .toString();
                final createdAt = DateTime.tryParse(
                  (report['created_at'] ?? '').toString(),
                );
                final officeName =
                    ((report['office'] as Map<String, dynamic>?)?['name'] ??
                            'Assigned office')
                        .toString();

                return Container(
                  padding: const EdgeInsets.all(14),
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
                                  style: const TextStyle(
                                    color: Color(0xFF93C5FD),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _NotificationRow(
                        icon: Icons.location_on_outlined,
                        value: location,
                      ),
                      const SizedBox(height: 6),
                      _NotificationRow(
                        icon: Icons.apartment_outlined,
                        value: officeName,
                      ),
                      const SizedBox(height: 6),
                      _NotificationRow(
                        icon: Icons.update_rounded,
                        value: _statusMessage(status, createdAt),
                      ),
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
        onAlertsTap: () {},
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

  String _normalizedStatus(String raw) {
    switch (raw) {
      case 'New':
        return 'Submitted';
      case 'Pending':
        return 'Under Review';
      default:
        return raw;
    }
  }

  String _statusMessage(String status, DateTime? createdAt) {
    final dateLabel = _formatDate(createdAt);
    switch (status) {
      case 'Submitted':
        return 'Submitted on $dateLabel and waiting for office review.';
      case 'Under Review':
        return 'Validated by the office. Review update posted on $dateLabel.';
      case 'In Progress':
        return 'Your complaint is now being handled by the assigned office.';
      case 'Resolved':
        return 'Marked resolved. You may now review the service experience.';
      default:
        return 'A new update is available for this complaint.';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Submitted':
        return const Color(0xFF22C55E);
      case 'Under Review':
        return const Color(0xFFF59E0B);
      case 'In Progress':
        return const Color(0xFF4B82F7);
      case 'Resolved':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
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
        color = const Color(0xFF22C55E);
        break;
      case 'Under Review':
        color = const Color(0xFFF59E0B);
        break;
      case 'In Progress':
        color = const Color(0xFF4B82F7);
        break;
      case 'Resolved':
        color = const Color(0xFF64748B);
        break;
      default:
        color = const Color(0xFF64748B);
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

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: citizenMutedColor(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: citizenBodyColor(context),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
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
