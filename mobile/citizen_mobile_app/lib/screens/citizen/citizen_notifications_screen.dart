import 'package:flutter/material.dart';

import '../../services/report_feedback_service.dart';
import '../../services/report_service.dart';

class CitizenNotificationsScreen extends StatefulWidget {
  const CitizenNotificationsScreen({super.key});

  @override
  State<CitizenNotificationsScreen> createState() => _CitizenNotificationsScreenState();
}

class _CitizenNotificationsScreenState extends State<CitizenNotificationsScreen> {
  final ReportService _reportService = ReportService();
  late Future<List<dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _reportService.getReports();
  }

  Future<void> _refresh() async {
    final future = _reportService.getReports();
    setState(() {
      _reportsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101826),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101826),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Complaint Updates'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _reportsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );
            }

            final reports = snapshot.data ?? const [];
            if (reports.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _NotificationsEmptyState(),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                final location = (report['location'] ?? report['barangay'] ?? 'No location')
                    .toString();
                final createdAt = DateTime.tryParse((report['created_at'] ?? '').toString());
                final officeName =
                    ((report['office'] as Map<String, dynamic>?)?['name'] ?? 'Assigned office')
                        .toString();

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2233),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                              color: _statusColor(status).withOpacity(0.16),
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
                                  style: const TextStyle(
                                    color: Colors.white,
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
        return Colors.white70;
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
        color = Colors.white70;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
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
  const _NotificationRow({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
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
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        'No complaint updates yet. Submit a report first so status changes appear here.',
        style: TextStyle(
          color: Colors.white.withOpacity(0.72),
          height: 1.5,
        ),
      ),
    );
  }
}
