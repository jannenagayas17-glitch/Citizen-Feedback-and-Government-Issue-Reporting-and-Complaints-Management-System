import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';

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
  String _selectedAccountGroup = 'Admin Accounts';
  String _selectedRoleFilter = 'All Role';
  String _selectedDepartmentFilter = 'All Department';
  String _selectedAvailabilityFilter = 'Account Status';

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
      _authService.getOffices(includeInactive: true),
    ]);

    return _StaffPayload(
      users: results[0] as List<dynamic>,
      currentUser: results[1] as Map<String, dynamic>,
      reports: results[2] as List<dynamic>,
      offices: results[3] as List<dynamic>,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account verified successfully.')),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deactivated successfully.')),
    );
    await _refresh();
  }

  Future<void> _reactivate(int id) async {
    final confirmed = await _confirmDialog(
      title: 'Reactivate Account?',
      message:
          'This will restore account access so the user can sign in again.',
      actionLabel: 'Reactivate',
      actionColor: const Color(0xFF16A34A),
    );
    if (confirmed != true) return;

    await _authService.reactivateAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account reactivated successfully.')),
    );
    await _refresh();
  }

  Future<void> _delete(_StaffRow row) async {
    final id = _userId(row.user);
    final isArchived = row.isArchived;
    final confirmed = await _confirmDialog(
      title: isArchived ? 'Permanently Delete Account?' : 'Archive Account?',
      message: isArchived
          ? 'This account is already archived. Permanent delete will remove it from the database and cannot be undone.'
          : 'This will archive the account first. You can still view it here and reactivate it before permanent deletion.',
      actionLabel: isArchived ? 'Permanent Delete' : 'Archive',
      actionColor: const Color(0xFFB91C1C),
    );
    if (confirmed != true) return;

    await _authService.deleteAccount(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArchived
              ? 'Account permanently deleted successfully.'
              : 'Account archived successfully.',
        ),
      ),
    );
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
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

  Future<void> _openAddAdmin() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AddMemberDialog(
        authService: _authService,
        accountKind: _ManagedAccountKind.admin,
      ),
    );

    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openAddCitizen() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AddMemberDialog(
        authService: _authService,
        accountKind: _ManagedAccountKind.citizen,
      ),
    );

    if (created == true) {
      setState(() {
        _selectedAccountGroup = 'Citizen Accounts';
        _selectedRoleFilter = 'All Role';
        _selectedDepartmentFilter = 'All Department';
        _selectedAvailabilityFilter = 'Account Status';
      });
      await _refresh();
    }
  }

  Future<void> _openEditAccount(_StaffRow row) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _EditAccountDialog(authService: _authService, user: row.user),
    );

    if (updated == true) {
      await _refresh();
    }
  }

  String _departmentLabel(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString().trim();
    if (role == 'super_admin') return 'System Administration';
    if (role == 'citizen') return 'Citizen Accounts';

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
      if (role != 'admin' &&
          role != 'pending_admin' &&
          role != 'super_admin' &&
          role != 'citizen') {
        return false;
      }
      if (currentRole == 'super_admin') {
        return true;
      }
      if (role == 'citizen') {
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

  List<String> _departmentFilters(_StaffPayload payload) {
    final officeDepartments = <String>{};

    for (final office in payload.offices.whereType<Map<String, dynamic>>()) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        officeDepartments.add(name);
      }
    }

    final departments = officeDepartments.isNotEmpty
        ? officeDepartments
        : <String>{};

    if (departments.isEmpty) {
      for (final user in payload.users.whereType<Map<String, dynamic>>()) {
        final role = (user['role'] ?? '').toString().trim();
        if (role == 'citizen' || role == 'super_admin') {
          continue;
        }

        final department = (user['department'] ?? '').toString().trim();
        if (department.isNotEmpty) {
          departments.add(department);
        }

        final office = user['office'];
        if (office is Map<String, dynamic>) {
          final officeName = (office['name'] ?? '').toString().trim();
          if (officeName.isNotEmpty) {
            departments.add(officeName);
          }
        }
      }
    }

    final sortedDepartments = departments.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All Department', ...sortedDepartments];
  }

  List<_StaffRow> _staffRows(_StaffPayload payload) {
    final departmentFilters = _departmentFilters(payload);
    final selectedDepartment =
        departmentFilters.contains(_selectedDepartmentFilter)
        ? _selectedDepartmentFilter
        : 'All Department';
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
        return status == 'In Progress' ||
            status == 'Pending' ||
            status == 'New';
      }).toList();
      assignments.sort((a, b) {
        final aDate =
            DateTime.tryParse(
              (a['updated_at'] ?? a['created_at'] ?? '').toString(),
            ) ??
            DateTime(2000);
        final bDate =
            DateTime.tryParse(
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
        _departmentLabel(user),
        (user['job_title'] ?? '').toString(),
        row.role,
        _roleLabel(row.role),
        row.jobTitle,
      ].join(' ').toLowerCase();
      if (search.isNotEmpty && !haystack.contains(search)) {
        return false;
      }

      if (_selectedAccountGroup == 'Admin Accounts' && row.role == 'citizen') {
        return false;
      }

      if (_selectedAccountGroup == 'Citizen Accounts' && row.role != 'citizen') {
        return false;
      }

      if (_selectedRoleFilter != 'All Role') {
        final target = switch (_selectedRoleFilter) {
          'Administrator' => 'admin',
          'Pending Account' => 'pending_admin',
          'System Administrator' => 'super_admin',
          'Citizen' => 'citizen',
          _ => '',
        };
        if (target == 'admin' && row.role != 'admin') {
          return false;
        }
        if (target.isNotEmpty && target != 'admin' && row.role != target) {
          return false;
        }
      }

      if (selectedDepartment != 'All Department' &&
          _departmentLabel(user) != selectedDepartment) {
        return false;
      }

      if (_selectedAvailabilityFilter == 'Available' && !row.isAvailable) {
        return false;
      }

      if (_selectedAvailabilityFilter == 'Pending' &&
          row.role != 'pending_admin') {
        return false;
      }

      if (_selectedAvailabilityFilter == 'Deactivated' &&
          (row.user['is_active'] != false || row.isArchived)) {
        return false;
      }

      if (_selectedAvailabilityFilter == 'Archived' && !row.isArchived) {
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
    required bool isArchived,
  }) {
    if (isSelf || targetRole == 'super_admin' || !isActive || isArchived) {
      return false;
    }
    return currentRole == 'super_admin' &&
        (targetRole == 'admin' ||
            targetRole == 'pending_admin' ||
            targetRole == 'citizen');
  }

  bool _canReactivateRole({
    required String currentRole,
    required String targetRole,
    required bool isSelf,
    required bool isActive,
    required bool isArchived,
  }) {
    if (isSelf || targetRole == 'super_admin') {
      return false;
    }
    return currentRole == 'super_admin' && (!isActive || isArchived);
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
    final isArchived = row.isArchived;
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
      isArchived: isArchived,
    );
    final canReactivate = _canReactivateRole(
      currentRole: currentRole,
      targetRole: targetRole,
      isSelf: isSelf,
      isActive: isActive,
      isArchived: isArchived,
    );
    final canDelete = _canDeleteRole(
      currentRole: currentRole,
      targetRole: targetRole,
      isSelf: isSelf,
    );
    final canEdit =
        currentRole == 'super_admin' &&
        !isSelf &&
        targetRole != 'super_admin' &&
        !isArchived;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171E2F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            (user['name'] ?? 'Staff Member').toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailLine('Email', (user['email'] ?? '').toString()),
                _detailLine(
                  targetRole == 'citizen' ? 'Account Group' : 'Department',
                  targetRole == 'super_admin'
                      ? 'System Administration'
                      : targetRole == 'citizen'
                      ? 'Citizen Account'
                      : _departmentLabel(user),
                ),
                _detailLine('Role', _roleLabel(targetRole)),
                if (isArchived)
                  _detailLine(
                    'Archive Status',
                    'Archived - visible until permanent deletion',
                  ),
                _detailLine(
                  targetRole == 'citizen' ? 'Profile Type' : 'Job Title',
                  row.jobTitle,
                ),
                _detailLine('Assigned', row.assignedSummary),
                _detailLine('Status', row.statusLabel),
                if (row.latestAssignment != null)
                  _detailLine(
                    'Latest Assignment',
                    (row.latestAssignment!['title'] ?? 'Assigned report')
                        .toString(),
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
            if (canEdit)
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _openEditAccount(row);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Text('Edit'),
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
                  await _delete(row);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7F1D1D),
                  foregroundColor: Colors.white,
                ),
                child: Text(isArchived ? 'Permanent Delete' : 'Archive'),
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
        return 'System Administrator';
      case 'admin':
        return 'Administrator';
      case 'citizen':
        return 'Citizen';
      case 'pending_admin':
        return 'Pending Account';
      default:
        return 'Account';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
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
                  style: TextStyle(color: colors.text),
                ),
              ),
            ],
          );
        }

        final payload = snapshot.data!;
        final currentUser = payload.currentUser;
        final rows = _staffRows(payload);
        final departmentFilters = _departmentFilters(payload);
        final isSuperAdmin =
            (currentUser['role'] ?? '').toString().trim() == 'super_admin';
        final departmentName = isSuperAdmin
            ? 'System Administrator'
            : _departmentLabel(currentUser);
        final allAccessibleUsers = _staffUsers(payload);
        final adminAccountCount = allAccessibleUsers
            .where((user) => (user['role'] ?? '').toString().trim() != 'citizen')
            .length;
        final citizenCount = allAccessibleUsers
            .where((user) => (user['role'] ?? '').toString().trim() == 'citizen')
            .length;
        final activeCount = rows
            .where((row) => row.user['is_active'] != false)
            .length;
        final reviewCount = rows
            .where((row) => row.role == 'pending_admin')
            .length;
        final archivedCount = rows.where((row) => row.isArchived).length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomSafeArea),
          children: [
            if (!widget.embedded && isWide)
              _portalTopBar(
                departmentName: departmentName,
                adminName: (currentUser['name'] ?? 'Admin User').toString(),
                notificationCount: reviewCount,
              ),
            if (!widget.embedded && isWide) const SizedBox(height: 18),
            Text(
              'Account Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.text,
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
                    isSuperAdmin
                        ? 'Manage protected administrator, department admin, and citizen accounts'
                        : '$departmentName - Tacloban City Government',
                    style: TextStyle(color: colors.mutedText, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _darkPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accounts',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _accountGroupTabs(
                    adminCount: adminAccountCount,
                    citizenCount: citizenCount,
                  ),
                  const SizedBox(height: 14),
                  _filterToolbar(
                    departmentFilters: departmentFilters,
                    canAddAccount: isSuperAdmin,
                  ),
                  const SizedBox(height: 18),
                  _summaryStrip(
                    total: rows.length,
                    active: activeCount,
                    citizens: citizenCount,
                    pending: reviewCount,
                    archived: archivedCount,
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
                        final colors = AdminThemeColors.of(context);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.panelAlt,
                                  border: Border.all(color: colors.border),
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
      backgroundColor: colors.background,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: colors.background,
              foregroundColor: colors.text,
              elevation: 0,
              title: const Text('Account Management'),
            ),
      body: body,
    );
  }

  Widget _portalTopBar({
    required String departmentName,
    required String adminName,
    required int notificationCount,
  }) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                    adminName.isEmpty
                        ? 'A'
                        : adminName.substring(0, 1).toUpperCase(),
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
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }

  InputDecoration _filterDecoration(String hintText) {
    final colors = AdminThemeColors.of(context);
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: colors.mutedText),
      prefixIcon: Icon(Icons.search_rounded, color: colors.mutedText, size: 18),
      filled: true,
      fillColor: colors.input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
    );
  }

  Widget _filterToolbar({
    required List<String> departmentFilters,
    required bool canAddAccount,
  }) {
    final searchField = TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      style: TextStyle(color: AdminThemeColors.of(context).text),
      decoration: _filterDecoration('Search name, email, role, or office...'),
    );

    final roleFilter = _filterDropdown(
      value: _selectedRoleFilter,
      items: _selectedAccountGroup == 'Citizen Accounts'
          ? const ['All Role', 'Citizen']
          : const [
              'All Role',
              'System Administrator',
              'Administrator',
              'Pending Account',
            ],
      onChanged: (value) =>
          setState(() => _selectedRoleFilter = value ?? 'All Role'),
      width: 170,
    );
    final departmentFilter = _filterDropdown(
      value: _selectedDepartmentFilter,
      items: departmentFilters,
      onChanged: (value) =>
          setState(() => _selectedDepartmentFilter = value ?? 'All Department'),
      width: 220,
    );
    final statusFilter = _filterDropdown(
      value: _selectedAvailabilityFilter,
      items: const [
        'Account Status',
        'Available',
        'Pending',
        'Deactivated',
        'Archived',
      ],
      onChanged: (value) => setState(
        () => _selectedAvailabilityFilter = value ?? 'Account Status',
      ),
      width: 180,
    );

    final addAdminButton = FilledButton.icon(
      onPressed: _openAddAdmin,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add Admin'),
    );

    final addCitizenButton = FilledButton.icon(
      onPressed: _openAddCitizen,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0891B2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
      label: const Text('Add Citizen'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const minSearchWidth = 260.0;
        final showDepartmentFilter = _selectedAccountGroup != 'Citizen Accounts';
        final fixedControlsWidth =
            170.0 +
            (showDepartmentFilter ? 220.0 : 0.0) +
            180.0 +
            (canAddAccount ? 300.0 : 0.0);
        final gapsWidth =
            12.0 * ((showDepartmentFilter ? 3 : 2) + (canAddAccount ? 2 : 0));
        final minToolbarWidth = minSearchWidth + fixedControlsWidth + gapsWidth;

        final toolbar = SizedBox(
          width: constraints.maxWidth >= minToolbarWidth
              ? constraints.maxWidth
              : minToolbarWidth,
          child: Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              roleFilter,
              if (showDepartmentFilter) ...[
                const SizedBox(width: 12),
                departmentFilter,
              ],
              const SizedBox(width: 12),
              statusFilter,
              if (canAddAccount) ...[
                const SizedBox(width: 12),
                SizedBox(width: 140, child: addAdminButton),
                const SizedBox(width: 12),
                SizedBox(width: 148, child: addCitizenButton),
              ],
            ],
          ),
        );

        if (constraints.maxWidth >= minToolbarWidth) {
          return toolbar;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: toolbar,
        );
      },
    );
  }

  Widget _accountGroupTabs({
    required int adminCount,
    required int citizenCount,
  }) {
    final colors = AdminThemeColors.of(context);
    final tabs = <({String label, int count, IconData icon})>[
      (
        label: 'Admin Accounts',
        count: adminCount,
        icon: Icons.admin_panel_settings_outlined,
      ),
      (
        label: 'Citizen Accounts',
        count: citizenCount,
        icon: Icons.people_alt_outlined,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tabs.map((tab) {
        final selected = _selectedAccountGroup == tab.label;
        return InkWell(
          onTap: () => setState(() {
            _selectedAccountGroup = tab.label;
            _selectedRoleFilter = 'All Role';
            if (tab.label == 'Citizen Accounts') {
              _selectedDepartmentFilter = 'All Department';
            }
          }),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? colors.activeNav : colors.input,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFF2563EB) : colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tab.icon,
                  color: selected ? const Color(0xFF93C5FD) : colors.mutedText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  tab.label,
                  style: TextStyle(
                    color: selected ? colors.activeText : colors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF2563EB).withValues(alpha: 0.22)
                        : colors.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tab.count}',
                    style: TextStyle(
                      color: selected ? const Color(0xFFBFDBFE) : colors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    final colors = AdminThemeColors.of(context);
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        isExpanded: true,
        menuMaxHeight: 360,
        dropdownColor: colors.panel,
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.input,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
        iconEnabledColor: colors.mutedText,
        style: TextStyle(color: colors.text, fontWeight: FontWeight.w600),
        selectedItemBuilder: (context) => items
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _summaryStrip({
    required int total,
    required int active,
    required int citizens,
    required int pending,
    required int archived,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _miniMetric('Total Accounts', '$total', const Color(0xFF60A5FA)),
        _miniMetric('Active', '$active', const Color(0xFF22C55E)),
        _miniMetric('Pending', '$pending', const Color(0xFFFBBF24)),
        _miniMetric('Citizens', '$citizens', const Color(0xFF38BDF8)),
        _miniMetric('Archived', '$archived', const Color(0xFFF87171)),
      ],
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    final colors = AdminThemeColors.of(context);
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
                color: colors.mutedText,
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
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: colors.input,
      child: Row(
        children: [
          Expanded(flex: 4, child: _headerCell('NAME / ROLE')),
          Expanded(flex: 2, child: _headerCell('REPORTS')),
          Expanded(flex: 3, child: _headerCell('ACCESS STATUS')),
          Expanded(flex: 2, child: _headerCell('ACCOUNT STATE')),
          const SizedBox(width: 90, child: Text('ACTIONS')),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    final colors = AdminThemeColors.of(context);
    return Text(
      text,
      style: TextStyle(
        color: colors.mutedText,
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
    final colors = AdminThemeColors.of(context);
    final color = row.avatarColor;
    final officeStatusColor = row.isArchived
        ? const Color(0xFFF87171)
        : row.isAvailable
        ? const Color(0xFF86EFAC)
        : row.user['is_active'] == false
        ? const Color(0xFFF87171)
        : const Color(0xFF86EFAC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
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
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
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
                          border: Border.all(color: colors.panel, width: 1.6),
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
                        (row.user['name'] ?? 'Account User').toString(),
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        row.jobTitle,
                        style: TextStyle(color: colors.mutedText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _infoCell(row.assignedSummary, row.assignmentSubline),
          ),
          Expanded(
            flex: 3,
            child: _statusCell(
              row.statusColor,
              row.statusLabel,
              row.statusSubline,
            ),
          ),
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
                    style: TextStyle(color: colors.mutedText, fontSize: 13),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
    final colors = AdminThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: colors.mutedText, fontSize: 12)),
      ],
    );
  }

  Widget _statusCell(Color color, String title, String subtitle) {
    final colors = AdminThemeColors.of(context);
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
                style: TextStyle(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: colors.mutedText, fontSize: 12)),
      ],
    );
  }

  Widget _emptyState() {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_rounded, color: Color(0xFF4C6FFF), size: 34),
          const SizedBox(height: 12),
          Text(
            'No staff records matched your filters.',
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try changing the role, staff title, or availability filters.',
            style: TextStyle(color: colors.mutedText, fontSize: 13),
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
    required this.offices,
  });

  final List<dynamic> users;
  final Map<String, dynamic> currentUser;
  final List<dynamic> reports;
  final List<dynamic> offices;
}

enum _ManagedAccountKind { admin, citizen }

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({
    required this.authService,
    required this.accountKind,
  });

  final AuthService authService;
  final _ManagedAccountKind accountKind;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  static const _adminTypes = [
    'Office Head',
    'Office Supervisor',
    'Office Coordinator',
    'Administrative Staff',
  ];

  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loadingOffices = true;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedOffice;
  String? _selectedAdminType;
  String? _formError;
  List<Map<String, dynamic>> _offices = const [];

  @override
  void initState() {
    super.initState();
    if (_isCitizenAccount) {
      _loadingOffices = false;
      return;
    }
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    try {
      final offices = await widget.authService.getOffices();
      final normalized =
          offices
              .whereType<Map<String, dynamic>>()
              .where(
                (office) => (office['name'] ?? '').toString().trim().isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              ),
            );

      if (!mounted) return;
      setState(() {
        _offices = normalized;
        _loadingOffices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOffices = false;
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _containsEmoji(String value) => _emojiRegex.hasMatch(value);

  bool _validName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r"^[A-Za-z]+(?:[.'-][A-Za-z]+)*\.?$").hasMatch(trimmed);
  }

  bool _validEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  bool get _isCitizenAccount => widget.accountKind == _ManagedAccountKind.citizen;

  String get _selectedRole => _isCitizenAccount ? 'citizen' : 'pending_admin';

  String? _validate() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_validName(firstName)) return 'Enter a valid first name.';
    if (!_validName(lastName)) return 'Enter a valid last name.';
    if (_containsEmoji('$firstName $lastName')) {
      return 'Emoji characters are not allowed in names.';
    }
    if (!_validEmail(email) || _containsEmoji(email)) {
      return 'Enter a valid email address.';
    }
    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      return 'Mobile number must be exactly 11 digits.';
    }
    if (!_isCitizenAccount) {
      if (_selectedOffice == null || _selectedOffice!.trim().isEmpty) {
        return 'Please select an office or department.';
      }
      if (_selectedAdminType == null || _selectedAdminType!.trim().isEmpty) {
        return 'Please select an admin type.';
      }
    }
    if (password.length < 8 || _containsEmoji(password)) {
      return 'Password must be at least 8 characters and contain no emoji.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _formError = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final name =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      final response = await widget.authService.createManagedAccount(
        name: name,
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        passwordConfirmation: _confirmPasswordController.text.trim(),
        role: _selectedRole,
        department: _isCitizenAccount ? null : _selectedOffice,
        jobTitle: _isCitizenAccount ? null : _selectedAdminType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ??
                (_isCitizenAccount
                    ? 'Citizen account created successfully.'
                    : 'Pending admin account created successfully.'),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 760;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: colors.panel,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 22, 18, 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors.topBarGradient),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCitizenAccount
                                    ? 'Add Citizen Account'
                                    : 'Add Admin Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _isCitizenAccount
                                    ? 'Create a citizen-only account for the mobile app.'
                                    : 'Create a pending administrator account for Super Admin verification.',
                                style: TextStyle(
                                  color: Color(0xDDEAF4FF),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_formError != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              _formError!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _responsiveFields(
                          twoColumns: twoColumns,
                          children: [
                            _textField(
                              controller: _firstNameController,
                              label: 'First Name',
                              icon: Icons.person_outline_rounded,
                            ),
                            _textField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.badge_outlined,
                            ),
                            _textField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _textField(
                              controller: _phoneController,
                              label: 'Mobile Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(11),
                              ],
                            ),
                            if (!_isCitizenAccount) _officeDropdown(),
                            if (!_isCitizenAccount) _adminTypeDropdown(),
                            _textField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            _textField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              icon: Icons.lock_reset_rounded,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.input,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isCitizenAccount
                                      ? 'Citizen accounts are active immediately and can submit or track reports from the citizen app.'
                                      : 'Pending admin accounts appear in the table for Super Admin verification before they can sign in.',
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.text,
                                  side: BorderSide(color: colors.border),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    (_saving ||
                                        (!_isCitizenAccount && _loadingOffices))
                                    ? null
                                    : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  _saving
                                      ? 'Creating...'
                                      : _isCitizenAccount
                                      ? 'Create Citizen'
                                      : 'Create Admin',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _responsiveFields({
    required bool twoColumns,
    required List<Widget> children,
  }) {
    if (!twoColumns) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: child,
              ),
            )
            .toList(),
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: children
          .map((child) => SizedBox(width: 345, child: child))
          .toList(),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colors = AdminThemeColors.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.mutedText),
      prefixIcon: Icon(icon, color: colors.mutedText, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final colors = AdminThemeColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: TextStyle(color: colors.text),
      decoration: _fieldDecoration(
        label: label,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _officeDropdown() {
    final items = _offices
        .map((office) => (office['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();

    return _selectionField(
      label: _loadingOffices ? 'Loading offices...' : 'Office / Department',
      icon: Icons.apartment_rounded,
      value: _selectedOffice,
      placeholder: _loadingOffices ? 'Please wait...' : 'Select office',
      enabled: !_loadingOffices && items.isNotEmpty,
      options: items,
      onSelected: (value) => setState(() => _selectedOffice = value),
    );
  }

  Widget _adminTypeDropdown() {
    return _selectionField(
      label: 'Admin Type',
      icon: Icons.admin_panel_settings_outlined,
      value: _selectedAdminType,
      placeholder: 'Select admin type',
      options: _adminTypes,
      onSelected: (value) => setState(() => _selectedAdminType = value),
    );
  }

  Widget _selectionField({
    required String label,
    required IconData icon,
    required String? value,
    required String placeholder,
    required List<String> options,
    required ValueChanged<String> onSelected,
    bool enabled = true,
  }) {
    final colors = AdminThemeColors.of(context);
    final displayValue = value?.trim().isNotEmpty == true
        ? value!.trim()
        : placeholder;

    return InkWell(
      onTap: enabled
          ? () async {
              final selected = await _showCenteredPicker(
                title: label,
                options: options,
                currentValue: value,
              );
              if (selected != null) {
                onSelected(selected);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(15),
      child: InputDecorator(
        decoration: _fieldDecoration(
          label: label,
          icon: icon,
          suffixIcon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: enabled
                ? colors.mutedText
                : colors.mutedText.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == null
                ? colors.mutedText.withValues(alpha: 0.78)
                : colors.text,
          ),
        ),
      ),
    );
  }

  Future<String?> _showCenteredPicker({
    required String title,
    required List<String> options,
    required String? currentValue,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = AdminThemeColors.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 28,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: colors.panel,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors.topBarGradient),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = option == currentValue;
                          return InkWell(
                            onTap: () => Navigator.pop(dialogContext, option),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colors.activeNav
                                    : colors.input,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF2563EB)
                                      : colors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: selected
                                            ? colors.activeText
                                            : colors.text,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditAccountDialog extends StatefulWidget {
  const _EditAccountDialog({required this.authService, required this.user});

  final AuthService authService;
  final Map<String, dynamic> user;

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  static const _roleOptions = [
    ('pending_admin', 'Pending Admin'),
    ('admin', 'Administrator'),
    ('citizen', 'Citizen'),
  ];

  static const _jobRoles = [
    'Office Head',
    'Office Supervisor',
    'Office Coordinator',
    'Administrative Staff',
  ];

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loadingOffices = true;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _role = 'pending_admin';
  String? _department;
  String? _formError;
  List<Map<String, dynamic>> _offices = const [];

  bool get _isCitizen => _role == 'citizen';

  @override
  void initState() {
    super.initState();
    _nameController.text = (widget.user['name'] ?? '').toString();
    _emailController.text = (widget.user['email'] ?? '').toString();
    _phoneController.text = (widget.user['mobile_number'] ?? '').toString();
    _role = (widget.user['role'] ?? 'pending_admin').toString().trim();
    if (!_roleOptions.any((option) => option.$1 == _role)) {
      _role = 'pending_admin';
    }
    _department = (widget.user['department'] ?? '').toString().trim();
    final jobTitle = (widget.user['job_title'] ?? '').toString().trim();
    _jobTitleController.text = jobTitle.isEmpty ? _jobRoles.first : jobTitle;
    _loadOffices();
  }

  Future<void> _loadOffices() async {
    try {
      final offices = await widget.authService.getOffices();
      final normalized =
          offices
              .whereType<Map<String, dynamic>>()
              .where(
                (office) => (office['name'] ?? '').toString().trim().isNotEmpty,
              )
              .toList()
            ..sort(
              (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
                (b['name'] ?? '').toString().toLowerCase(),
              ),
            );

      if (!mounted) return;
      setState(() {
        _offices = normalized;
        if (!_isCitizen &&
            (_department == null ||
                _department!.isEmpty ||
                !normalized.any((office) => office['name'] == _department))) {
          _department = normalized.isEmpty
              ? null
              : (normalized.first['name'] ?? '').toString();
        }
        _loadingOffices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOffices = false;
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!RegExp(
      r"^(?=.{3,255}$)(?=.*\s)[A-Za-z][A-Za-z'.-]*(?:\s+[A-Za-z][A-Za-z'.-]*)+$",
    ).hasMatch(name)) {
      return 'Enter a valid full name with first and last name.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (phone.isNotEmpty && !RegExp(r'^\d{11}$').hasMatch(phone)) {
      return 'Mobile number must be exactly 11 digits.';
    }
    if (!_isCitizen) {
      if (_department == null || _department!.trim().isEmpty) {
        return 'Please select a department.';
      }
      if (_jobTitleController.text.trim().isEmpty) {
        return 'Please enter a job role.';
      }
    }
    if (password.isNotEmpty && password.length < 8) {
      return 'New password must be at least 8 characters.';
    }
    if (password.isNotEmpty && password != confirmPassword) {
      return 'New password confirmation does not match.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _formError = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final response = await widget.authService.updateManagedAccount(
        id: (widget.user['id'] as num).toInt(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _phoneController.text.trim(),
        role: _role,
        department: _isCitizen ? null : _department,
        jobTitle: _isCitizen ? null : _jobTitleController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        passwordConfirmation: _confirmPasswordController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Account updated successfully.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final offices = _offices
        .map((office) => (office['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: colors.panel,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Edit Account',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded),
                        color: colors.text,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_formError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        _formError!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _textField(
                    _nameController,
                    'Full Name',
                    Icons.person_outline,
                  ),
                  _textField(
                    _emailController,
                    'Email Address',
                    Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _textField(
                    _phoneController,
                    'Mobile Number',
                    Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                  ),
                  _dropdown(
                    label: 'Account Role',
                    icon: Icons.manage_accounts_outlined,
                    value: _role,
                    items: _roleOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.$1,
                            child: Text(option.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _role = value;
                        if (_isCitizen) {
                          _department = null;
                        }
                      });
                    },
                  ),
                  if (!_isCitizen)
                    _dropdown(
                      label: _loadingOffices
                          ? 'Loading Departments...'
                          : 'Department',
                      icon: Icons.apartment_rounded,
                      value: offices.contains(_department)
                          ? _department
                          : (offices.isEmpty ? null : offices.first),
                      items: offices
                          .map(
                            (office) => DropdownMenuItem(
                              value: office,
                              child: Text(office),
                            ),
                          )
                          .toList(),
                      onChanged: _loadingOffices
                          ? null
                          : (value) => setState(() => _department = value),
                    ),
                  if (!_isCitizen)
                    _dropdown(
                      label: 'Job Role',
                      icon: Icons.badge_outlined,
                      value: _jobRoles.contains(_jobTitleController.text)
                          ? _jobTitleController.text
                          : _jobRoles.first,
                      items: _jobRoles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _jobTitleController.text = value);
                      },
                    ),
                  _textField(
                    _passwordController,
                    'New Password (optional)',
                    Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  _textField(
                    _confirmPasswordController,
                    'Confirm New Password',
                    Icons.lock_reset_rounded,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.text,
                            side: BorderSide(color: colors.border),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              (_saving || (!_isCitizen && _loadingOffices))
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_saving ? 'Saving...' : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        inputFormatters: inputFormatters,
        style: TextStyle(color: AdminThemeColors.of(context).text),
        decoration: _decoration(label, icon, suffixIcon),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
  }) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: colors.panel,
        style: TextStyle(color: colors.text),
        decoration: _decoration(label, icon, null),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, Widget? suffixIcon) {
    final colors = AdminThemeColors.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.mutedText),
      prefixIcon: Icon(icon, color: colors.mutedText, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.input,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }
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

  bool get isArchived {
    final deletedAt = user['deleted_at'];
    return deletedAt != null && deletedAt.toString().trim().isNotEmpty;
  }

  String get jobTitle {
    if (role == 'super_admin') return 'Administrator';
    final value = (user['job_title'] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
    if (role == 'citizen') return 'Citizen Account';
    return 'Administrator';
  }

  String get initials {
    final name = (user['name'] ?? '').toString().trim();
    if (name.isEmpty) return 'ST';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
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
      case 'citizen account':
        return const Color(0xFF38BDF8);
      case 'administrator':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFFB77CFF);
    }
  }

  bool get isAvailable =>
      !isArchived &&
      activeAssignments.isEmpty &&
      user['is_active'] != false &&
      role != 'pending_admin';

  String get assignedSummary {
    if (isArchived) return 'Archived account';
    if (role == 'super_admin') return 'Protected account';
    if (role == 'citizen') return 'Citizen profile';
    if (activeAssignments.isEmpty) return 'No active reports';
    final count = activeAssignments.length;
    return count == 1 ? '1 active report' : '$count active reports';
  }

  String get assignmentSubline {
    if (isArchived) return 'Reactivate or permanently delete';
    if (role == 'super_admin') return 'Only one system owner';
    if (role == 'citizen') return 'Can submit and track reports';
    if (latestAssignment == null) return 'Ready for assignment';
    final title = (latestAssignment!['title'] ?? '').toString().trim();
    return title.isEmpty ? '1 recent assigned' : title;
  }

  String get statusLabel {
    if (isArchived) return 'Archived';
    if (user['is_active'] == false) return 'Deactivated';
    if (role == 'super_admin') return 'Protected';
    if (role == 'pending_admin') return 'Pending verification';
    if (role == 'citizen') return 'Citizen access';
    if (activeAssignments.isNotEmpty) return 'Out in the field';
    return 'Available';
  }

  String get officeStatusLabel {
    if (isArchived) return 'Archived';
    if (user['is_active'] == false) return 'Offline';
    if (role == 'super_admin') return 'Cannot modify';
    if (role == 'pending_admin') return 'Pending approval';
    if (role == 'citizen') return 'Active profile';
    return activeAssignments.isNotEmpty ? 'Out in the field' : 'Available';
  }

  String get statusSubline {
    if (isArchived) return 'Hidden from login, retained for review';
    if (user['is_active'] == false) return 'Account access removed';
    if (role == 'super_admin') return 'Deletion and deactivation disabled';
    if (role == 'pending_admin') return 'Waiting for Super Admin approval';
    if (role == 'citizen') return 'Citizen can use the mobile app';
    if (latestAssignment == null) return 'Ready for assignment';

    final title = (latestAssignment!['title'] ?? 'Recent assignment')
        .toString();
    final updatedAt = DateTime.tryParse(
      (latestAssignment!['updated_at'] ?? latestAssignment!['created_at'] ?? '')
          .toString(),
    );
    return '$title - ${_timeAgo(updatedAt)}';
  }

  Color get statusColor {
    if (isArchived) return const Color(0xFFF87171);
    if (user['is_active'] == false) return const Color(0xFFF87171);
    if (role == 'super_admin') return const Color(0xFFF97316);
    if (role == 'pending_admin') return const Color(0xFFFBBF24);
    if (role == 'citizen') return const Color(0xFF38BDF8);
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
