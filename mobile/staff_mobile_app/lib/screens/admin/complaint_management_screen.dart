import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/department_issue_types.dart';
import '../../utils/file_download.dart';
import '../citizen/complaint_detail_screen.dart';

class ComplaintManagementScreen extends StatefulWidget {
  const ComplaintManagementScreen({
    super.key,
    this.embedded = false,
    this.initialOfficeName,
  });

  final bool embedded;
  final String? initialOfficeName;

  @override
  State<ComplaintManagementScreen> createState() =>
      _ComplaintManagementScreenState();
}

class _ComplaintManagementScreenState extends State<ComplaintManagementScreen> {
  static const List<String> _taclobanBarangays = [
    'Barangay 1 (Libertad)',
    'Barangay 2 (Jones)',
    'Barangay 3 (Upper Nulatula)',
    'Barangay 4 (Libertad)',
    'Barangay 5 (T. Claudio)',
    'Barangay 5-A (T. Claudio)',
    'Barangay 6',
    'Barangay 6-A (Sto. Nino)',
    'Barangay 7',
    'Barangay 8 (T. Claudio)',
    'Barangay 8-A',
    'Barangay 12 (GE Palanog)',
    'Barangay 13 (Salazar/J. Romualdez)',
    'Barangay 14',
    'Barangay 15',
    'Barangay 16',
    'Barangay 17',
    'Barangay 18',
    'Barangay 19',
    'Barangay 20',
    'Barangay 21 (P. Burgos)',
    'Barangay 22',
    'Barangay 23',
    'Barangay 23-A',
    'Barangay 24',
    'Barangay 25',
    'Barangay 26 (P. Gomez)',
    'Barangay 27',
    'Barangay 28',
    'Barangay 29 (P. Gomez)',
    'Barangay 30 (Burgos)',
    'Barangay 31',
    'Barangay 32',
    'Barangay 33',
    'Barangay 34 (Real)',
    'Barangay 35',
    'Barangay 35-A',
    'Barangay 36 (Sabang)',
    'Barangay 36-A (Sabang)',
    'Barangay 37 (Sea Wall)',
    'Barangay 37-A (G.E. Palanog Gawad Kalinga Village)',
    'Barangay 38 (Calvary Hill)',
    'Barangay 39 (Calvary Hill)',
    'Barangay 40 (Calvary Hill)',
    'Barangay 41 (Calvary Hill)',
    'Barangay 42',
    'Barangay 42-A (Quarry)',
    'Barangay 42-B (Quarry)',
    'Barangay 43',
    'Barangay 43-A (Quarry)',
    'Barangay 43-B (Quarry)',
    'Barangay 44',
    'Barangay 44-A (Quarry)',
    'Barangay 44-B (Quarry)',
    'Barangay 45',
    'Barangay 46 (Imelda/Juan Luna)',
    'Barangay 47',
    'Barangay 48',
    'Barangay 48-A',
    'Barangay 48-B',
    'Barangay 49 (Youngfield)',
    'Barangay 50 (Youngfield)',
    'Barangay 50-A (Youngfield)',
    'Barangay 50-B (Youngfield)',
    'Barangay 51',
    'Barangay 51-A',
    'Barangay 52 (Lucban Magallanes)',
    'Barangay 53 (Magallanes)',
    'Barangay 54 (Magallanes)',
    'Barangay 54-A (Magallanes)',
    'Barangay 55 (El Reposo)',
    'Barangay 56 (El Reposo)',
    'Barangay 56-A (El Reposo)',
    'Barangay 57 (Whitelane Sampaguita)',
    'Barangay 58',
    'Barangay 59 (Sagkahan Picas)',
    'Barangay 59-A (Sampaguita)',
    'Barangay 59-B (Sampaguita)',
    'Barangay 59-E (Sagkahan Picas)',
    'Barangay 60 (Sagkahan Aslum)',
    'Barangay 60-A (Sagkahan)',
    'Barangay 61 (Sagkahan)',
    'Barangay 62 (Sagkahan Saging)',
    'Barangay 62-A (Sagkahan Ilong)',
    'Barangay 62-B (Sagkahan Picas)',
    'Barangay 63 (Sagkahan Mangga)',
    'Barangay 64 (Sagkahan Bliss)',
    'Barangay 65 (Paseo de Legaspi)',
    'Barangay 66 (Anibong)',
    'Barangay 66-A (Anibong)',
    'Barangay 67 (Anibong)',
    'Barangay 68 (Anibong)',
    'Barangay 69 (Anibong, Happy Land)',
    'Barangay 70 (Anibong, Rawis)',
    'Barangay 71 (Naga-naga)',
    'Barangay 72 (PHHC Seaside)',
    'Barangay 73 (PHHC Mountainside)',
    'Barangay 74 (Lower Nula-Tula)',
    'Barangay 75 (Fatima Village)',
    'Barangay 76 (Fatima Village)',
    'Barangay 77 (Fatima Village)',
    'Barangay 78 (Marasbaras)',
    'Barangay 79 (Marasbaras)',
    'Barangay 80 (Marasbaras)',
    'Barangay 81 (Marasbaras)',
    'Barangay 82 (Marasbaras)',
    'Barangay 83 (Paraiso)',
    'Barangay 83-A (Burayan)',
    'Barangay 83-B (San Jose, Cogon)',
    'Barangay 83-C (San Jose)',
    'Barangay 84 (San Jose)',
    'Barangay 85 (San Jose)',
    'Barangay 86 (San Jose)',
    'Barangay 87 (San Jose)',
    'Barangay 88 (San Jose)',
    'Barangay 89 (San Jose, Baybay)',
    'Barangay 90 (San Jose)',
    'Barangay 91 (Abucay)',
    'Barangay 92 (Apitong)',
    'Barangay 93 (Bagacay)',
    'Barangay 94 (Tigbao)',
    'Barangay 94-A (Basper)',
    'Barangay 95 (Caibaan)',
    'Barangay 95-A (Caibaan)',
    'Barangay 96 (Calanipawan)',
    'Barangay 97 (Cabalawan)',
    'Barangay 98 (Camansihay)',
    'Barangay 99 (Diit)',
    'Barangay 100 (San Roque)',
    'Barangay 101 (New Kawayan)',
    'Barangay 102 (Kawayan)',
    'Barangay 103 (Palanog)',
    'Barangay 103-A (San Paglaum)',
    'Barangay 104 (Salvacion)',
    'Barangay 105 (Suhi)',
    'Barangay 106 (Santo Nino)',
    'Barangay 107 (Santa Elena)',
    'Barangay 108 (Tagapuro)',
    'Barangay 109 (V&G Subdivision)',
    'Barangay 109-A (V&G Subdivision)',
    'Barangay 110 (Utap)',
  ];

  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  late Future<_ReportsPayload> _payloadFuture;
  bool _exporting = false;
  String _search = '';
  String _selectedCategory = 'All Categories';
  String _selectedBarangay = 'All Barangays';
  String _selectedStatus = 'All Status';
  String _selectedOffice = 'All Departments';

