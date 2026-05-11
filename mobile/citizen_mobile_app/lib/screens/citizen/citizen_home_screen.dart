import 'package:flutter/material.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../utils/app_routes.dart';
import '../../widgets/citizen_avatar.dart';
import '../../widgets/citizen_bottom_nav.dart';
import '../../widgets/theme_mode_toggle.dart';
import 'citizen_notifications_screen.dart';
import 'complaint_detail_screen.dart';
import 'citizen_profile_screen.dart';
import 'my_complaints_screen.dart';
import 'submit_complaint_screen.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  late Future<Map<String, dynamic>> _payloadFuture;
  Map<String, dynamic> _cachedUser = const {};
  int _selectedFilter = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _payloadFuture = CitizenDataCache.getHomePayload();
  }

  Future<void> _refresh() async {
    final future = CitizenDataCache.getHomePayload(refresh: true);

    setState(() {
      _payloadFuture = future;
    });

    await future;
  }

  Future<void> _openSubmitReport() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
    );

    if (!mounted) return;
    setState(() => _currentIndex = 0);

    if (created != null) {
      if (created is Map<String, dynamic>) {
        CitizenDataCache.prependReport(created);
      } else {
        CitizenDataCache.invalidateReports();
      }
      await _refresh();
    }
  }

  Future<void> _openMyReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyComplaintsScreen()),
    );

    if (!mounted) return;
    setState(() => _currentIndex = 0);
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CitizenNotificationsScreen()),
    );

    if (!mounted) return;
    setState(() => _currentIndex = 0);
  }

  Future<void> _openProfile(Map<String, dynamic> user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CitizenProfileScreen(user: user)),
    );

    if (!mounted) return;
    setState(() => _currentIndex = 0);
    final cachedUser = CitizenDataCache.cachedUser;
    if (cachedUser != null) {
      _cachedUser = cachedUser;
    }
  }

  Future<void> _openReportDetail(Map<String, dynamic> report) async {
    final reportId = CitizenReportModel.reportIdOf(report);
    if (reportId == null) {
      await _openMyReports();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintDetailScreen(reportId: reportId),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _currentIndex = 0);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1322)
          : const Color(0xFFF6F8FC),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
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
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _payloadFuture,
              initialData: CitizenDataCache.cachedHomePayload,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  if (error is AuthSessionExpiredException) {
                    _redirectToLogin();
                    return _buildLoadingState();
                  }

                  return _buildErrorState(error);
                }

                final payload = snapshot.data ?? const <String, dynamic>{};
                final dashboard =
                    payload['dashboard'] as Map<String, dynamic>? ?? const {};
                final reports =
                    payload['reports'] as List<dynamic>? ?? const [];
                final user =
                    payload['user'] as Map<String, dynamic>? ?? const {};
                _cachedUser = user;
                final visibleReports = _applyCategoryFilter(reports);
                final notificationCount = reports
                    .where(
                      (item) =>
                          _normalizedStatus(item as Map<String, dynamic>) !=
                          'Resolved',
                    )
                    .length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 104),
                  children: [
                    _buildHeader(user, notificationCount),
                    const SizedBox(height: 14),
                    _buildStatsRow(dashboard),
                    const SizedBox(height: 14),
                    _buildReportCard(),
                    const SizedBox(height: 12),
                    _buildNoticeCard(),
                    const SizedBox(height: 14),
                    _buildFilterChips(reports),
                    const SizedBox(height: 12),
                    _buildRecentHeader(visibleReports.length),
                    const SizedBox(height: 12),
                    if (visibleReports.isEmpty)
                      _buildEmptyState()
                    else
                      ...visibleReports
                          .take(6)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _IssueCard(
                                report: item as Map<String, dynamic>,
                                onTap: () => _openReportDetail(item),
                              ),
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: CitizenBottomNav(
        currentIndex: _currentIndex,
        onHomeTap: () => setState(() => _currentIndex = 0),
        onReportsTap: () {
          setState(() => _currentIndex = 1);
          _openMyReports();
        },
        onAlertsTap: () {
          setState(() => _currentIndex = 3);
          _openNotifications();
        },
        onProfileTap: () async {
          setState(() => _currentIndex = 4);
          await _openProfile(_cachedUser);
        },
      ),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: const Color(0xFF3B82F6),
          onPressed: _openSubmitReport,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    });
  }

  Widget _buildErrorState(Object? error) {
    final message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('AuthSessionExpiredException: ', '');
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 104),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171F32) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFD8E3F7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFFBBF24),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load your account',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF12213A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFB7C0D5)
                      : const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> user, int notificationCount) {
    final profileName = (user['name'] ?? 'Citizen').toString().trim();
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader = constraints.maxWidth < 370;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CitizenAvatar(
              name: profileName,
              size: compactHeader ? 38 : 40,
              backgroundColor: isDark
                  ? const Color(0xFF2D447B)
                  : const Color(0xFFE0EAFF),
              textColor: isDark
                  ? const Color(0xFFC6D6FF)
                  : const Color(0xFF1D4ED8),
              borderColor: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : const Color(0xFFBFDBFE),
              borderWidth: 1.5,
              fontSize: compactHeader ? 17 : 18,
            ),
            SizedBox(width: compactHeader ? 8 : 10),
            Expanded(
              child: Text(
                profileName.isEmpty ? 'Citizen' : profileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF12213A),
                  fontSize: compactHeader ? 14.5 : 15.5,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
            ),
            const ThemeModeToggle(compact: true),
            SizedBox(width: compactHeader ? 6 : 8),
            _HeaderPill(
              icon: Icons.location_on,
              label: compactHeader ? null : 'Tacloban',
              onTap: () {},
            ),
            SizedBox(width: compactHeader ? 6 : 8),
            _BellButton(count: notificationCount, onTap: _openNotifications),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> dashboard) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.bar_chart_rounded,
            iconColor: const Color(0xFF6EE7B7),
            value: '${dashboard['total_reports'] ?? 0}',
            label: 'Total',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.fiber_new_rounded,
            iconColor: const Color(0xFFFBBF24),
            value: '${dashboard['new'] ?? 0}',
            label: 'New',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.access_time_filled_rounded,
            iconColor: const Color(0xFFE5E7EB),
            value: '${dashboard['in_progress'] ?? 0}',
            label: 'Active',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.check_box_rounded,
            iconColor: const Color(0xFF4ADE80),
            value: '${dashboard['resolved'] ?? 0}',
            label: 'Done',
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 116),
      children: [
        Row(
          children: [
            _loadingBox(48, 48, radius: 24),
            const SizedBox(width: 12),
            Expanded(child: _loadingBox(double.infinity, 20)),
            const SizedBox(width: 12),
            _loadingBox(40, 40, radius: 20),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: List.generate(
            7,
            (index) => index.isOdd
                ? const SizedBox(width: 8)
                : Expanded(child: _loadingBox(double.infinity, 96, radius: 16)),
          ),
        ),
        const SizedBox(height: 16),
        _loadingBox(double.infinity, 78, radius: 18),
        const SizedBox(height: 14),
        _loadingBox(double.infinity, 84, radius: 18),
        const SizedBox(height: 18),
        _loadingBox(150, 18, radius: 9),
        const SizedBox(height: 14),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _loadingBox(double.infinity, 96, radius: 18),
          ),
        ),
      ],
    );
  }

  Widget _loadingBox(double width, double height, {double radius = 14}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
    );
  }

  Widget _buildReportCard() {
    return InkWell(
      onTap: _openSubmitReport,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F83FF), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Color(0x30FFFFFF),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an Issue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Submit directly to the live system',
                    style: TextStyle(color: Color(0xFFDCEAFF), fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard() {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2112) : const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF8F6A1F) : const Color(0xFFFACC15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.circle, color: Color(0xFFFBBF24), size: 10),
              SizedBox(width: 8),
              Text(
                'Live reporting is enabled',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'New reports submitted are stored in the backend database immediately.',
            style: TextStyle(
              color: isDark ? const Color(0xFFD7C7A5) : const Color(0xFF6B4E16),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<dynamic> reports) {
    final filters = _buildFilters(reports);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == index;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF3B82F6)
                    : isDark
                    ? const Color(0xFF121B2F)
                    : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF3B82F6)
                      : isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFD8E3F7),
                ),
              ),
              child: Text(
                filter == 'All Issues'
                    ? filter
                    : '$filter (${_filterCountFor(reports, filter)})',
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : isDark
                      ? const Color(0xFFB7C0D5)
                      : const Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentHeader(int count) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          'Recent Issues',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF12213A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '$count reports',
          style: TextStyle(
            color: isDark ? const Color(0xFF77839D) : const Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E31) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD8E3F7),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            'No reports found',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF12213A),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Submit your first complaint to start tracking updates here.',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.62)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildFilters(List<dynamic> reports) {
    final names =
        reports
            .map(
              (item) =>
                  ((item as Map<String, dynamic>)['category']
                          as Map<String, dynamic>?)?['name']
                      ?.toString(),
            )
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();

    return ['All Issues', ...names];
  }

  List<dynamic> _applyCategoryFilter(List<dynamic> reports) {
    final filters = _buildFilters(reports);
    final selected = filters[_selectedFilter.clamp(0, filters.length - 1)];
    if (selected == 'All Issues') {
      return reports;
    }

    return reports.where((item) {
      final category =
          ((item as Map<String, dynamic>)['category']
                  as Map<String, dynamic>?)?['name']
              ?.toString() ??
          '';
      return category == selected;
    }).toList();
  }

  int _filterCountFor(List<dynamic> reports, String filter) {
    if (filter == 'All Issues') {
      return reports.length;
    }

    return reports.where((item) {
      final category =
          ((item as Map<String, dynamic>)['category']
                  as Map<String, dynamic>?)?['name']
              ?.toString() ??
          '';
      return category == filter;
    }).length;
  }

  String _normalizedStatus(Map<String, dynamic> report) {
    final raw = (report['status'] ?? 'Submitted').toString();
    switch (raw) {
      case 'New':
      case 'Pending':
        return 'Submitted';
      default:
        return raw;
    }
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Tooltip(
        message: label ?? 'Tacloban',
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF182238) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFD8E3F7),
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
            size: 16,
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182238) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFD8E3F7),
              ),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Color(0xFFFBBF24),
              size: 17,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF0B1322) : Colors.white,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final resolvedIconColor = !isDark && iconColor == const Color(0xFFE5E7EB)
        ? const Color(0xFF64748B)
        : iconColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171F32) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD8E3F7),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: resolvedIconColor, size: 15),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF12213A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFF9EA9C2) : const Color(0xFF64748B),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.report, required this.onTap});

  final Map<String, dynamic> report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (report['title'] ?? 'Untitled report').toString();
    final categoryName =
        ((report['category'] as Map<String, dynamic>?)?['name'] ?? 'General')
            .toString();
    final location = (report['location'] ?? 'No location').toString();
    final officeName =
        ((report['office'] as Map<String, dynamic>?)?['name'] ??
                'Assigned office')
            .toString();
    final status = _displayStatus((report['status'] ?? 'Pending').toString());
    final statusColor = _statusColor(status);
    final iconColor = _iconColor(categoryName);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171F32) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFD8E3F7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_issueIcon(categoryName), color: iconColor),
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
                      color: isDark ? Colors.white : const Color(0xFF12213A),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        '-',
                        style: TextStyle(
                          color: Color(0xFFFB7185),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$location - $officeName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFA2AEC7)
                                : const Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayStatus(String raw) {
    switch (raw) {
      case 'New':
      case 'Pending':
        return 'Submitted';
      default:
        return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF4ADE80);
      case 'In Progress':
        return const Color(0xFF60A5FA);
      case 'Submitted':
        return const Color(0xFFFB7185);
      case 'Rejected':
        return const Color(0xFFF87171);
      default:
        return Colors.white70;
    }
  }

  IconData _issueIcon(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('road')) return Icons.handyman_outlined;
    if (normalized.contains('water')) return Icons.water_drop_outlined;
    if (normalized.contains('electric')) return Icons.bolt_outlined;
    return Icons.report_outlined;
  }

  Color _iconColor(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('road')) return const Color(0xFFF472B6);
    if (normalized.contains('water')) return const Color(0xFF60A5FA);
    if (normalized.contains('electric')) return const Color(0xFFFBBF24);
    return const Color(0xFFA78BFA);
  }
}
