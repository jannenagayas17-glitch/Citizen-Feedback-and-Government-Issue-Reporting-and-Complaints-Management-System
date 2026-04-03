import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../auth/register_screen.dart';

class ManageAdminsScreen extends StatefulWidget {
  const ManageAdminsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends State<ManageAdminsScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();

  late Future<_StaffPayload> _payloadFuture;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All Roles';
  String _selectedJobFilter = 'All Staff';
  bool _availableOnly = false;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadPayload();
  }

  Future<_StaffPayload> _loadPayload() async {
    final results = await Future.wait<dynamic>([
      _authService.getAdminUsers(),
      _authService.getCurrentUser(),
      _reportService.getAdminReports(),
    ]);

    return _StaffPayload(
      users: results[0] as List<dynamic>,
      currentUser: results[1] as Map<String, dynamic>,
      reports: results[2] as List<dynamic>,
    );
  }

  Future<void> _refresh() async {
    final future = _loadPayload();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _verify(int id) async {
    await _authService.verifyAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account verified successfully.')));
    await _refresh();
  }

  Future<void> _deactivate(int id) async {
    final confirmed = await _confirmDialog(
      title: 'Deactivate Account?',
      message:
          'This will remove elevated access and sign the account out of active sessions.',
      actionLabel: 'Deactivate',
      actionColor: const Color(0xFFDC2626),
    );
    if (confirmed != true) return;

    await _authService.deactivateAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account deactivated successfully.')));
    await _refresh();
  }

  Future<void> _reactivate(int id) async {
    final confirmed = await _confirmDialog(
      title: 'Reactivate Account?',
      message: 'This will restore account access so the user can sign in again.',
      actionLabel: 'Reactivate',
      actionColor: const Color(0xFF16A34A),
    );
    if (confirmed != true) return;

    await _authService.reactivateAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account reactivated successfully.')));
    await _refresh();
  }

  Future<void> _delete(int id) async {
    final confirmed = await _confirmDialog(
      title: 'Delete Account?',
      message:
          'This will permanently remove the account and its unused access. This action cannot be undone.',
      actionLabel: 'Delete',
      actionColor: const Color(0xFFB91C1C),
    );
    if (confirmed != true) return;

    await _authService.deleteAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account deleted successfully.')));
    await _refresh();
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    required Color actionColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2234),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAddMember() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    await _refresh();
  }

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final officeName = (office['name'] ?? '').toString().trim();
      if (officeName.isNotEmpty) return officeName;
    }
    final department = (user['department'] ?? '').toString().trim();
    return department.isEmpty ? 'Department' : department;
  }

  int _userId(Map<String, dynamic> user) {
    final rawId = user['id'];
    if (rawId is int) {
      return rawId;
    }
    return int.tryParse('$rawId') ?? 0;
  }

  List<Map<String, dynamic>> _staffUsers(_StaffPayload payload) {
    final currentUser = payload.currentUser;
    final currentRole = (currentUser['role'] ?? '').toString().trim();
    final currentDepartment = _departmentLabel(currentUser).trim();

    final users = payload.users.whereType<Map<String, dynamic>>().where((user) {
      final role = (user['role'] ?? '').toString().trim();
      if (role != 'admin' && role != 'pending_admin' && role != 'super_admin') {
        return false;
      }
      if (currentRole == 'super_admin') {
        return true;
      }
      return (user['department'] ?? '').toString().trim() == currentDepartment;
    }).toList();

    users.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return users;
  }

  List<String> _jobTitleFilters(List<Map<String, dynamic>> users) {
    final titles = users
        .map((user) => (user['job_title'] ?? '').toString().trim())
        .where((title) => title.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Staff', ...titles.take(2)];
  }

  List<_StaffRow> _staffRows(_StaffPayload payload) {
    final rows = _staffUsers(payload).map((user) {
      final userId = user['id'] is int
          ? user['id'] as int
          : int.tryParse('${user['id']}') ?? 0;
      final assignments = payload.reports
          .whereType<Map<String, dynamic>>()
          .where((report) {
            final assignedTo = report['assigned_to'] is int
                ? report['assigned_to'] as int
                : int.tryParse('${report['assigned_to']}');
            return assignedTo == userId;
          })
          .toList();
      final activeAssignments = assignments.where((report) {
        final status = (report['status'] ?? '').toString().trim();
        return status == 'In Progress' || status == 'Pending' || status == 'New';
      }).toList();
      assignments.sort((a, b) {
        final aDate = DateTime.tryParse(
              (a['updated_at'] ?? a['created_at'] ?? '').toString(),
            ) ??
            DateTime(2000);
        final bDate = DateTime.tryParse(
              (b['updated_at'] ?? b['created_at'] ?? '').toString(),
            ) ??
            DateTime(2000);
        return bDate.compareTo(aDate);
      });
      return _StaffRow(
        user: user,
        activeAssignments: activeAssignments,
        latestAssignment: assignments.isEmpty ? null : assignments.first,
      );
    }).toList();

    return rows.where((row) {
      final user = row.user;
      final search = _searchQuery.trim().toLowerCase();
      final haystack = [
        (user['name'] ?? '').toString(),
        (user['email'] ?? '').toString(),
        (user['department'] ?? '').toString(),
        (user['job_title'] ?? '').toString(),
      ].join(' ').toLowerCase();
      if (search.isNotEmpty && !haystack.contains(search)) {
        return false;
      }

      if (_selectedRoleFilter != 'All Roles') {
        final target = switch (_selectedRoleFilter) {
          'Admin' => 'admin',
          'Pending Review' => 'pending_admin',
          'Super Admin' => 'super_admin',
          _ => '',
        };
        if (target.isNotEmpty && row.role != target) {
          return false;
        }
      }

      if (_selectedJobFilter != 'All Staff' && row.jobTitle != _selectedJobFilter) {
        return false;
      }

      if (_availableOnly && !row.isAvailable) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _canDeactivateRole({
    required String currentRole,
    required String targetRole,
    required bool isSelf,
    required bool isActive,
  }) {
    if (isSelf || targetRole == 'super_admin' || !isActive) {
      return false;
    }
    return currentRole == 'super_admin' &&
        (targetRole == 'admin' || targetRole == 'pending_admin');
  }

  bool _canReactivateRole({
    required String currentRole,
    required String targetRole,
    required bool isSelf,
    required bool isActive,
  }) {
    if (isSelf || targetRole == 'super_admin' || isActive) {
      return false;
    }
    return currentRole == 'super_admin';
  }

  bool _canDeleteRole({
    required String currentRole,
    required String targetRole,
    required bool isSelf,
  }) {
    if (currentRole != 'super_admin' || isSelf || targetRole == 'super_admin') {
      return false;
    }

    return true;
  }

  Future<void> _showViewDialog(
    _StaffRow row,
    Map<String, dynamic> currentUser,
  ) async {
    final user = row.user;
    final currentRole = (currentUser['role'] ?? '').toString().trim();
    final targetRole = (user['role'] ?? '').toString().trim();
    final isActive = user['is_active'] != false;
    final userId = _userId(user);
    final isSelf = userId != 0 && userId == _userId(currentUser);
    final canVerify =
        currentRole == 'super_admin' &&
        targetRole == 'pending_admin' &&
        isActive;
    final canDeactivate = _canDeactivateRole(
      currentRole: currentRole,
      targetRole: targetRole,
      isSelf: isSelf,
      isActive: isActive,
    );
    final canReactivate = _canReactivateRole(
      currentRole: currentRole,
      targetRole: targetRole,
      isSelf: isSelf,
      isActive: isActive,
    );
    final canDelete = _canDeleteRole(
      currentRole: currentRole,
      targetRole: targetRole,
      isSelf: isSelf,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171E2F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            (user['name'] ?? 'Staff Member').toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailLine('Email', (user['email'] ?? '').toString()),
                _detailLine(
                  'Department',
                  (user['department'] ?? 'No office assigned').toString(),
                ),
                _detailLine('Role', _roleLabel(targetRole)),
                _detailLine('Job Title', row.jobTitle),
                _detailLine('Assigned', row.assignedSummary),
                _detailLine('Status', row.statusLabel),
                if (row.latestAssignment != null)
                  _detailLine(
                    'Latest Assignment',
                    (row.latestAssignment!['title'] ?? 'Assigned report').toString(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              ),
            ),
            if (canVerify)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _verify(userId);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Verify'),
              ),
            if (canDeactivate)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _deactivate(userId);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Deactivate'),
              ),
            if (canReactivate)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _reactivate(userId);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reactivate'),
              ),
            if (canDelete)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _delete(userId);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7F1D1D),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
          ],
        );
      },
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      case 'citizen':
        return 'Citizen';
      case 'pending_admin':
        return 'Pending Review';
      default:
        return 'Staff';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isWide = MediaQuery.of(context).size.width >= 1100;

    final content = FutureBuilder<_StaffPayload>(
      future: _payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _darkPanel(
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        }

        final payload = snapshot.data!;
        final currentUser = payload.currentUser;
        final rows = _staffRows(payload);
        final jobFilters = _jobTitleFilters(_staffUsers(payload));
        final departmentName = _departmentLabel(currentUser);
        final activeCount =
            rows.where((row) => row.activeAssignments.isNotEmpty).length;
        final availableCount = rows.where((row) => row.isAvailable).length;
        final pendingCount =
            rows.where((row) => row.role == 'pending_admin').length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomSafeArea),
          children: [
            if (!widget.embedded && isWide)
              _portalTopBar(
                departmentName: departmentName,
                adminName: (currentUser['name'] ?? 'Admin User').toString(),
                notificationCount: pendingCount,
              ),
            if (!widget.embedded && isWide) const SizedBox(height: 18),
            Text(
              'Staff',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.hexagon_rounded,
                  size: 18,
                  color: Color(0xFF4C6FFF),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$departmentName - Tacloban City',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _darkPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            style: const TextStyle(color: Colors.white),
                            decoration: _filterDecoration('Search staff...'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 8,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _filterChip(
                                label: _selectedRoleFilter,
                                isActive: _selectedRoleFilter != 'All Roles',
                                onTap: () async {
                                  final selected = await _showSelectionSheet(
                                    title: 'Role Filter',
                                    options: const [
                                      'All Roles',
                                      'Admin',
                                      'Pending Review',
                                      'Super Admin',
                                    ],
                                    currentValue: _selectedRoleFilter,
                                  );
                                  if (selected == null) return;
                                  setState(() => _selectedRoleFilter = selected);
                                },
                              ),
                              for (final job in jobFilters)
                                _filterChip(
                                  label: job,
                                  isActive:
                                      _selectedJobFilter == job &&
                                      job != 'All Staff',
                                  onTap: () {
                                    setState(() {
                                      _selectedJobFilter =
                                          _selectedJobFilter == job
                                              ? 'All Staff'
                                              : job;
                                    });
                                  },
                                ),
                              _filterChip(
                                label: 'Available',
                                isActive: _availableOnly,
                                onTap: () => setState(
                                  () => _availableOnly = !_availableOnly,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _openAddMember,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                ),
                                label: const Text('Add Member'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 240,
                          child: TextField(
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            style: const TextStyle(color: Colors.white),
                            decoration: _filterDecoration('Search staff...'),
                          ),
                        ),
                        _filterChip(
                          label: _selectedRoleFilter,
                          isActive: _selectedRoleFilter != 'All Roles',
                          onTap: () async {
                            final selected = await _showSelectionSheet(
                              title: 'Role Filter',
                              options: const [
                                'All Roles',
                                'Admin',
                                'Pending Review',
                                'Super Admin',
                              ],
                              currentValue: _selectedRoleFilter,
                            );
                            if (selected == null) return;
                            setState(() => _selectedRoleFilter = selected);
                          },
                        ),
                        for (final job in jobFilters)
                          _filterChip(
                            label: job,
                            isActive:
                                _selectedJobFilter == job &&
                                job != 'All Staff',
                            onTap: () {
                              setState(() {
                                _selectedJobFilter = _selectedJobFilter == job
                                    ? 'All Staff'
                                    : job;
                              });
                            },
                          ),
                        _filterChip(
                          label: 'Available',
                          isActive: _availableOnly,
                          onTap: () =>
                              setState(() => _availableOnly = !_availableOnly),
                        ),
                        FilledButton.icon(
                          onPressed: _openAddMember,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Member'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),
                  _summaryStrip(
                    total: rows.length,
                    active: activeCount,
                    available: availableCount,
                    pending: pendingCount,
                  ),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    _emptyState()
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double tableWidth = math.max<double>(
                          constraints.maxWidth,
                          1120,
                        );
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131A2A),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.04),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _tableHeader(),
                                    ...rows.map(
                                      (row) => _staffTableRow(
                                        row: row,
                                        currentUser: currentUser,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );

    final body = widget.embedded
        ? content
        : SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF4C6FFF),
              child: content,
            ),
          );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0B1020),
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Staff'),
            ),
      body: body,
    );
  }

  Future<String?> _showSelectionSheet({
    required String title,
    required List<String> options,
    required String currentValue,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...options.map((option) {
                  final selected = option == currentValue;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: selected ? const Color(0xFF22325A) : null,
                    title: Text(
                      option,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop(context, option),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _portalTopBar({
    required String departmentName,
    required String adminName,
    required int notificationCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13182A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF2557D6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'CityTrack PH',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 10),
          Text(
            'Admin Portal',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.34),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            departmentName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 14),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  size: 18,
                  color: Color(0xFFF59E0B),
                ),
              ),
              if (notificationCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      notificationCount > 9 ? '9+' : '$notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2638),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFF6D5EF8),
                  child: Text(
                    adminName.isEmpty ? 'A' : adminName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  adminName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13182A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }

  InputDecoration _filterDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: Colors.white54,
        size: 18,
      ),
      filled: true,
      fillColor: const Color(0xFF1B2235),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF22325A) : const Color(0xFF1B2235),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF3B82F6)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _summaryStrip({
    required int total,
    required int active,
    required int available,
    required int pending,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _miniMetric('Total', '$total', const Color(0xFF60A5FA)),
        _miniMetric('Active', '$active', const Color(0xFF22C55E)),
        _miniMetric('Available', '$available', const Color(0xFF86EFAC)),
        _miniMetric('Pending', '$pending', const Color(0xFFFBBF24)),
      ],
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: const Color(0xFF182033),
      child: Row(
        children: [
          Expanded(flex: 4, child: _headerCell('NAME / ROLE')),
          Expanded(flex: 2, child: _headerCell('ASSIGNED')),
          Expanded(flex: 3, child: _headerCell('STATUS')),
          Expanded(flex: 2, child: _headerCell('OFFICE STATUS')),
          const SizedBox(width: 90, child: Text('ACTIONS')),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.46),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _staffTableRow({
    required _StaffRow row,
    required Map<String, dynamic> currentUser,
  }) {
    final color = row.avatarColor;
    final officeStatusColor = row.isAvailable
        ? const Color(0xFF86EFAC)
        : row.user['is_active'] == false
        ? const Color(0xFFF87171)
        : const Color(0xFF86EFAC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withValues(alpha: 0.22),
                      child: Text(
                        row.initials,
                        style: TextStyle(color: color, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: officeStatusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF131A2A),
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (row.user['name'] ?? 'Staff Member').toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.jobTitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _infoCell(row.assignedSummary, row.assignmentSubline)),
          Expanded(flex: 3, child: _statusCell(row.statusColor, row.statusLabel, row.statusSubline)),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: officeStatusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.officeStatusLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () => _showViewDialog(row, currentUser),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2557D6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  minimumSize: Size.zero,
                ),
                child: const Text('View'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCell(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _statusCell(Color color, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.46),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF4C6FFF), size: 34),
          const SizedBox(height: 12),
          const Text(
            'No staff records matched your filters.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try changing the role, staff title, or availability filters.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffPayload {
  const _StaffPayload({
    required this.users,
    required this.currentUser,
    required this.reports,
  });

  final List<dynamic> users;
  final Map<String, dynamic> currentUser;
  final List<dynamic> reports;
}

class _StaffRow {
  const _StaffRow({
    required this.user,
    required this.activeAssignments,
    required this.latestAssignment,
  });

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> activeAssignments;
  final Map<String, dynamic>? latestAssignment;

  String get role => (user['role'] ?? '').toString().trim();

  String get jobTitle {
    final value = (user['job_title'] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
    if (role == 'pending_admin') return 'Pending Staff';
    if (role == 'super_admin') return 'Portal Administrator';
    return 'Administrative Staff';
  }

  String get initials {
    final name = (user['name'] ?? '').toString().trim();
    if (name.isEmpty) return 'ST';
    final parts =
        name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color get avatarColor {
    switch (jobTitle.toLowerCase()) {
      case 'field engineer':
        return const Color(0xFF5B8CFF);
      case 'pipe technician':
        return const Color(0xFF60D6A8);
      case 'maintenance crew':
        return const Color(0xFFEAB308);
      default:
        return const Color(0xFFB77CFF);
    }
  }

  bool get isAvailable =>
      activeAssignments.isEmpty &&
      user['is_active'] != false &&
      role != 'pending_admin';

  String get assignedSummary {
    if (activeAssignments.isEmpty) return 'No active reports';
    final count = activeAssignments.length;
    return count == 1 ? '1 active report' : '$count active reports';
  }

  String get assignmentSubline {
    if (latestAssignment == null) return 'Ready for assignment';
    final title = (latestAssignment!['title'] ?? '').toString().trim();
    return title.isEmpty ? '1 recent assigned' : title;
  }

  String get statusLabel {
    if (user['is_active'] == false) return 'Deactivated';
    if (role == 'pending_admin') return 'Pending review';
    if (activeAssignments.isNotEmpty) return 'Out in the field';
    return 'Available';
  }

  String get officeStatusLabel {
    if (user['is_active'] == false) return 'Offline';
    if (role == 'pending_admin') return 'Awaiting access';
    return activeAssignments.isNotEmpty ? 'Out in the field' : 'Available';
  }

  String get statusSubline {
    if (user['is_active'] == false) return 'Account access removed';
    if (role == 'pending_admin') return 'Waiting for verification';
    if (latestAssignment == null) return 'Ready for assignment';

    final title = (latestAssignment!['title'] ?? 'Recent assignment').toString();
    final updatedAt = DateTime.tryParse(
      (latestAssignment!['updated_at'] ?? latestAssignment!['created_at'] ?? '')
          .toString(),
    );
    return '$title - ${_timeAgo(updatedAt)}';
  }

  Color get statusColor {
    if (user['is_active'] == false) return const Color(0xFFF87171);
    if (role == 'pending_admin') return const Color(0xFFFBBF24);
    return const Color(0xFF86EFAC);
  }

  static String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'unknown time';
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 1) {
      return difference.inDays == 1
          ? '1 day ago'
          : '${difference.inDays} days ago';
    }
    if (difference.inHours >= 1) {
      return difference.inHours == 1
          ? '1 hour ago'
          : '${difference.inHours} hours ago';
    }
    if (difference.inMinutes >= 1) {
      return difference.inMinutes == 1
          ? '1 minute ago'
          : '${difference.inMinutes} minutes ago';
    }
    return 'just now';
  }
}
