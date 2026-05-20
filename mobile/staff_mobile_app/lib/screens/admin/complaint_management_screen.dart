import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/file_download.dart';
import 'report_detail_dialog.dart';

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
  static const int _pageSize = 25;

  _ReportListContext? _contextCache;
  late Future<_ReportsPayload> _payloadFuture;
  _ReportsPayload? _resolvedPayload;
  Timer? _searchDebounce;
  int _requestVersion = 0;
  bool _exporting = false;
  String _search = '';
  String _selectedCategory = 'All Categories';
  String _selectedBarangay = 'All Barangays';
  String _selectedStatus = 'All Status';
  String _selectedOffice = 'All Departments';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _selectedOffice = widget.initialOfficeName?.trim().isNotEmpty == true
        ? widget.initialOfficeName!.trim()
        : 'All Departments';
    _payloadFuture = _queueLoad(refreshContext: true);
    _searchController.addListener(() {
      final nextSearch = _searchController.text.trim();
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || nextSearch == _search) {
          return;
        }

        setState(() {
          _search = nextSearch;
          _page = 1;
          _payloadFuture = _queueLoad();
        });
      });
    });
  }

  Future<_ReportsPayload> _queueLoad({bool refreshContext = false}) {
    final requestId = ++_requestVersion;
    return _loadPayload(refreshContext: refreshContext, requestId: requestId);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<_ReportListContext> _loadContext({bool refresh = false}) async {
    if (!refresh && _contextCache != null) {
      return _contextCache!;
    }

    final user = await _authService.getCurrentUser();
    final isSuperAdmin = _isSuperAdmin(user);
    final results = await Future.wait<dynamic>([
      _reportService.getCategories(),
      _authService.getOffices(includeInactive: isSuperAdmin),
    ]);

    final context = _ReportListContext(
      user: Map<String, dynamic>.from(user),
      categories: (results[0] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      offices: (results[1] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
    );
    _contextCache = context;
    return context;
  }

  Future<_ReportsPayload> _loadPayload({
    bool refreshContext = false,
    required int requestId,
  }) async {
    final context = await _loadContext(refresh: refreshContext);
    var pageData = await _reportService.getAdminReportsPage(
      page: _page,
      perPage: _pageSize,
      search: _search,
      status: _selectedStatus == 'All Status' ? null : _selectedStatus,
      category: _selectedCategory == 'All Categories'
          ? null
          : _selectedCategory,
      barangay: _selectedBarangay == 'All Barangays' ? null : _selectedBarangay,
      office: _selectedOffice == 'All Departments' ? null : _selectedOffice,
    );

    if (pageData.reports.isEmpty && pageData.total > 0 && _page > 1) {
      _page = pageData.lastPage;
      pageData = await _reportService.getAdminReportsPage(
        page: _page,
        perPage: _pageSize,
        search: _search,
        status: _selectedStatus == 'All Status' ? null : _selectedStatus,
        category: _selectedCategory == 'All Categories'
            ? null
            : _selectedCategory,
        barangay: _selectedBarangay == 'All Barangays'
            ? null
            : _selectedBarangay,
        office: _selectedOffice == 'All Departments' ? null : _selectedOffice,
      );
    }

    final payload = _ReportsPayload(context: context, page: pageData);
    if (requestId == _requestVersion) {
      _resolvedPayload = payload;
      _page = pageData.currentPage;
    }

    return payload;
  }

  Future<void> _refresh() async {
    final future = _queueLoad(refreshContext: true);
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page == _page) {
      return;
    }

    setState(() {
      _page = page;
      _payloadFuture = _queueLoad();
    });
    await _payloadFuture;
  }

  Future<void> _exportReports() async {
    setState(() => _exporting = true);
    try {
      final file = await _reportService.exportAdminReports(
        search: _searchController.text.trim(),
        status: _selectedStatus == 'All Status' ? null : _selectedStatus,
        category: _selectedCategory == 'All Categories'
            ? null
            : _selectedCategory,
        barangay: _selectedBarangay == 'All Barangays'
            ? null
            : _selectedBarangay,
        office: _selectedOffice == 'All Departments' ? null : _selectedOffice,
      );
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
    final availableCategories = payload.page.availableFilters.categories;

    return _options([
      if (_selectedCategory != 'All Categories') _selectedCategory,
      ...availableCategories,
      if (availableCategories.isEmpty)
        ...payload.context.categories.map(
          (category) => (category['name'] ?? '').toString(),
        ),
    ], 'All Categories');
  }

  List<String> _departmentOptions(_ReportsPayload payload) {
    if (!_isSuperAdmin(payload.context.user)) {
      final department = _departmentLabel(payload.context.user);
      return department.isEmpty ? ['Assigned Department'] : [department];
    }

    final availableOffices = payload.page.availableFilters.offices;

    return _options([
      if (_selectedOffice != 'All Departments') _selectedOffice,
      ...availableOffices,
      if (availableOffices.isEmpty)
        ...payload.context.offices.map((office) => (office['name'] ?? '').toString()),
    ], 'All Departments');
  }

  List<String> _barangayOptions(_ReportsPayload payload) {
    return _options(
      [
        if (_selectedBarangay != 'All Barangays') _selectedBarangay,
        ...payload.page.availableFilters.barangays,
      ],
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

  Future<bool> _openStatusDialog(Map<String, dynamic> report) async {
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
      return false;
    }

    try {
      await _reportService.updateReportStatus(
        reportId: report['id'] as int,
        status: selectedStatus,
        remarks: remarksController.text,
      );
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report status updated successfully.')),
      );
      await _refresh();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return false;
    } finally {
      remarksController.dispose();
    }
  }

  Future<void> _openReportDetails(Map<String, dynamic> report) async {
    final reportId = report['id'] is int
        ? report['id'] as int
        : int.tryParse('${report['id']}');
    if (reportId == null) {
      return;
    }

    await showAdminReportDetailDialog(
      context: context,
      reportId: reportId,
      onUpdateStatus: _openStatusDialog,
    );
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
    final body = SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ReportsPayload>(
          initialData: _resolvedPayload,
          future: _payloadFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState != ConnectionState.done;
            final payload = snapshot.data ?? _resolvedPayload;

            if (isLoading && payload == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && payload == null) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _panel(
                    child: Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: colors.text),
                    ),
                  ),
                ],
              );
            }

            if (payload == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final contextData = payload.context;
            final pageData = payload.page;
            final superAdmin = _isSuperAdmin(contextData.user);
            final reports = pageData.reports;
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
            final isWide = MediaQuery.of(context).size.width >= 1180;
            final rangeLabel = _selectedOffice != 'All Departments'
                ? ' - $_selectedOffice'
                : _selectedBarangay != 'All Barangays'
                ? ' - $_selectedBarangay'
                : '';
            final exportDisabled = _exporting || isLoading;

            final content = [
              if (isLoading) ...[
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF2557D6),
                ),
                const SizedBox(height: 14),
              ],
              if (snapshot.hasError) ...[
                _panel(
                  child: Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(color: colors.text),
                  ),
                ),
                const SizedBox(height: 14),
              ],
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useStackedToolbar = constraints.maxWidth < 1320;
                        final filters = LayoutBuilder(
                          builder: (context, filterConstraints) {
                            final useInlineFilters =
                                filterConstraints.maxWidth >= 760;
                            final categoryFilter = _filterDropdown(
                              value: _selectedCategory,
                              items: categories,
                              width: 180,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedCategory = value;
                                  _page = 1;
                                  _payloadFuture = _queueLoad();
                                });
                              },
                            );
                            final officeFilter = _filterDropdown(
                              value: _selectedOffice,
                              items: offices,
                              width: 210,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedOffice = value;
                                  _selectedCategory = 'All Categories';
                                  _page = 1;
                                  _payloadFuture = _queueLoad();
                                });
                              },
                            );
                            final barangayFilter = _filterDropdown(
                              value: _selectedBarangay,
                              items: barangays,
                              width: 180,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedBarangay = value;
                                  _page = 1;
                                  _payloadFuture = _queueLoad();
                                });
                              },
                            );
                            final statusFilter = _filterDropdown(
                              value: _selectedStatus,
                              items: statuses,
                              width: 160,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedStatus = value;
                                  _page = 1;
                                  _payloadFuture = _queueLoad();
                                });
                              },
                            );

                            if (useInlineFilters) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    categoryFilter,
                                    const SizedBox(width: 12),
                                    officeFilter,
                                    const SizedBox(width: 12),
                                    barangayFilter,
                                    const SizedBox(width: 12),
                                    statusFilter,
                                  ],
                                ),
                              );
                            }

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                categoryFilter,
                                officeFilter,
                                barangayFilter,
                                statusFilter,
                              ],
                            );
                          },
                        );
                        final exportButton = FilledButton.icon(
                          onPressed: exportDisabled ? null : _exportReports,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2557D6),
                          ),
                          icon: exportDisabled
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
                            _exporting
                                ? 'Exporting...'
                                : (isLoading ? 'Syncing filters...' : 'Export Excel'),
                          ),
                        );

                        if (!useStackedToolbar) {
                          return Row(
                            children: [
                              Expanded(child: _searchField()),
                              const SizedBox(width: 12),
                              Expanded(flex: 3, child: filters),
                              const SizedBox(width: 12),
                              exportButton,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _searchField(),
                            const SizedBox(height: 12),
                            filters,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: exportButton,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${pageData.total} Reports$rangeLabel',
                      style: TextStyle(color: colors.mutedText, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    _tableHeader(),
                    const SizedBox(height: 6),
                    if (reports.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No reports match your current filters.',
                          style: TextStyle(color: colors.mutedText),
                        ),
                      )
                    else
                      ...reports.map((report) => _reportRow(report)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Showing ${pageData.total == 0 ? 0 : pageData.from} to ${pageData.to} of ${pageData.total} entries',
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        _pagerButton(
                          'Previous',
                          enabled: pageData.hasPreviousPage,
                          onTap: pageData.hasPreviousPage
                              ? () => _goToPage(pageData.currentPage - 1)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        _pagerIndex(
                          '${pageData.currentPage}/${pageData.lastPage}',
                        ),
                        const SizedBox(width: 8),
                        _pagerButton(
                          'Next',
                          enabled: pageData.hasNextPage,
                          onTap: pageData.hasNextPage
                              ? () => _goToPage(pageData.currentPage + 1)
                              : null,
                        ),
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
    );
    if (widget.embedded) {
      return ColoredBox(color: colors.background, child: body);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text('All Reports'),
      ),
      body: body,
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
      onTap: () => _openReportDetails(report),
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

  Widget _pagerButton(
    String label, {
    required bool enabled,
    VoidCallback? onTap,
  }) {
    final colors = AdminThemeColors.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? colors.input : colors.input.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled
                ? colors.mutedText
                : colors.mutedText.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
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
  const _ReportsPayload({required this.context, required this.page});

  final _ReportListContext context;
  final AdminReportPage page;
}

class _ReportListContext {
  const _ReportListContext({
    required this.user,
    required this.categories,
    required this.offices,
  });

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> offices;
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
