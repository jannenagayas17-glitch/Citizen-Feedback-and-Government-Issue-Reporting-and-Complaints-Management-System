import 'package:flutter/material.dart';

import '../../services/report_feedback_service.dart';
import '../../services/report_service.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
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
        title: const Text('My Reports'),
        backgroundColor: const Color(0xFF101826),
        foregroundColor: Colors.white,
        elevation: 0,
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: const [
                  _EmptySummaryCard(),
                  SizedBox(height: 16),
                  _SectionCard(
                    title: 'Status Timeline',
                    subtitle: 'Report ID: Awaiting report',
                    child: _EmptyTimeline(),
                  ),
                  SizedBox(height: 16),
                  _SectionCard(
                    title: 'Admin Remarks',
                    child: _EmptyMessage(
                      message: 'Submit your first complaint to receive official updates and remarks here.',
                    ),
                  ),
                  SizedBox(height: 16),
                  _SectionCard(
                    title: 'Assigned Staff',
                    child: _EmptyAssignedStaff(),
                  ),
                ],
              );
            }

            final latestReport = reports.first as Map<String, dynamic>;
            final rawId = latestReport['id'];
            final reportId = rawId is int ? rawId : int.tryParse('$rawId');

            if (reportId == null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  Text(
                    'Unable to load the selected report.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            }

            return FutureBuilder<Map<String, dynamic>>(
              future: _reportService.getReportDetail(reportId),
              builder: (context, detailSnapshot) {
                if (detailSnapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (detailSnapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        detailSnapshot.error.toString().replaceFirst('Exception: ', ''),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  );
                }

                final report = detailSnapshot.data ?? latestReport;
                final title = (report['title'] ?? 'Untitled report').toString();
                final location = (report['location'] ?? 'No location').toString();
                final rawStatus = (report['status'] ?? 'New').toString();
                final status = _normalizedStatus(rawStatus);
                final createdAt = DateTime.tryParse((report['created_at'] ?? '').toString());
                final trackingId = ReportFeedbackService.buildTrackingId(reportId);
                final adminResponses =
                    (report['admin_responses'] as List<dynamic>? ??
                            report['adminResponses'] as List<dynamic>? ??
                            const [])
                        .cast<dynamic>();
                final statusHistories =
                    (report['status_histories'] as List<dynamic>? ??
                            report['statusHistories'] as List<dynamic>? ??
                            const [])
                        .cast<dynamic>();
                final assignedStaff = _resolveAssignedStaff(adminResponses, statusHistories);
                final assignedRole = _resolveAssignedRole(adminResponses, statusHistories);
                final adminRemark = _resolveAdminRemark(adminResponses, status);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    _SummaryCard(
                      title: title,
                      subtitle:
                          '${_compactLocation(location)} · Submitted ${_formatDate(createdAt)}',
                      status: status,
                      icon: _reportIcon(report),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Status Timeline',
                      subtitle: 'Report ID: $trackingId',
                      child: Column(
                        children: _buildTimelineItems(status, createdAt),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Admin Remarks',
                      child: Text(
                        adminRemark,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Assigned Staff',
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignedStaff,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  assignedRole,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.62),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2234),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: Color(0xFFFFA54A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildTimelineItems(String status, DateTime? createdAt) {
    final steps = <_TimelineEntry>[
      _TimelineEntry(
        title: 'Submitted',
        caption: _formatDateTime(createdAt),
        active: true,
        completed: true,
      ),
      _TimelineEntry(
        title: 'Validated',
        caption: status == 'Submitted' ? 'Awaiting...' : _nextPhaseCaption(createdAt, 1),
        active: status == 'Under Review',
        completed: status == 'Under Review' || status == 'In Progress' || status == 'Resolved',
      ),
      _TimelineEntry(
        title: 'In Progress',
        caption: status == 'In Progress' || status == 'Resolved'
            ? _nextPhaseCaption(createdAt, 2)
            : 'Awaiting...',
        active: status == 'In Progress',
        completed: status == 'In Progress' || status == 'Resolved',
      ),
      _TimelineEntry(
        title: 'Resolved',
        caption: status == 'Resolved' ? _nextPhaseCaption(createdAt, 3) : 'Awaiting...',
        active: status == 'Resolved',
        completed: status == 'Resolved',
        isLast: true,
      ),
    ];

    return steps.map((entry) => _TimelineItem(entry: entry)).toList();
  }

  String _resolveAdminRemark(List<dynamic> adminResponses, String status) {
    if (adminResponses.isNotEmpty) {
      final response = adminResponses.first as Map<String, dynamic>;
      final message = (response['response'] ?? '').toString().trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    switch (status) {
      case 'In Progress':
        return 'The assigned department is currently working on your report.';
      case 'Resolved':
        return 'The report was marked resolved by the assigned department.';
      case 'Under Review':
        return 'Your report is currently being reviewed and validated by the office.';
      default:
        return 'Your report has been received and is waiting for action from the assigned office.';
    }
  }

  String _resolveAssignedStaff(List<dynamic> adminResponses, List<dynamic> statusHistories) {
    if (adminResponses.isNotEmpty) {
      final response = adminResponses.first as Map<String, dynamic>;
      final user = response['user'] as Map<String, dynamic>?;
      final name = (user?['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    if (statusHistories.isNotEmpty) {
      final history = statusHistories.first as Map<String, dynamic>;
      final user = history['user'] as Map<String, dynamic>?;
      final name = (user?['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Awaiting assignment';
  }

  String _resolveAssignedRole(List<dynamic> adminResponses, List<dynamic> statusHistories) {
    if (adminResponses.isNotEmpty) {
      final response = adminResponses.first as Map<String, dynamic>;
      final user = response['user'] as Map<String, dynamic>?;
      final role = (user?['job_title'] ?? user?['role'] ?? '').toString().trim();
      if (role.isNotEmpty) {
        return role;
      }
    }

    if (statusHistories.isNotEmpty) {
      final history = statusHistories.first as Map<String, dynamic>;
      final user = history['user'] as Map<String, dynamic>?;
      final role = (user?['job_title'] ?? user?['role'] ?? '').toString().trim();
      if (role.isNotEmpty) {
        return role;
      }
    }

    return 'Department staff';
  }

  IconData _reportIcon(Map<String, dynamic> report) {
    final category =
        ((report['category'] as Map<String, dynamic>?)?['name'] ?? '').toString().toLowerCase();
    if (category.contains('water')) return Icons.water_drop_rounded;
    if (category.contains('road')) return Icons.handyman_rounded;
    if (category.contains('electric')) return Icons.bolt_rounded;
    return Icons.report_problem_rounded;
  }

  static String _normalizedStatus(String raw) {
    switch (raw) {
      case 'New':
        return 'Submitted';
      case 'Pending':
        return 'Under Review';
      default:
        return raw;
    }
  }

  String _compactLocation(String location) {
    if (location.length <= 32) return location;
    return '${location.substring(0, 32)}...';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
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
    return '${months[date.month - 1]} ${date.day}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'Awaiting...';
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
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
  }

  String _nextPhaseCaption(DateTime? createdAt, int dayOffset) {
    if (createdAt == null) return 'Completed';
    return _formatDateTime(createdAt.add(Duration(days: dayOffset)));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF274D96)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF24355A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6FA8FF)),
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
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.56),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.title,
    required this.caption,
    required this.active,
    required this.completed,
    this.isLast = false,
  });

  final String title;
  final String caption;
  final bool active;
  final bool completed;
  final bool isLast;
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final dotColor = entry.completed
        ? const Color(0xFF22C55E)
        : entry.active
            ? const Color(0xFF4B82F7)
            : const Color(0xFF2A3348);
    final textColor = entry.completed || entry.active
        ? (entry.active ? const Color(0xFF6FA8FF) : const Color(0xFF4ADE80))
        : Colors.white38;

    return Padding(
      padding: EdgeInsets.only(bottom: entry.isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  entry.completed ? Icons.check : Icons.circle,
                  size: entry.completed ? 14 : 8,
                  color: Colors.white,
                ),
              ),
              if (!entry.isLast)
                Container(
                  width: 2,
                  height: 38,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: entry.completed ? const Color(0xFF22C55E) : const Color(0xFF2A3348),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.caption,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Resolved':
        color = const Color(0xFF22C55E);
        break;
      case 'In Progress':
        color = const Color(0xFF4B82F7);
        break;
      case 'Under Review':
        color = const Color(0xFFF59E0B);
        break;
      default:
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(20),
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

class _EmptySummaryCard extends StatelessWidget {
  const _EmptySummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF274D96)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF24355A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF6FA8FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No report selected yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submit a complaint to start seeing your tracker updates here.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _StatusPill(status: 'Pending'),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    const entries = [
      _TimelineEntry(
        title: 'Submitted',
        caption: 'Awaiting...',
        active: false,
        completed: false,
      ),
      _TimelineEntry(
        title: 'Validated',
        caption: 'Awaiting...',
        active: false,
        completed: false,
      ),
      _TimelineEntry(
        title: 'In Progress',
        caption: 'Awaiting...',
        active: false,
        completed: false,
      ),
      _TimelineEntry(
        title: 'Resolved',
        caption: 'Awaiting...',
        active: false,
        completed: false,
        isLast: true,
      ),
    ];

    return Column(
      children: entries.map((entry) => _TimelineItem(entry: entry)).toList(),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: Colors.white.withOpacity(0.78),
        height: 1.45,
      ),
    );
  }
}

class _EmptyAssignedStaff extends StatelessWidget {
  const _EmptyAssignedStaff();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Awaiting assignment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Staff will appear here after validation',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2234),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: Color(0xFFFFA54A),
          ),
        ),
      ],
    );
  }
}

class _TrackerEmptyState extends StatelessWidget {
  const _TrackerEmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No reports yet. Submit a complaint to start tracking updates here.',
      style: TextStyle(
        color: Colors.white.withOpacity(0.72),
        height: 1.5,
      ),
    );
  }
}