  @override
  void initState() {
    super.initState();
    _payloadFuture = _loadPayload();
    _selectedOffice = widget.initialOfficeName?.trim().isNotEmpty == true
        ? widget.initialOfficeName!.trim()
        : 'All Departments';
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ReportsPayload> _loadPayload() async {
    final user = await _authService.getCurrentUser();
    final isSuperAdmin = _isSuperAdmin(user);
    final results = await Future.wait<dynamic>([
      _reportService.getAdminReports(),
      _reportService.getCategories(),
      _authService.getOffices(includeInactive: isSuperAdmin),
    ]);
    return _ReportsPayload(
      reports: (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      user: Map<String, dynamic>.from(user),
      categories: results[1] as List<dynamic>,
      offices: results[2] as List<dynamic>,
    );
  }

  Future<void> _refresh() async {
    final future = _loadPayload();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _exportReports() async {
    setState(() => _exporting = true);
    try {
      final statusParam = _selectedStatus == 'All Status'
          ? null
          : _selectedStatus;
      final file = await _reportService.exportAdminReports(status: statusParam);
      await downloadFile(
        bytes: file.bytes,
        fileName: file.fileName,
        mimeType: file.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${file.fileName} successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _category(Map<String, dynamic> report) {
    final categoryName = (report['category_name'] ?? '').toString().trim();
    if (categoryName.isNotEmpty) return categoryName;

    final category = report['category'];
    if (category is Map<String, dynamic>) {
      final name = (category['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Other';
  }

  String _barangay(Map<String, dynamic> report) =>
      (report['barangay'] ?? '').toString().trim();

  String _status(Map<String, dynamic> report) =>
      (report['status'] ?? 'New').toString();

  String _location(Map<String, dynamic> report) =>
      (report['location'] ?? 'Tacloban City').toString().trim();

  String _assignee(Map<String, dynamic> report) {
    final assigned = report['assigned_admin'];
    if (assigned is Map<String, dynamic>) {
      final name = (assigned['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Unassigned';
  }

  String _office(Map<String, dynamic> report) {
    final office = report['office'];
    if (office is Map<String, dynamic>) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Unassigned office';
  }

  bool _isSuperAdmin(Map<String, dynamic> user) =>
      (user['role'] ?? '').toString().trim() == 'super_admin';

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }

    return (user['department'] ?? '').toString().trim();
  }

  DateTime? _createdAt(Map<String, dynamic> report) =>
      DateTime.tryParse((report['created_at'] ?? '').toString())?.toLocal();

  List<String> _options(
    Iterable<String> items,
    String allLabel, {
    int Function(String, String)? compare,
  }) {
    final values = <String, String>{};
    for (final item in items) {
      final value = item.trim();
      if (value.isEmpty) continue;
      values.putIfAbsent(value.toLowerCase(), () => value);
    }

    final sortedValues = values.values.toList()
      ..sort(compare ?? (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [allLabel, ...sortedValues];
  }

  List<String> _categoryOptions(_ReportsPayload payload) {
    final selectedDepartments = _selectedOffice == 'All Departments'
        ? [
            ...payload.offices.whereType<Map<String, dynamic>>().map(
              (office) => (office['name'] ?? '').toString(),
            ),
            ...payload.reports.map(_office),
          ]
        : [_selectedOffice];
    final mappedIssueTypes = issueTypesForDepartments(selectedDepartments);
    final scopedReportCategories = payload.reports
        .where((report) {
          if (_selectedOffice == 'All Departments') return true;
          return _office(report).toLowerCase() == _selectedOffice.toLowerCase();
        })
        .map(_category);

    return _options([
      ...mappedIssueTypes,
      ...scopedReportCategories,
      if (mappedIssueTypes.isEmpty)
        ...payload.categories.whereType<Map<String, dynamic>>().map(
          (category) => (category['name'] ?? '').toString(),
        ),
    ], 'All Categories');
  }

  List<String> _departmentOptions(_ReportsPayload payload) {
    if (!_isSuperAdmin(payload.user)) {
      final department = _departmentLabel(payload.user);
      return department.isEmpty ? ['Assigned Department'] : [department];
    }

    final officeNames = payload.offices.whereType<Map<String, dynamic>>().map(
      (office) => (office['name'] ?? '').toString(),
    );
    final reportOffices = payload.reports
        .map(_office)
        .where(
          (office) => office.trim().isNotEmpty && office != 'Unassigned office',
        );

    return _options([...officeNames, ...reportOffices], 'All Departments');
  }

  List<String> _barangayOptions(_ReportsPayload payload) {
    return _options(
      [..._taclobanBarangays, ...payload.reports.map(_barangay)],
      'All Barangays',
      compare: _compareBarangays,
    );
  }

  int _compareBarangays(String a, String b) {
    final aNumber = _barangayNumber(a);
    final bNumber = _barangayNumber(b);
    if (aNumber != null && bNumber != null && aNumber != bNumber) {
      return aNumber.compareTo(bNumber);
    }
    if (aNumber != null && bNumber == null) return -1;
    if (aNumber == null && bNumber != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  double? _barangayNumber(String value) {
    final match = RegExp(
      r'^barangay\s+(\d+)(?:-([a-z]))?',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final number = double.tryParse(match.group(1)!);
    if (number == null) return null;
    final suffix = match.group(2);
    if (suffix == null) return number;
    return number + ((suffix.toLowerCase().codeUnitAt(0) - 96) / 10);
  }

  List<Map<String, dynamic>> _filteredReports(
    _ReportsPayload payload,
    List<Map<String, dynamic>> reports,
  ) {
    final isSuperAdmin = _isSuperAdmin(payload.user);
    final assignedDepartment = _departmentLabel(payload.user);
    return reports.where((report) {
      if (!isSuperAdmin &&
          assignedDepartment.isNotEmpty &&
          _office(report) != assignedDepartment) {
        return false;
      }
      if (_selectedCategory != 'All Categories' &&
          normalizeIssueTypeKey(_category(report)) !=
              normalizeIssueTypeKey(_selectedCategory)) {
        return false;
      }
      if (_selectedOffice != 'All Departments' &&
          _office(report).toLowerCase() != _selectedOffice.toLowerCase()) {
        return false;
      }
      if (_selectedBarangay != 'All Barangays' &&
          _barangay(report) != _selectedBarangay) {
        return false;
      }
      if (_selectedStatus != 'All Status' &&
          _status(report) != _selectedStatus) {
        return false;
      }
      if (_search.isEmpty) return true;
      final reportId = 'CTR-${(report['id'] ?? 0).toString().padLeft(4, '0')}';
      return [
        reportId,
        _category(report),
        _barangay(report),
        _location(report),
        (report['title'] ?? '').toString(),
      ].any((value) => value.toLowerCase().contains(_search));
    }).toList();
  }

  Future<void> _openStatusDialog(Map<String, dynamic> report) async {
    String selectedStatus = _status(report);
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF181C2E),
              title: const Text(
                'Update Report Status',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    dropdownColor: const Color(0xFF181C2E),
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogDecoration('Status'),
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New')),
                      DropdownMenuItem(
                        value: 'Pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'In Progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(
                        value: 'Resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogDecoration('Remarks (optional)'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2557D6),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      remarksController.dispose();
      return;
    }

    try {
      await _reportService.updateReportStatus(
        reportId: report['id'] as int,
        status: selectedStatus,
        remarks: remarksController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report status updated successfully.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      remarksController.dispose();
    }
  }

  InputDecoration _dialogDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFF2557D6)),
    ),
  );

  String _timeAgo(DateTime? date) {
    if (date == null) return '-';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF68D9A2);
      case 'In Progress':
        return const Color(0xFFF0B34C);
      case 'Rejected':
        return const Color(0xFFE6616D);
      case 'Pending':
        return const Color(0xFFD5A650);
      default:
        return const Color(0xFF6E78AA);
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Water':
        return const Color(0xFF5B9DFF);
      case 'Roads':
      case 'Streetlight':
        return const Color(0xFFD39A4C);
      case 'Electrical':
        return const Color(0xFF8C7DFF);
      case 'Fire Hazard':
        return const Color(0xFFE37A56);
      case 'Garbage':
        return const Color(0xFF73B38E);
      case 'Flooding':
        return const Color(0xFF4B7AE7);
      default:
        return const Color(0xFF7B7FB4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: colors.background,
              foregroundColor: colors.text,
              elevation: 0,
              title: const Text('All Reports'),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_ReportsPayload>(
            future: _payloadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _panel(
                      child: Text(
                        snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        style: TextStyle(color: colors.text),
                      ),
                    ),
                  ],
                );
              }

              final payload = snapshot.data!;
              final superAdmin = _isSuperAdmin(payload.user);
              final reports = payload.reports;
              final offices = _departmentOptions(payload);
              if (!offices.contains(_selectedOffice)) {
                _selectedOffice = offices.first;
              }
              final categories = _categoryOptions(payload);
              final barangays = _barangayOptions(payload);
              const statuses = [
                'All Status',
                'New',
                'Pending',
                'In Progress',
                'Resolved',
                'Rejected',
              ];
              if (!categories.contains(_selectedCategory)) {
                _selectedCategory = categories.first;
              }
              if (!barangays.contains(_selectedBarangay)) {
                _selectedBarangay = barangays.first;
              }
              if (!statuses.contains(_selectedStatus)) {
                _selectedStatus = statuses.first;
              }
              final filtered = _filteredReports(payload, reports);
              final isWide = MediaQuery.of(context).size.width >= 1180;

              final content = [
                Text(
                  'All Reports',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  superAdmin
                      ? 'View and manage all issue reports from across the city.'
                      : 'View and manage reports assigned to your department.',
                  style: TextStyle(color: colors.mutedText, fontSize: 13),
                ),
                const SizedBox(height: 18),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _searchField()),
                          const SizedBox(width: 12),
                          _filterDropdown(
                            value: _selectedCategory,
                            items: categories,
                            width: 180,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedCategory = value);
                            },
                          ),
                          const SizedBox(width: 12),
                          _filterDropdown(
                            value: _selectedOffice,
                            items: offices,
                            width: 210,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedOffice = value;
                                _selectedCategory = 'All Categories';
                              });
                            },
                          ),
                          const SizedBox(width: 12),
                          _filterDropdown(
                            value: _selectedBarangay,
                            items: barangays,
                            width: 180,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedBarangay = value);
                            },
                          ),
                          const SizedBox(width: 12),
                          _filterDropdown(
                            value: _selectedStatus,
                            items: statuses,
                            width: 160,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedStatus = value);
                            },
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _exporting ? null : _exportReports,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2557D6),
                            ),
                            icon: _exporting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.file_download_outlined,
                                    size: 16,
                                  ),
                            label: Text(
                              _exporting ? 'Exporting...' : 'Export Excel',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${filtered.length} Reports${_selectedOffice != 'All Departments'
                            ? ' - $_selectedOffice'
                            : _selectedBarangay != 'All Barangays'
                            ? ' - $_selectedBarangay'
                            : ''}',
                        style: TextStyle(color: colors.mutedText, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _tableHeader(),
                      const SizedBox(height: 6),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No reports match your current filters.',
                            style: TextStyle(color: colors.mutedText),
                          ),
                        )
                      else
                        ...filtered.map((report) => _reportRow(report)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Showing ${filtered.isEmpty ? 0 : 1} to ${filtered.length} of ${reports.length} entries',
                            style: TextStyle(
                              color: colors.mutedText,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          _pagerButton('Previous'),
                          const SizedBox(width: 8),
                          _pagerIndex('1'),
                          const SizedBox(width: 8),
                          _pagerButton('Next'),
                        ],
                      ),
                    ],
                  ),
                ),
              ];

              return ListView(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomSafeArea),
                children: [if (isWide) ...content else ...content],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AdminThemeColors.of(context).panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AdminThemeColors.of(context).border),
    ),
    child: child,
  );

  Widget _searchField() => TextField(
    controller: _searchController,
    style: TextStyle(color: AdminThemeColors.of(context).text),
    decoration: InputDecoration(
      prefixIcon: Icon(
        Icons.search_rounded,
        color: AdminThemeColors.of(context).mutedText,
      ),
      hintText: 'Search by report ID, category, or barangay',
      hintStyle: TextStyle(color: AdminThemeColors.of(context).mutedText),
      filled: true,
      fillColor: AdminThemeColors.of(context).input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AdminThemeColors.of(context).border),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AdminThemeColors.of(context).border),
      ),
    ),
  );

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        isExpanded: true,
        menuMaxHeight: 360,
        dropdownColor: AdminThemeColors.of(context).panel,
        decoration: InputDecoration(
          filled: true,
          fillColor: AdminThemeColors.of(context).input,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AdminThemeColors.of(context).border),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AdminThemeColors.of(context).border),
          ),
        ),
        iconEnabledColor: AdminThemeColors.of(context).mutedText,
        style: TextStyle(color: AdminThemeColors.of(context).text),
        selectedItemBuilder: (context) => items
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AdminThemeColors.of(context).text),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AdminThemeColors.of(context).text),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _tableHeader() {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: const Row(
        children: [
          _HeaderCell('ID', flex: 3),
          _HeaderCell('Category', flex: 4),
          _HeaderCell('Department', flex: 4),
          _HeaderCell('Barangay', flex: 3),
          _HeaderCell('Reported', flex: 3),
          _HeaderCell('Status', flex: 2),
          _HeaderCell('Assigned To', flex: 3),
        ],
      ),
    );
  }

  Widget _reportRow(Map<String, dynamic> report) {
    final colors = AdminThemeColors.of(context);
    final idLabel = 'CTR-${(report['id'] ?? 0).toString().padLeft(4, '0')}';
    final category = _category(report);
    final status = _status(report);
    final statusColor = _statusColor(status);
    final categoryColor = _categoryColor(category);
    final createdAt = _createdAt(report);
    final assignee = _assignee(report);
    final assigneeInitial = assignee.isEmpty
        ? 'U'
        : assignee.substring(0, 1).toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ComplaintDetailScreen(reportId: report['id'] as int),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    idLabel,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (report['title'] ?? idLabel).toString(),
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.category_rounded,
                      color: categoryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                _office(report),
                style: TextStyle(color: colors.mutedText),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _barangay(report).isEmpty ? '-' : _barangay(report),
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _location(report),
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _timeAgo(createdAt),
                style: TextStyle(color: colors.mutedText),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _openStatusDialog(report),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFF324C8A),
                    child: Text(
                      assigneeInitial,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(assignee, style: TextStyle(color: colors.text)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagerButton(String label) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.mutedText, fontSize: 12),
      ),
    );
  }

  Widget _pagerIndex(String label) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.activeNav,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.activeText, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReportsPayload {
  const _ReportsPayload({
    required this.reports,
    required this.user,
    required this.categories,
    required this.offices,
  });

  final List<Map<String, dynamic>> reports;
  final Map<String, dynamic> user;
  final List<dynamic> categories;
  final List<dynamic> offices;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
