import 'package:flutter/material.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/report_feedback_service.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/citizen_bottom_nav.dart';
import 'citizen_home_screen.dart';
import 'citizen_notifications_screen.dart';
import 'citizen_profile_screen.dart';
import 'submit_complaint_screen.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  late Future<List<dynamic>> _reportsFuture;
  final Map<int, Future<Map<String, dynamic>>> _detailFutures = {};
  int? _selectedReportId;

  @override
  void initState() {
    super.initState();
    _reportsFuture = CitizenDataCache.getReports();
  }

  Future<void> _refresh() async {
    _detailFutures.clear();
    final future = CitizenDataCache.getReports(refresh: true);
    setState(() {
      _reportsFuture = future;
    });
    await future;
  }

  void _syncSelectedReport(List<dynamic> reports) {
    if (reports.isEmpty) {
      _selectedReportId = null;
      return;
    }

    final hasSelected = reports.any((item) {
      final report = item as Map<String, dynamic>;
      return _extractReportId(report) == _selectedReportId;
    });

    if (!hasSelected) {
      _selectedReportId = _extractReportId(
        reports.first as Map<String, dynamic>,
      );
    }
  }

  int? _extractReportId(Map<String, dynamic> report) {
    final rawId = report['id'];
    return rawId is int ? rawId : int.tryParse('$rawId');
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
        title: const Text('My Reports'),
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        elevation: 0,
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
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 96,
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
            _syncSelectedReport(reports);
            if (reports.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _EmptySummaryCard(),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Status Timeline',
                    subtitle: 'Report ID: Awaiting report',
                    child: _EmptyTimeline(),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Admin Remarks',
                    child: _EmptyMessage(
                      message:
                          'Submit your first complaint to receive official updates and remarks here.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Assigned Staff',
                    child: _EmptyAssignedStaff(),
                  ),
                ],
              );
            }

            final selectedReport = reports
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (report) => _extractReportId(report) == _selectedReportId,
                  orElse: () => reports.first as Map<String, dynamic>,
                );
            final reportId = _extractReportId(selectedReport);

            if (reportId == null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Unable to load the selected report.',
                    style: TextStyle(color: citizenTitleColor(context)),
                  ),
                ],
              );
            }

            return FutureBuilder<Map<String, dynamic>>(
              future: _detailFutures.putIfAbsent(
                reportId,
                () => CitizenDataCache.getReportDetail(reportId),
              ),
              builder: (context, detailSnapshot) {
                if (detailSnapshot.connectionState != ConnectionState.done) {
                  return _buildDetailLoadingState(
                    reports.cast<Map<String, dynamic>>(),
                    reportId,
                  );
                }

                if (detailSnapshot.hasError) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        detailSnapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        style: TextStyle(color: citizenTitleColor(context)),
                      ),
                    ],
                  );
                }

                final report = detailSnapshot.data ?? selectedReport;
                final title = (report['title'] ?? 'Untitled report').toString();
                final location = (report['location'] ?? 'No location')
                    .toString();
                final rawStatus = (report['status'] ?? 'New').toString();
                final status = _normalizedStatus(rawStatus);
                final createdAt = DateTime.tryParse(
                  (report['created_at'] ?? '').toString(),
                );
                final trackingId = ReportFeedbackService.buildTrackingId(
                  reportId,
                );
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
                final assignedStaff = _resolveAssignedStaff(
                  adminResponses,
                  statusHistories,
                );
                final assignedRole = _resolveAssignedRole(
                  adminResponses,
                  statusHistories,
                );
                final adminRemark = _resolveAdminRemark(
                  report,
                  adminResponses,
                  statusHistories,
                  status,
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(
                      'Submitted Reports',
                      style: TextStyle(
                        color: citizenTitleColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...reports.cast<Map<String, dynamic>>().map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReportSelectorCard(
                          report: item,
                          selected: _extractReportId(item) == reportId,
                          onTap: () {
                            final nextId = _extractReportId(item);
                            if (nextId == null) return;
                            setState(() => _selectedReportId = nextId);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SummaryCard(
                      title: title,
                      subtitle:
                          '${_compactLocation(location)} - Submitted ${_formatDate(createdAt)}',
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
                          color: citizenBodyColor(context),
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
                                  style: TextStyle(
                                    color: citizenTitleColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  assignedRole,
                                  style: TextStyle(
                                    color: citizenBodyColor(context),
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

  List<Widget> _buildTimelineItems(String status, DateTime? createdAt) {
    final steps = <_TimelineEntry>[
      _TimelineEntry(
        title: 'Submitted',
        caption: _formatDateTime(createdAt),
        active: true,
        completed: true,
      ),
      _TimelineEntry(
        title: 'In Progress',
        caption: status == 'In Progress' || status == 'Resolved'
            ? _nextPhaseCaption(createdAt, 1)
            : 'Awaiting...',
        active: status == 'In Progress',
        completed: status == 'In Progress' || status == 'Resolved',
      ),
      _TimelineEntry(
        title: 'Resolved',
        caption: status == 'Resolved'
            ? _nextPhaseCaption(createdAt, 2)
            : 'Awaiting...',
        active: status == 'Resolved',
        completed: status == 'Resolved',
        isLast: true,
      ),
    ];

    return steps.map((entry) => _TimelineItem(entry: entry)).toList();
  }

  String _resolveAdminRemark(
    Map<String, dynamic> report,
    List<dynamic> adminResponses,
    List<dynamic> statusHistories,
    String status,
  ) {
    final latestUpdate = _latestUpdateMessage(
      report,
      adminResponses: adminResponses,
      statusHistories: statusHistories,
    );
    if (latestUpdate != null) {
      return latestUpdate;
    }

    switch (status) {
      case 'In Progress':
        return 'The assigned department is currently working on your report.';
      case 'Resolved':
        return 'The report was marked resolved by the assigned department.';
      case 'Rejected':
        return 'The assigned office closed this report without resolving it.';
      default:
        return 'Your report has been received and is waiting for action from the assigned office.';
    }
  }

  String _resolveAssignedStaff(
    List<dynamic> adminResponses,
    List<dynamic> statusHistories,
  ) {
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

  String _resolveAssignedRole(
    List<dynamic> adminResponses,
    List<dynamic> statusHistories,
  ) {
    if (adminResponses.isNotEmpty) {
      final response = adminResponses.first as Map<String, dynamic>;
      final user = response['user'] as Map<String, dynamic>?;
      final role = (user?['job_title'] ?? user?['role'] ?? '')
          .toString()
          .trim();
      if (role.isNotEmpty) {
        return role;
      }
    }

    if (statusHistories.isNotEmpty) {
      final history = statusHistories.first as Map<String, dynamic>;
      final user = history['user'] as Map<String, dynamic>?;
      final role = (user?['job_title'] ?? user?['role'] ?? '')
          .toString()
          .trim();
      if (role.isNotEmpty) {
        return role;
      }
    }

    return 'Department staff';
  }

  IconData _reportIcon(Map<String, dynamic> report) {
    final category =
        ((report['category'] as Map<String, dynamic>?)?['name'] ?? '')
            .toString()
            .toLowerCase();
    if (category.contains('water')) return Icons.water_drop_rounded;
    if (category.contains('road')) return Icons.handyman_rounded;
    if (category.contains('electric')) return Icons.bolt_rounded;
    return Icons.report_problem_rounded;
  }

  static String _normalizedStatus(String raw) {
    switch (raw) {
      case 'New':
      case 'Pending':
        return 'Submitted';
      default:
        return raw;
    }
  }

  static String? _latestUpdateMessage(
    Map<String, dynamic> report, {
    List<dynamic>? adminResponses,
    List<dynamic>? statusHistories,
  }) {
    final latestAdminResponse = _stringValue(
      _mapValue(report['latest_admin_response'])?['response'] ??
          _mapValue(report['latestAdminResponse'])?['response'],
    );
    if (latestAdminResponse != null) {
      return latestAdminResponse;
    }

    final responseList =
        adminResponses ??
        (report['admin_responses'] as List<dynamic>? ??
            report['adminResponses'] as List<dynamic>? ??
            const []);
    for (final item in responseList) {
      final response = _stringValue(_mapValue(item)?['response']);
      if (response != null) {
        return response;
      }
    }

    final latestStatusRemark = _stringValue(
      _mapValue(report['latest_status_history'])?['remarks'] ??
          _mapValue(report['latestStatusHistory'])?['remarks'],
    );
    if (latestStatusRemark != null) {
      return latestStatusRemark;
    }

    final historyList =
        statusHistories ??
        (report['status_histories'] as List<dynamic>? ??
            report['statusHistories'] as List<dynamic>? ??
            const []);
    for (final item in historyList) {
      final remarks = _stringValue(_mapValue(item)?['remarks']);
      if (remarks != null) {
        return remarks;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
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
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} - $hour:$minute $period';
  }

  String _nextPhaseCaption(DateTime? createdAt, int dayOffset) {
    if (createdAt == null) return 'Completed';
    return _formatDateTime(createdAt.add(Duration(days: dayOffset)));
  }

  Widget _buildDetailLoadingState(
    List<Map<String, dynamic>> reports,
    int reportId,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Submitted Reports',
          style: TextStyle(
            color: citizenTitleColor(context),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        ...reports.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReportSelectorCard(
              report: item,
              selected: _extractReportId(item) == reportId,
              onTap: () {
                final nextId = _extractReportId(item);
                if (nextId == null) return;
                setState(() => _selectedReportId = nextId);
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 16),
            child: Container(
              height: index == 0 ? 108 : 126,
              decoration: BoxDecoration(
                color: citizenCardColor(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: citizenBorderColor(context)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportSelectorCard extends StatelessWidget {
  const _ReportSelectorCard({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (report['title'] ?? 'Untitled report').toString();
    final location = (report['location'] ?? 'No location').toString();
    final rawStatus = (report['status'] ?? 'New').toString();
    final status = _MyComplaintsScreenState._normalizedStatus(rawStatus);
    final createdAt = DateTime.tryParse(
      (report['created_at'] ?? '').toString(),
    );
    final latestUpdate = _MyComplaintsScreenState._latestUpdateMessage(report);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? (citizenIsDark(context)
                    ? const Color(0xFF1A2233)
                    : const Color(0xFFEFF6FF))
              : citizenCardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF274D96)
                : citizenBorderColor(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: citizenIsDark(context)
                    ? const Color(0xFF24355A)
                    : const Color(0xFFE0EAFF),
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
                  const SizedBox(height: 4),
                  Text(
                    '${_compactText(location)} - ${_reportDate(createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: citizenBodyColor(context),
                      fontSize: 12,
                    ),
                  ),
                  if (latestUpdate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Latest update: ${_compactText(latestUpdate, limit: 64)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: citizenBodyColor(context),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(status: status),
          ],
        ),
      ),
    );
  }

  static String _compactText(String value, {int limit = 30}) {
    if (value.length <= limit) return value;
    return '${value.substring(0, limit)}...';
  }

  static String _reportDate(DateTime? date) {
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
    final isDark = citizenIsDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2233) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF274D96) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24355A) : const Color(0xFFE0EAFF),
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
                  style: TextStyle(
                    color: citizenTitleColor(context),
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
                    color: citizenBodyColor(context),
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
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(color: citizenBodyColor(context), fontSize: 12),
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
    final isDark = citizenIsDark(context);
    final dotColor = entry.completed
        ? const Color(0xFF22C55E)
        : entry.active
        ? const Color(0xFF4B82F7)
        : isDark
        ? const Color(0xFF2A3348)
        : const Color(0xFFE2E8F0);
    final textColor = entry.completed || entry.active
        ? (entry.active ? const Color(0xFF6FA8FF) : const Color(0xFF4ADE80))
        : citizenMutedColor(context);

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
                  color: entry.completed
                      ? const Color(0xFF22C55E)
                      : isDark
                      ? const Color(0xFF2A3348)
                      : const Color(0xFFE2E8F0),
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
                      color: citizenMutedColor(context),
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
      case 'Submitted':
        color = const Color(0xFFF59E0B);
        break;
      case 'Rejected':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
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
    final isDark = citizenIsDark(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2233) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF274D96) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF24355A) : const Color(0xFFE0EAFF),
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
                Text(
                  'No report selected yet',
                  style: TextStyle(
                    color: citizenTitleColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submit a complaint to start seeing your tracker updates here.',
                  style: TextStyle(
                    color: citizenBodyColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _StatusPill(status: 'Submitted'),
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
      style: TextStyle(color: citizenBodyColor(context), height: 1.45),
    );
  }
}

class _EmptyAssignedStaff extends StatelessWidget {
  const _EmptyAssignedStaff();

  @override
  Widget build(BuildContext context) {
    final isDark = citizenIsDark(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Awaiting assignment',
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Staff will appear here after validation',
                style: TextStyle(
                  color: citizenBodyColor(context),
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
            color: isDark ? const Color(0xFF2A2234) : const Color(0xFFFFF7ED),
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
