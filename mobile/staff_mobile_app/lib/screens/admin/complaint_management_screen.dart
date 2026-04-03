import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
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
    final results = await Future.wait<dynamic>([
      _reportService.getAdminReports(),
      _authService.getCurrentUser(),
    ]);
    return _ReportsPayload(
      reports: (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      user: Map<String, dynamic>.from(results[1] as Map),
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
      final statusParam =
          _selectedStatus == 'All Status' ? null : _selectedStatus;
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

  DateTime? _createdAt(Map<String, dynamic> report) =>
      DateTime.tryParse((report['created_at'] ?? '').toString())?.toLocal();

  List<String> _options(List<String> items, String allLabel) {
    final values = items.where((item) => item.trim().isNotEmpty).toSet().toList()
      ..sort();
    return [allLabel, ...values];
  }

  List<Map<String, dynamic>> _filteredReports(List<Map<String, dynamic>> reports) {
    return reports.where((report) {
      if (_selectedCategory != 'All Categories' &&
          _category(report) != _selectedCategory) {
        return false;
      }
      if (_selectedOffice != 'All Departments' && _office(report) != _selectedOffice) {
        return false;
      }
      if (_selectedBarangay != 'All Barangays' &&
          _barangay(report) != _selectedBarangay) {
        return false;
      }
      if (_selectedStatus != 'All Status' && _status(report) != _selectedStatus) {
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
                    value: selectedStatus,
                    dropdownColor: const Color(0xFF181C2E),
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogDecoration('Status'),
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                        value: 'In Progress',
                        child: Text('In Progress'),
                      ),
                      DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.75)),
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
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.70)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
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
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1B),
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0B0E1B),
              foregroundColor: Colors.white,
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
                        snapshot.error.toString().replaceFirst('Exception: ', ''),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              }

              final payload = snapshot.data!;
              final reports = payload.reports;
              final categories =
                  _options(reports.map(_category).toList(), 'All Categories');
              final offices =
                  _options(reports.map(_office).toList(), 'All Departments');
              final barangays =
                  _options(reports.map(_barangay).toList(), 'All Barangays');
              const statuses = ['All Status', 'New', 'Pending', 'In Progress', 'Resolved', 'Rejected'];
              if (!categories.contains(_selectedCategory)) {
                _selectedCategory = categories.first;
              }
              if (!offices.contains(_selectedOffice)) {
                _selectedOffice = offices.first;
              }
              if (!barangays.contains(_selectedBarangay)) {
                _selectedBarangay = barangays.first;
              }
              if (!statuses.contains(_selectedStatus)) {
                _selectedStatus = statuses.first;
              }
              final filtered = _filteredReports(reports);
              final isWide = MediaQuery.of(context).size.width >= 1180;

              final content = [
                const Text(
                  'All Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'View and manage all issue reports from across the city.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                _panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _searchField(),
                          ),
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
                              setState(() => _selectedOffice = value);
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
                                : const Icon(Icons.file_download_outlined, size: 16),
                            label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${filtered.length} Reports${_selectedOffice != 'All Departments' ? ' • $_selectedOffice' : _selectedBarangay != 'All Barangays' ? ' • $_selectedBarangay' : ''}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _tableHeader(),
                      const SizedBox(height: 6),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No reports match your current filters.',
                            style: TextStyle(color: Colors.white.withOpacity(0.62)),
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
                              color: Colors.white.withOpacity(0.50),
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
                children: [
                  if (isWide)
                    ...content
                  else
                    ...content,
                ],
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
          color: const Color(0xFF111426),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: child,
      );

  Widget _searchField() => TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          hintText: 'Search by report ID, category, or barangay',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.42)),
          filled: true,
          fillColor: const Color(0xFF181C2E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
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
        value: items.contains(value) ? value : items.first,
        dropdownColor: const Color(0xFF181C2E),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF181C2E),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        iconEnabledColor: Colors.white70,
        style: const TextStyle(color: Colors.white),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _tableHeader() => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
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

  Widget _reportRow(Map<String, dynamic> report) {
    final idLabel = 'CTR-${(report['id'] ?? 0).toString().padLeft(4, '0')}';
    final category = _category(report);
    final status = _status(report);
    final statusColor = _statusColor(status);
    final categoryColor = _categoryColor(category);
    final createdAt = _createdAt(report);
    final assignee = _assignee(report);
    final assigneeInitial = assignee.isEmpty ? 'U' : assignee.substring(0, 1).toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(reportId: report['id'] as int),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
          ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (report['title'] ?? idLabel).toString(),
                    style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 12),
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
                      color: categoryColor.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.category_rounded, color: categoryColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                _office(report),
                style: TextStyle(color: Colors.white.withOpacity(0.74)),
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
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _location(report),
                    style: TextStyle(color: Colors.white.withOpacity(0.46), fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _timeAgo(createdAt),
                style: TextStyle(color: Colors.white.withOpacity(0.72)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _openStatusDialog(report),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
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
                    child: Text(
                      assignee,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagerButton(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF181C2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12),
        ),
      );

  Widget _pagerIndex(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3356),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      );
}

class _ReportsPayload {
  const _ReportsPayload({
    required this.reports,
    required this.user,
  });

  final List<Map<String, dynamic>> reports;
  final Map<String, dynamic> user;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.48),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
