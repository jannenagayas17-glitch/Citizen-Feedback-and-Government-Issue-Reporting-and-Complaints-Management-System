import 'dart:ui';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import 'complaint_detail_screen.dart';
import 'my_complaints_screen.dart';
import 'citizen_notifications_screen.dart';
import 'citizen_profile_screen.dart';
import 'submit_complaint_screen.dart';

class CitizenHomeScreen extends StatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  int _selectedFilter = 0;
  int _currentIndex = 0;
  String _searchQuery = '';
  late Future<Map<String, dynamic>> _dashboardFuture;
  late Future<List<dynamic>> _reportsFuture;
  late Future<Map<String, dynamic>> _userFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dashboardFuture = _dashboardService.getDashboardStats();
    _reportsFuture = _reportService.getReports();
    _userFuture = _authService.getCurrentUser();
  }

  Future<void> _refresh() async {
    final dashboardFuture = _dashboardService.getDashboardStats();
    final reportsFuture = _reportService.getReports();
    final userFuture = _authService.getCurrentUser();

    setState(() {
      _dashboardFuture = dashboardFuture;
      _reportsFuture = reportsFuture;
      _userFuture = userFuture;
    });

    await Future.wait([
      dashboardFuture,
      reportsFuture,
      userFuture,
    ]);
  }

  Future<void> _openSubmitReport() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubmitComplaintScreen(),
      ),
    );

    if (!mounted) return;
    setState(() => _currentIndex = 0);

    if (created != null) {
      await _refresh();
    }
  }

  Future<void> _openMyReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyComplaintsScreen(),
      ),
    );
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    await _refresh();
  }

  Future<void> _openNotifications(List<dynamic> reports) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CitizenNotificationsScreen(reports: reports),
      ),
    );
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    await _refresh();
  }

  Future<void> _openProfile(Map<String, dynamic> user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CitizenProfileScreen(user: user),
      ),
    );
    if (!mounted) return;
    setState(() => _currentIndex = 0);
    await _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0C1727),
                  Color(0xFF1E293B),
                  Color(0xFF463327),
                ],
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<Map<String, dynamic>>(
            future: Future.wait<dynamic>([
              _dashboardFuture,
              _reportsFuture,
              _userFuture,
            ]).then(
              (values) => {
                'dashboard': values[0] as Map<String, dynamic>,
                'reports': values[1] as List<dynamic>,
                'user': values[2] as Map<String, dynamic>,
              },
            ),
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
                    ),
                  ],
                );
              }

              final payload = snapshot.data ?? const <String, dynamic>{};
              final dashboard =
                  payload['dashboard'] as Map<String, dynamic>? ?? const {};
              final reports = payload['reports'] as List<dynamic>? ?? const [];
              final user = payload['user'] as Map<String, dynamic>? ?? const {};
              final filteredReports = _applySearch(_applyFilter(reports));

              return ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                children: [
                  _buildHeader(user, reports),
                  const SizedBox(height: 14),
                  _buildGlassShell(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(reports.length),
                        const SizedBox(height: 14),
                        _buildStatsRow(dashboard),
                        const SizedBox(height: 12),
                        _buildReportCard(),
                        const SizedBox(height: 10),
                        _buildNoticeCard(),
                        const SizedBox(height: 12),
                        _buildFilterChips(reports),
                        const SizedBox(height: 16),
                        _buildRecentHeader(filteredReports.length),
                        const SizedBox(height: 10),
                        if (filteredReports.isEmpty)
                          _buildEmptyState()
                        else
                          ...filteredReports.map(
                            (report) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _IssueCard(
                                report: report as Map<String, dynamic>,
                                onTap: () {
                                  final id = report['id'];
                                  final reportId = id is int ? id : int.tryParse('$id');
                                  if (reportId == null) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ComplaintDetailScreen(
                                        reportId: reportId,
                                      ),
                                    ),
                                  ).then((_) async {
                                    if (!mounted) return;
                                    setState(() => _currentIndex = 0);
                                    await _refresh();
                                  });
                                },
                              ),
                            ),
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
        ],
      ),
      bottomNavigationBar: _buildBottomNav(primaryBlue),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: primaryBlue,
          onPressed: _openSubmitReport,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  List<dynamic> _applyFilter(List<dynamic> reports) {
    return _filterReportsForIndex(reports, _selectedFilter);
  }

  List<dynamic> _applySearch(List<dynamic> reports) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return reports;
    }

    return reports.where((item) {
      final report = item as Map<String, dynamic>;
      final title = (report['title'] ?? '').toString().toLowerCase();
      final location = (report['location'] ?? '').toString().toLowerCase();
      final barangay = (report['barangay'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          location.contains(query) ||
          barangay.contains(query);
    }).toList();
  }

  List<dynamic> _filterReportsForIndex(List<dynamic> reports, int index) {
    if (index == 0) {
      return reports;
    }

    final selected = _filterOptions[index].toLowerCase();
    return reports.where((item) {
      final report = item as Map<String, dynamic>;
      final category = (report['category'] as Map<String, dynamic>?)?['name']
              ?.toString()
              .toLowerCase() ??
          '';
      return category.contains(selected);
    }).toList();
  }

  List<String> get _filterOptions => const [
        'All Issues',
        'Roads',
        'Water',
        'Electric',
      ];

  Widget _buildHeader(Map<String, dynamic> user, List<dynamic> reports) {
    final name = (user['name'] ?? 'Citizen').toString().trim();
    final firstName = name.isEmpty ? 'Citizen' : name.split(' ').first;
    final activeNotifications = reports
        .where(
          (item) => ((item as Map<String, dynamic>)['status'] ?? 'New')
                  .toString() !=
              'Resolved',
        )
        .length;

    return _buildGlassShell(
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
              border: Border.all(
                color: const Color(0xFFD8B15A),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  firstName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tacloban City Engineering Office',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Tacloban',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openNotifications(reports),
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    if (activeNotifications > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            activeNotifications > 9 ? '9+' : '$activeNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(int reportsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white.withOpacity(0.72), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: reportsCount == 0
                    ? 'No submitted issues yet'
                    : 'Search by title or location',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 13,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            InkWell(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.72),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> dashboard) {
    final total = '${dashboard['total_reports'] ?? 0}';
    final newCount = '${dashboard['new'] ?? 0}';
    final inProgress = '${dashboard['in_progress'] ?? 0}';
    final resolved = '${dashboard['resolved'] ?? 0}';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            number: total,
            label: 'Total\nIssues',
            color: const Color(0xFF94D82D),
            icon: Icons.insert_chart_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            number: newCount,
            label: 'New',
            color: const Color(0xFF20C997),
            icon: Icons.fiber_new_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            number: inProgress,
            label: 'Active',
            color: const Color(0xFFFF922B),
            icon: Icons.access_time,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            number: resolved,
            label: 'Resolved',
            color: const Color(0xFFFF6B6B),
            icon: Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard() {
    const primaryBlue = Color(0xFF2563EB);

    return InkWell(
      onTap: _openSubmitReport,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primaryBlue.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withOpacity(0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Color(0x33FFFFFF),
              child: Icon(Icons.add, color: Colors.white),
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
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                    Text(
                    'Submit a new issue directly to the live system',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                    ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE8A3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFFA000), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live reporting is enabled',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF8D6E00),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'New reports submitted from this form are stored in the backend database immediately.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF8D6E00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<dynamic> reports) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedFilter == index;
          final count = _filterReportsForIndex(reports, index).length;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2563EB)
                    : Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : Colors.white.withOpacity(0.14),
                ),
              ),
              child: Text(
                '${_filterOptions[index]}${index == 0 ? '' : ' ($count)'}',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withOpacity(0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentHeader(int count) {
    return Row(
      children: [
        const Text(
          'Recent Issues',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Text(
          '$count reports',
          style: TextStyle(color: Colors.white.withOpacity(0.56), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 36,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 10),
          const Text(
            'No reports yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Report an Issue" to create your first real report and save it to the database.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.68)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color primaryBlue) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: const Color(0xFF1B2334),
      child: SizedBox(
        height: 68,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.description_outlined,
              label: 'Reports',
              selected: _currentIndex == 1,
              onTap: () {
                setState(() => _currentIndex = 1);
                _openMyReports();
              },
            ),
            const SizedBox(width: 56),
            _NavItem(
              icon: Icons.notifications_none,
              label: 'Alerts',
              selected: _currentIndex == 3,
              onTap: () {
                setState(() => _currentIndex = 3);
                _reportsFuture.then(_openNotifications);
              },
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: _currentIndex == 4,
              onTap: () {
                setState(() => _currentIndex = 4);
                _userFuture.then(_openProfile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassShell({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.08),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.number,
    required this.label,
    required this.color,
    required this.icon,
  });

  final String number;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            number,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.72),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.report,
    required this.onTap,
  });

  final Map<String, dynamic> report;
  final VoidCallback onTap;

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF69DB7C);
      case 'In Progress':
        return const Color(0xFFFFC078);
      case 'Pending':
        return const Color(0xFF74C0FC);
      case 'New':
        return const Color(0xFFE599F7);
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('road')) return Icons.construction;
    if (normalized.contains('water')) return Icons.water_drop;
    if (normalized.contains('electric')) return Icons.bolt;
    if (normalized.contains('waste')) return Icons.delete_outline;
    return Icons.report_problem_outlined;
  }

  Color _categoryColor(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('road')) return const Color(0xFFFF6B6B);
    if (normalized.contains('water')) return const Color(0xFF4DABF7);
    if (normalized.contains('electric')) return const Color(0xFFFFA94D);
    if (normalized.contains('waste')) return const Color(0xFFADB5BD);
    return const Color(0xFF7C83FD);
  }

  @override
  Widget build(BuildContext context) {
    final title = (report['title'] ?? 'Untitled report').toString();
    final location = (report['location'] ?? report['barangay'] ?? 'No location')
        .toString();
    final categoryName =
        ((report['category'] as Map<String, dynamic>?)?['name'] ?? 'General')
            .toString();
    final priority = (report['priority'] ?? 'Normal').toString();
    final status = (report['status'] ?? 'New').toString();
    final color = _categoryColor(categoryName);
    final statusColor = _statusColor(status);
    final date = (report['created_at'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _categoryIcon(categoryName),
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    location,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _smallTag(
                        priority,
                        bg: color.withOpacity(.12),
                        textColor: color,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          categoryName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _smallTag(
                  status,
                  bg: statusColor.withOpacity(.15),
                  textColor: statusColor,
                ),
                const SizedBox(height: 28),
                Text(
                  date.isEmpty ? '' : date.substring(0, 10),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.56),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallTag(
    String text, {
    required Color bg,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF2563EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? active : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? active : Colors.white.withOpacity(0.6),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
