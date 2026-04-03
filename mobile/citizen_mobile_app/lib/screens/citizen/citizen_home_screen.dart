import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../widgets/citizen_avatar.dart';
import 'citizen_notifications_screen.dart';
import 'citizen_profile_screen.dart';
import 'my_complaints_screen.dart';
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

  late Future<Map<String, dynamic>> _payloadFuture;
  int _selectedFilter = 0;
  int _currentIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _payloadFuture = Future.wait<dynamic>([
      _dashboardService.getDashboardStats(),
      _reportService.getReports(),
      _authService.getCurrentUser(),
    ]).then(
      (values) => {
        'dashboard': values[0] as Map<String, dynamic>,
        'reports': values[1] as List<dynamic>,
        'user': values[2] as Map<String, dynamic>,
      },
    );
  }

  Future<void> _refresh() async {
    final future = Future.wait<dynamic>([
      _dashboardService.getDashboardStats(),
      _reportService.getReports(),
      _authService.getCurrentUser(),
    ]).then(
      (values) => {
        'dashboard': values[0] as Map<String, dynamic>,
        'reports': values[1] as List<dynamic>,
        'user': values[2] as Map<String, dynamic>,
      },
    );

    setState(() {
      _payloadFuture = future;
    });

    await future;
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

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CitizenNotificationsScreen(),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B1322),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1322),
              Color(0xFF10192E),
              Color(0xFF0E1525),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _payloadFuture,
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

                final payload = snapshot.data ?? const <String, dynamic>{};
                final dashboard =
                    payload['dashboard'] as Map<String, dynamic>? ?? const {};
                final reports = payload['reports'] as List<dynamic>? ?? const [];
                final user = payload['user'] as Map<String, dynamic>? ?? const {};
                final visibleReports = _applySearch(_applyCategoryFilter(reports));
                final notificationCount = reports
                    .where((item) => _normalizedStatus(item as Map<String, dynamic>) != 'Resolved')
                    .length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 108),
                  children: [
                    _buildHeader(user, notificationCount),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 18),
                    _buildStatsRow(dashboard),
                    const SizedBox(height: 18),
                    _buildReportCard(),
                    const SizedBox(height: 14),
                    _buildNoticeCard(),
                    const SizedBox(height: 16),
                    _buildFilterChips(reports),
                    const SizedBox(height: 14),
                    _buildRecentHeader(visibleReports.length),
                    const SizedBox(height: 12),
                    if (visibleReports.isEmpty)
                      _buildEmptyState()
                    else
                      ...visibleReports.take(6).map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _IssueCard(
                                report: item as Map<String, dynamic>,
                                onTap: _openMyReports,
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
      bottomNavigationBar: _buildBottomNav(),
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

  Widget _buildHeader(
    Map<String, dynamic> user,
    int notificationCount,
  ) {
    final profileName = (user['name'] ?? 'Citizen').toString().trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CitizenAvatar(
          name: profileName,
          size: 48,
          backgroundColor: const Color(0xFF2D447B),
          textColor: const Color(0xFFC6D6FF),
          borderColor: Colors.white.withOpacity(0.22),
          borderWidth: 1.5,
          fontSize: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            profileName.isEmpty ? 'Citizen' : profileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        _HeaderPill(
          icon: Icons.location_on,
          label: 'Tacloban',
          onTap: () {},
        ),
        const SizedBox(width: 10),
        _BellButton(
          count: notificationCount,
          onTap: _openNotifications,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2338),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF7C8AAA), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search by title or location...',
                hintStyle: TextStyle(
                  color: Color(0xFF7C8AAA),
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close, color: Color(0xFF7C8AAA), size: 18),
            ),
        ],
      ),
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
            label: 'Total Issues',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.fiber_new_rounded,
            iconColor: const Color(0xFFFBBF24),
            value: '${dashboard['new'] ?? 0}',
            label: 'New',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.access_time_filled_rounded,
            iconColor: const Color(0xFFE5E7EB),
            value: '${dashboard['in_progress'] ?? 0}',
            label: 'Active',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.check_box_rounded,
            iconColor: const Color(0xFF4ADE80),
            value: '${dashboard['resolved'] ?? 0}',
            label: 'Resolved',
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard() {
    return InkWell(
      onTap: _openSubmitReport,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4F83FF),
              Color(0xFF3B82F6),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.32),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: Color(0x30FFFFFF),
              child: Icon(Icons.add, color: Colors.white),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an Issue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Submit directly to the live system',
                    style: TextStyle(
                      color: Color(0xFFDCEAFF),
                      fontSize: 13,
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2112),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8F6A1F)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          SizedBox(height: 8),
          Text(
            'New reports submitted are stored in the backend database immediately.',
            style: TextStyle(
              color: Color(0xFFD7C7A5),
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

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == index;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = index);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF3B82F6) : const Color(0xFF121B2F),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF3B82F6)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                filter == 'All Issues'
                    ? filter
                    : '$filter (${_filterCountFor(reports, filter)})',
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFB7C0D5),
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
    return Row(
      children: [
        const Text(
          'Recent Issues',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '$count reports',
          style: const TextStyle(
            color: Color(0xFF77839D),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151E31),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white70, size: 32),
          const SizedBox(height: 10),
          const Text(
            'No reports found',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another search or submit your first complaint.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: const Color(0xFF101827),
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      child: SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_filled,
              label: 'Home',
              selected: _currentIndex == 0,
              color: const Color(0xFF3B82F6),
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.description_outlined,
              label: 'Reports',
              selected: _currentIndex == 1,
              color: const Color(0xFFE5E7EB),
              onTap: () {
                setState(() => _currentIndex = 1);
                _openMyReports();
              },
            ),
            const SizedBox(width: 56),
            _NavItem(
              icon: Icons.notifications_active_outlined,
              label: 'Alerts',
              selected: _currentIndex == 3,
              color: const Color(0xFFFBBF24),
              onTap: () {
                setState(() => _currentIndex = 3);
                _openNotifications();
              },
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: _currentIndex == 4,
              color: const Color(0xFF8B5CF6),
              onTap: () async {
                final user = await _authService.getCurrentUser();
                if (!mounted) return;
                setState(() => _currentIndex = 4);
                await _openProfile(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> _buildFilters(List<dynamic> reports) {
    final names = reports
        .map((item) => ((item as Map<String, dynamic>)['category']
                as Map<String, dynamic>?)?['name']
            ?.toString())
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
      final category = ((item as Map<String, dynamic>)['category']
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
      final category = ((item as Map<String, dynamic>)['category']
                  as Map<String, dynamic>?)?['name']
              ?.toString() ??
          '';
      return category == filter;
    }).length;
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
      return title.contains(query) || location.contains(query);
    }).toList();
  }

  String _normalizedStatus(Map<String, dynamic> report) {
    final raw = (report['status'] ?? 'Submitted').toString();
    switch (raw) {
      case 'New':
        return 'New';
      case 'Pending':
        return 'Pending';
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
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF182238),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF472B6), size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB9C3D9),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF182238),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Color(0xFFFBBF24),
              size: 19,
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
                  border: Border.all(color: const Color(0xFF0B1322), width: 2),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171F32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9EA9C2),
              fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    final title = (report['title'] ?? 'Untitled report').toString();
    final categoryName =
        ((report['category'] as Map<String, dynamic>?)?['name'] ?? 'General')
            .toString();
    final location = (report['location'] ?? 'No location').toString();
    final officeName =
        ((report['office'] as Map<String, dynamic>?)?['name'] ?? 'Assigned office')
            .toString();
    final status = _displayStatus((report['status'] ?? 'Pending').toString());
    final statusColor = _statusColor(status);
    final iconColor = _iconColor(categoryName);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171F32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _issueIcon(categoryName),
                color: iconColor,
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
                      fontSize: 18,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        '•',
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
                          style: const TextStyle(
                            color: Color(0xFFA2AEC7),
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
                color: statusColor.withOpacity(0.18),
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
        return 'New';
      case 'Pending':
        return 'Pending';
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
      case 'Pending':
        return const Color(0xFFFBBF24);
      case 'New':
        return const Color(0xFFFB7185);
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? color : const Color(0xFF7B86A1),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: selected ? color : const Color(0xFF7B86A1),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
