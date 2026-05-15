import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/department_issue_types.dart';
import '../../utils/file_download.dart';
import '../../utils/tacloban_barangays.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();

  late Future<_Payload> _payloadFuture;
  _Payload? _cachedPayload;
  bool _exporting = false;
  String _department = 'All Departments';
  String _barangay = 'All Barangays';
  String _category = 'All Categories';
  String _status = 'All Statuses';
  String _datePreset = 'all_time';
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _range = _defaultRange();
    _payloadFuture = _load();
  }

  Future<_Payload> _load() async {
    final user = await _authService.getCurrentUser();
    final isSuperAdmin = _isSuperAdmin(user);
    final results = await Future.wait<dynamic>([
      _authService.getOffices(includeInactive: isSuperAdmin),
      _reportService.getCategories(),
      _dashboardService.getAnalytics(
        office: _department == 'All Departments' ? null : _department,
        barangay: _barangay == 'All Barangays' ? null : _barangay,
        category: _category == 'All Categories' ? null : _category,
        status: _status == 'All Statuses' ? null : _status,
        datePreset: _datePreset,
        startDate: _datePreset == 'custom' ? _range.start : null,
        endDate: _datePreset == 'custom' ? _range.end : null,
      ),
    ]);
    final payload = _Payload(
      user: Map<String, dynamic>.from(user),
      reports: const [],
      offices: (results[0] as List)
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      categories: (results[1] as List)
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
      analytics: Map<String, dynamic>.from(results[2] as Map),
    );
    _cachedPayload = payload;

    return payload;
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await _reportService.exportAdminReports(
        office: _department == 'All Departments' ? null : _department,
        barangay: _barangay == 'All Barangays' ? null : _barangay,
        category: _category == 'All Categories' ? null : _category,
        status: _status == 'All Statuses' ? null : _status,
        datePreset: _datePreset,
        startDate: _datePreset == 'custom' ? _range.start : null,
        endDate: _datePreset == 'custom' ? _range.end : null,
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

  bool _isSuperAdmin(Map<String, dynamic> user) =>
      (user['role'] ?? '').toString() == 'super_admin';

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }

    return (user['department'] ?? '').toString().trim();
  }

  DateTimeRange _defaultRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return DateTimeRange(
      start: DateTime(today.year, today.month, 1),
      end: today,
    );
  }

  DateTimeRange _rangeForPreset(String? preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case 'weekly':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: start, end: today);
      case 'monthly':
        return DateTimeRange(start: DateTime(today.year, today.month, 1), end: today);
      case 'yearly':
        return DateTimeRange(start: DateTime(today.year, 1, 1), end: today);
      case 'last_7_days':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case 'last_30_days':
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case 'custom':
        return _range;
      default:
        return _defaultRange();
    }
  }

  String _datePresetLabel() {
    switch (_datePreset) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      case 'custom':
        return 'Custom Range';
      default:
        return 'All Time';
    }
  }

  void _setDatePreset(String label) {
    switch (label) {
      case 'All Time':
        _datePreset = 'all_time';
        _range = _defaultRange();
        break;
      case 'Weekly':
        _datePreset = 'weekly';
        _range = _rangeForPreset(_datePreset);
        break;
      case 'Monthly':
        _datePreset = 'monthly';
        _range = _rangeForPreset(_datePreset);
        break;
      case 'Yearly':
        _datePreset = 'yearly';
        _range = _rangeForPreset(_datePreset);
        break;
    }

    _refresh();
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  List<MapEntry<String, int>> _entriesFromAnalytics(List<dynamic>? raw) {
    final items =
        raw
            ?.whereType<Map<String, dynamic>>()
            .map(
              (row) => MapEntry(
                (row['label'] ?? '').toString(),
                _intValue(row['count']),
              ),
            )
            .where((entry) => entry.key.isNotEmpty)
            .toList() ??
        const <MapEntry<String, int>>[];

    return items;
  }

  List<_Bucket> _bucketsFromAnalytics(List<dynamic>? rawBuckets) {
    return rawBuckets
            ?.whereType<Map<String, dynamic>>()
            .map(
              (bucket) => _Bucket(
                label: (bucket['label'] ?? '').toString(),
                total: _intValue(bucket['total']),
                pending: _intValue(bucket['pending']),
                progress: _intValue(bucket['progress']),
                resolved: _intValue(bucket['resolved']),
                rejected: _intValue(bucket['rejected']),
              ),
            )
            .toList() ??
        const <_Bucket>[];
  }

  List<String> _options(
    Iterable<String> raw,
    String allLabel, {
    int Function(String, String)? compare,
  }) {
    final values = <String, String>{};
    for (final item in raw) {
      final value = item.trim();
      if (value.isEmpty) continue;
      values.putIfAbsent(value.toLowerCase(), () => value);
    }

    final items = values.values.toList()
      ..sort(compare ?? (a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [allLabel, ...items];
  }

  List<String> _departmentOptions(_Payload payload) {
    if (!_isSuperAdmin(payload.user)) {
      final department = _departmentLabel(payload.user);
      return department.isEmpty ? ['Assigned Department'] : [department];
    }

    return _options([
      ...payload.offices.map((office) => (office['name'] ?? '').toString()),
    ], 'All Departments');
  }

  List<String> _barangayOptions(_Payload payload) {
    return _options(
      taclobanBarangays,
      'All Barangays',
      compare: _compareBarangays,
    );
  }

  List<String> _categoryOptions(_Payload payload) {
    final selectedDepartments = _department == 'All Departments'
        ? [
            ...payload.offices.map(
              (office) => (office['name'] ?? '').toString(),
            ),
          ]
        : [_department];
    final mappedIssueTypes = issueTypesForDepartments(selectedDepartments);

    return _options([
      ...mappedIssueTypes,
      if (mappedIssueTypes.isEmpty)
        ...payload.categories.map(
          (category) => (category['name'] ?? '').toString(),
        ),
    ], 'All Categories');
  }

  List<String> _statusOptions() {
    return const [
      'All Statuses',
      'New',
      'Pending',
      'In Progress',
      'Resolved',
      'Rejected',
    ];
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

  int _deltaPercent(int current, int previous) {
    if (previous <= 0) {
      return current > 0 ? 100 : 0;
    }
    return (((current - previous) / previous) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = AdminThemeColors.of(context);
    final body = LayoutBuilder(
      builder: (context, viewportConstraints) {
        final bottom = MediaQuery.of(context).padding.bottom;
        final contentWidth = viewportConstraints.maxWidth;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_Payload>(
            future: _payloadFuture,
            initialData: _cachedPayload,
            builder: (context, snapshot) {
              final resolvedPayload = snapshot.data ?? _cachedPayload;
              final isLoading =
                  snapshot.connectionState != ConnectionState.done &&
                  resolvedPayload != null;

              if (resolvedPayload == null &&
                  snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _panel(
                      Text(
                        snapshot.error.toString(),
                        style: TextStyle(color: themeColors.text),
                      ),
                    ),
                  ],
                );
              }

              if (resolvedPayload == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final payload = resolvedPayload;
              final analytics = payload.analytics;
              final departments = _departmentOptions(payload);
              if (!departments.contains(_department)) {
                _department = departments.first;
              }
              final barangays = _barangayOptions(payload);
              final categories = _categoryOptions(payload);
              if (!barangays.contains(_barangay)) _barangay = barangays.first;
              if (!categories.contains(_category)) _category = categories.first;

              final overview = Map<String, dynamic>.from(
                analytics['overview'] as Map? ?? const {},
              );
              final comparisonOverview = Map<String, dynamic>.from(
                analytics['comparison_overview'] as Map? ?? const {},
              );
              final timelineMeta = Map<String, dynamic>.from(
                analytics['timeline_meta'] as Map? ?? const {},
              );
              final roleScope = Map<String, dynamic>.from(
                analytics['role_scope'] as Map? ?? const {},
              );
              final counts = <String, int>{
                'total': _intValue(overview['total_reports']),
                'pending': _intValue(overview['pending']),
                'progress': _intValue(overview['in_progress']),
                'resolved': _intValue(overview['resolved']),
                'rejected': _intValue(overview['rejected']),
              };
              final previousCounts = <String, int>{
                'total': _intValue(comparisonOverview['total_reports']),
                'pending': _intValue(comparisonOverview['pending']),
                'progress': _intValue(comparisonOverview['in_progress']),
                'resolved': _intValue(comparisonOverview['resolved']),
                'rejected': _intValue(comparisonOverview['rejected']),
              };
              final categoryBreakdown = _entriesFromAnalytics(
                analytics['category_breakdown'] as List?,
              );
              final barangayBreakdown = _entriesFromAnalytics(
                analytics['barangay_breakdown'] as List?,
              );
              final timelineBuckets = _bucketsFromAnalytics(
                analytics['timeline_breakdown'] as List?,
              );
              final officeBreakdown =
                  (analytics['office_breakdown'] as List<dynamic>? ?? const [])
                      .whereType<Map<String, dynamic>>()
                      .map(Map<String, dynamic>.from)
                      .toList();
              final departmentTrend = _DepartmentTrendData.fromAnalytics(
                analytics['department_trend'] as Map?,
              );
              final totalCount = counts['total'] ?? 0;
              final resolvedCount = counts['resolved'] ?? 0;
              final resolutionRate = totalCount == 0
                  ? 0
                  : ((resolvedCount / totalCount) * 100).round();
              final isWide = contentWidth >= 1120;
              final useWideFilters = contentWidth >= 1320;
              final superAdmin = _isSuperAdmin(payload.user);
              final dateLabel =
                  (timelineMeta['range_label'] ?? _datePresetLabel()).toString();
              final groupingLabel =
                  (timelineMeta['grouping_label'] ?? '').toString();
              final scopeLabel =
                  (roleScope['selected_department'] ?? _department).toString();
              final hasComparison = _datePreset != 'all_time';
              final statuses = _statusOptions();
              if (!statuses.contains(_status)) {
                _status = statuses.first;
              }

              Widget card(
                String label,
                String key,
                String hint, {
                IconData? icon,
              }) => Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _colorFor(key).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _colorFor(key).withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${counts[key] ?? 0}',
                            style: TextStyle(
                              color: _colorFor(key),
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (icon != null)
                          Icon(icon, color: _colorFor(key), size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: themeColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      style: TextStyle(
                        color: themeColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasComparison
                          ? '${_deltaPercent(counts[key] ?? 0, previousCounts[key] ?? 0) >= 0 ? '+' : ''}${_deltaPercent(counts[key] ?? 0, previousCounts[key] ?? 0)}% from last period'
                          : 'Showing all scoped reports',
                      style: TextStyle(
                        color: hasComparison
                            ? (_deltaPercent(
                                        counts[key] ?? 0,
                                        previousCounts[key] ?? 0,
                                      ) >=
                                      0
                                  ? const Color(0xFF7FE2B5)
                                  : const Color(0xFFF38A8A))
                            : themeColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );

              Widget summaryCard(
                String label,
                String key,
                String hint, {
                IconData? icon,
              }) {
                final child = card(label, key, hint, icon: icon);
                if (!isWide) return child;
                return Expanded(child: child);
              }

              final filterRow = useWideFilters
                  ? Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _dropdown(_department, departments, (v) {
                            if (v == null) return;
                            setState(() {
                              _department = v;
                              _category = 'All Categories';
                              _payloadFuture = _load();
                            });
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _dropdown(_barangay, barangays, (v) {
                            if (v == null) return;
                            setState(() {
                              _barangay = v;
                              _payloadFuture = _load();
                            });
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _dropdown(_category, categories, (v) {
                            if (v == null) return;
                            setState(() {
                              _category = v;
                              _payloadFuture = _load();
                            });
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: _dropdown(_status, statuses, (v) {
                            if (v == null) return;
                            setState(() {
                              _status = v;
                              _payloadFuture = _load();
                            });
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _dropdown(
                                _datePresetLabel(),
                                const [
                                  'All Time',
                                  'Weekly',
                                  'Monthly',
                                  'Yearly',
                                ],
                                (v) {
                                  if (v == null) return;
                                  _setDatePreset(v);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _dropdown(_department, departments, (v) {
                          if (v == null) return;
                          setState(() {
                            _department = v;
                            _category = 'All Categories';
                            _payloadFuture = _load();
                          });
                        }, width: 240),
                        _dropdown(_barangay, barangays, (v) {
                          if (v == null) return;
                          setState(() {
                            _barangay = v;
                            _payloadFuture = _load();
                          });
                        }, width: 240),
                        _dropdown(_category, categories, (v) {
                          if (v == null) return;
                          setState(() {
                            _category = v;
                            _payloadFuture = _load();
                          });
                        }, width: 240),
                        _dropdown(_status, statuses, (v) {
                          if (v == null) return;
                          setState(() {
                            _status = v;
                            _payloadFuture = _load();
                          });
                        }, width: 220),
                        SizedBox(
                          width: 280,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _dropdown(
                                _datePresetLabel(),
                                const [
                                  'All Time',
                                  'Weekly',
                                  'Monthly',
                                  'Yearly',
                                ],
                                (v) {
                                  if (v == null) return;
                                  _setDatePreset(v);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

              final summaryRow = isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        summaryCard(
                          'Total Reports',
                          'total',
                          'Filtered city reports',
                          icon: Icons.insert_chart_rounded,
                        ),
                        const SizedBox(width: 14),
                        summaryCard(
                          'Pending Reports',
                          'pending',
                          'Needs triage',
                          icon: Icons.south_rounded,
                        ),
                        const SizedBox(width: 14),
                        summaryCard(
                          'In Progress Reports',
                          'progress',
                          'Assigned to staff',
                          icon: Icons.north_rounded,
                        ),
                        const SizedBox(width: 14),
                        summaryCard(
                          'Resolved Reports',
                          'resolved',
                          'Closed cases',
                          icon: Icons.trending_up_rounded,
                        ),
                        const SizedBox(width: 14),
                        summaryCard(
                          'Rejected Reports',
                          'rejected',
                          'Invalid or prank',
                          icon: Icons.south_east_rounded,
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        card(
                          'Total Reports',
                          'total',
                          'Filtered city reports',
                          icon: Icons.insert_chart_rounded,
                        ),
                        card(
                          'Pending Reports',
                          'pending',
                          'Needs triage',
                          icon: Icons.south_rounded,
                        ),
                        card(
                          'In Progress Reports',
                          'progress',
                          'Assigned to staff',
                          icon: Icons.north_rounded,
                        ),
                        card(
                          'Resolved Reports',
                          'resolved',
                          'Closed cases',
                          icon: Icons.trending_up_rounded,
                        ),
                        card(
                          'Rejected Reports',
                          'rejected',
                          'Invalid or prank',
                          icon: Icons.south_east_rounded,
                        ),
                      ],
                    );

              final chartTrailing = groupingLabel.isEmpty
                  ? dateLabel
                  : '$groupingLabel • $dateLabel';
              final analyticsPanelsCore = isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: Column(
                            children: [
                              _metricPanel(
                                'Reports Overview',
                                _trendBuckets(timelineBuckets),
                                trailing: chartTrailing,
                              ),
                              const SizedBox(height: 16),
                              _metricPanel(
                                'Report Resolution Rate',
                                _resolutionPanel(
                                  resolutionRate,
                                  categoryBreakdown,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _metricPanel(
                                'Reports by Category',
                                _bars(
                                  categoryBreakdown,
                                  const Color(0xFF6678FF),
                                  usePalette: true,
                                ),
                                trailing: chartTrailing,
                              ),
                              const SizedBox(height: 16),
                              _metricPanel(
                                'Issues by Barangay',
                                _bars(
                                  barangayBreakdown,
                                  const Color(0xFF557DFF),
                                ),
                                trailing: chartTrailing,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _metricPanel(
                          'Reports Overview',
                          _trendBuckets(timelineBuckets),
                          trailing: chartTrailing,
                        ),
                        const SizedBox(height: 16),
                        _metricPanel(
                          'Reports by Category',
                          _bars(
                            categoryBreakdown,
                            const Color(0xFF6678FF),
                            usePalette: true,
                          ),
                          trailing: chartTrailing,
                        ),
                        const SizedBox(height: 16),
                        _metricPanel(
                          'Report Resolution Rate',
                          _resolutionPanel(resolutionRate, categoryBreakdown),
                        ),
                        const SizedBox(height: 16),
                        _metricPanel(
                          'Issues by Barangay',
                          _bars(barangayBreakdown, const Color(0xFF557DFF)),
                          trailing: chartTrailing,
                        ),
                      ],
                    );
              final analyticsPanels = AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Column(
                  key: ValueKey(
                    [
                      analytics['generated_at'],
                      _department,
                      _barangay,
                      _category,
                      _status,
                      _datePreset,
                    ].join('|'),
                  ),
                  children: [
                    _metricPanel(
                      superAdmin
                          ? 'Department Activity Trends'
                          : 'Assigned Department Trend',
                      _departmentTrendPanel(
                        departmentTrend: departmentTrend,
                        officeBreakdown: officeBreakdown,
                        scopeLabel: scopeLabel,
                      ),
                      trailing: chartTrailing,
                    ),
                    const SizedBox(height: 16),
                    analyticsPanelsCore,
                  ],
                ),
              );

              return Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(14, 14, 14, bottom + 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (!widget.embedded) _topBar(payload.user, superAdmin),
                      if (!widget.embedded) const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Analytics',
                                  style: TextStyle(
                                    color: themeColors.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  superAdmin
                                      ? 'Compare departments and track live citywide report behavior.'
                                      : 'Live analytics for $scopeLabel using real scoped report records.',
                                  style: TextStyle(color: themeColors.mutedText),
                                ),
                              ],
                            ),
                          ),
                          if (isWide) ...[
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: _exporting ? null : _export,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2557D6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
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
                                  : const Icon(Icons.download_rounded, size: 16),
                              label: Text(
                                _exporting ? 'Exporting...' : 'Export Excel',
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            filterRow,
                            const SizedBox(height: 16),
                            summaryRow,
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      analyticsPanels,
                      if (!isWide) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _exporting ? null : _export,
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
                                : const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              _exporting ? 'Exporting...' : 'Export Excel',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isLoading)
                    Positioned(
                      right: 18,
                      top: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: themeColors.panel,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: themeColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 14,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2557D6),
                                ),
                                backgroundColor: themeColors.border,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Updating analytics...',
                              style: TextStyle(
                                color: themeColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );

    if (widget.embedded) {
      return ColoredBox(color: themeColors.background, child: body);
    }

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(child: body),
    );
  }

  Widget _topBar(Map<String, dynamic> user, bool superAdmin) {
    final colors = AdminThemeColors.of(context);
    final name = (user['name'] ?? 'Admin').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4C6FFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              superAdmin ? Icons.star_rounded : Icons.chevron_right_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'CityTrack PH',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          if (superAdmin) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2018),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF6F4D2C)),
              ),
              child: const Text(
                'SUPER ADMIN',
                style: TextStyle(
                  color: Color(0xFFF0A43B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 10),
            Text(
              'Admin Portal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.34),
                fontSize: 12,
              ),
            ),
          ],
          const Spacer(),
          CircleAvatar(
            radius: 12,
            backgroundColor: superAdmin
                ? const Color(0xFF6B5CF6)
                : const Color(0xFF4C6FFF),
            child: Text(
              name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AdminThemeColors.of(context).panel,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AdminThemeColors.of(context).border),
    ),
    child: child,
  );

  Widget _metricPanel(String title, Widget child, {String? trailing}) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AdminThemeColors.of(context).text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AdminThemeColors.of(context).input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminThemeColors.of(context).border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: AdminThemeColors.of(context).mutedText,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trailing,
                      style: TextStyle(
                        color: AdminThemeColors.of(context).text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    double? width,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      isExpanded: true,
      dropdownColor: AdminThemeColors.of(context).panel,
      decoration: InputDecoration(
        filled: true,
        fillColor: AdminThemeColors.of(context).input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
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
      style: TextStyle(color: AdminThemeColors.of(context).text),
      iconEnabledColor: AdminThemeColors.of(context).mutedText,
      selectedItemBuilder: (context) => items
          .map(
            (e) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                e,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AdminThemeColors.of(context).text),
              ),
            ),
          )
          .toList(),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AdminThemeColors.of(context).text),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );

  Widget _bars(
    List<MapEntry<String, int>> entries,
    Color color, {
    bool usePalette = false,
  }) {
    if (entries.isEmpty) {
      return Text(
        'No data for the selected filters.',
        style: TextStyle(color: AdminThemeColors.of(context).mutedText),
      );
    }
    final colors = AdminThemeColors.of(context);
    final maxValue = entries.fold<int>(
      1,
      (max, item) => math.max(max, item.value),
    );
    return Column(
      children: entries.take(6).toList().asMap().entries.map((wrapped) {
        final index = wrapped.key;
        final entry = wrapped.value;
        final rowColor = usePalette ? _palette(index) : color;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: rowColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: Text(entry.key, style: TextStyle(color: colors.text)),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: entry.value / maxValue,
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              rowColor.withValues(alpha: 0.75),
                              rowColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${entry.value}',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _trendBuckets(List<_Bucket> buckets) {
    if (buckets.isEmpty) {
      return Text(
        'No trend data is available for the selected range.',
        style: TextStyle(color: AdminThemeColors.of(context).mutedText),
      );
    }
    final colors = AdminThemeColors.of(context);
    final maxValue = buckets
        .map(
          (bucket) => [
            bucket.total,
            bucket.pending,
            bucket.progress,
            bucket.resolved,
            bucket.rejected,
          ].reduce(math.max),
        )
        .fold<int>(1, math.max);
    final ySteps = <int>[
      maxValue,
      (maxValue * 0.66).round(),
      (maxValue * 0.33).round(),
      0,
    ];

    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const [
            _TrendLegend('Total', Color(0xFF557DFF)),
            _TrendLegend('Pending', Color(0xFFF4B04F)),
            _TrendLegend('In Progress', Color(0xFFD19A43)),
            _TrendLegend('Resolved', Color(0xFF76D0B6)),
            _TrendLegend('Rejected', Color(0xFFE16A74)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ySteps
                      .map(
                        (value) => Text(
                          '$value',
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: _TrendChartPainter(
                          buckets: buckets,
                          maxValue: maxValue.toDouble(),
                          gridColor: colors.border,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: buckets
                          .map(
                            (bucket) => Expanded(
                              child: Text(
                                bucket.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resolutionPanel(int rate, List<MapEntry<String, int>> categories) {
    final colors = AdminThemeColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: rate / 100,
                  strokeWidth: 12,
                  backgroundColor: colors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6678FF),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$rate%',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Resolution Rate',
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: categories.take(5).toList().asMap().entries.map((entry) {
              final color = _palette(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value.key,
                        style: TextStyle(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value.value}',
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _departmentTrendPanel({
    required _DepartmentTrendData departmentTrend,
    required List<Map<String, dynamic>> officeBreakdown,
    required String scopeLabel,
  }) {
    final colors = AdminThemeColors.of(context);
    final series = departmentTrend.series;
    final labels = departmentTrend.labels;
    final maxValue = series.isEmpty
        ? 1
        : series
              .expand((item) => item.counts)
              .fold<int>(1, (current, value) => math.max(current, value));

    if (series.isEmpty && officeBreakdown.isEmpty) {
      return Text(
        'No department activity data is available for the selected filters.',
        style: TextStyle(color: colors.mutedText),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final labelWidth = compact ? 120.0 : 180.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact
                  ? scopeLabel
                  : '$scopeLabel • Real report activity by time period',
              style: TextStyle(color: colors.mutedText, fontSize: 12),
            ),
            if (labels.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(width: labelWidth + 20),
                  Expanded(
                    child: Row(
                      children: labels
                          .map(
                            (label) => Expanded(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
            if (series.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...series.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final color = _palette(index);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.total} reports • ${item.resolutionRate}% resolved',
                              style: TextStyle(
                                color: colors.mutedText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: item.counts.asMap().entries.map((point) {
                              final count = point.value;
                              final pointLabel = point.key < labels.length
                                  ? labels[point.key]
                                  : 'Period ${point.key + 1}';
                              final height = maxValue == 0
                                  ? 8.0
                                  : math.max(8.0, (count / maxValue) * 42);
                              return Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: Tooltip(
                                    message:
                                        '${item.label} • $pointLabel: $count',
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$count',
                                          style: TextStyle(
                                            color: colors.mutedText,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 220),
                                          curve: Curves.easeOutCubic,
                                          height: height,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                color.withValues(alpha: 0.55),
                                                color,
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (officeBreakdown.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: officeBreakdown.take(4).map((item) {
                  final label = (item['label'] ?? 'Department').toString();
                  final total = _intValue(item['count']);
                  final resolution = _intValue(item['resolution_rate']);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.input,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '$label • $total reports • $resolution% resolved',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Color _colorFor(String key) {
    switch (key) {
      case 'pending':
        return const Color(0xFFF4B04F);
      case 'progress':
        return const Color(0xFFD19A43);
      case 'resolved':
        return const Color(0xFF76D0B6);
      case 'rejected':
        return const Color(0xFFE16A74);
      default:
        return const Color(0xFF7AA2FF);
    }
  }

  Color _palette(int index) {
    const colors = [
      Color(0xFF557DFF),
      Color(0xFFF2B45A),
      Color(0xFF8FD6B6),
      Color(0xFF7AB6FF),
      Color(0xFFE16A74),
    ];
    return colors[index % colors.length];
  }
}

class _Payload {
  const _Payload({
    required this.user,
    required this.reports,
    required this.offices,
    required this.categories,
    required this.analytics,
  });
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> offices;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic> analytics;
}

class _Bucket {
  const _Bucket({
    required this.label,
    required this.total,
    required this.pending,
    required this.progress,
    required this.resolved,
    required this.rejected,
  });
  final String label;
  final int total;
  final int pending;
  final int progress;
  final int resolved;
  final int rejected;
}

class _DepartmentTrendData {
  const _DepartmentTrendData({
    required this.labels,
    required this.series,
  });

  factory _DepartmentTrendData.fromAnalytics(Map<dynamic, dynamic>? raw) {
    final data = raw == null ? const <dynamic, dynamic>{} : Map<dynamic, dynamic>.from(raw);
    final labels = (data['labels'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.trim().isNotEmpty)
        .toList();
    final series = (data['series'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_DepartmentTrendSeries.fromJson)
        .toList();

    return _DepartmentTrendData(labels: labels, series: series);
  }

  final List<String> labels;
  final List<_DepartmentTrendSeries> series;
}

class _DepartmentTrendSeries {
  const _DepartmentTrendSeries({
    required this.label,
    required this.counts,
    required this.total,
    required this.resolutionRate,
  });

  factory _DepartmentTrendSeries.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return _DepartmentTrendSeries(
      label: (json['label'] ?? '').toString(),
      counts: (json['counts'] as List<dynamic>? ?? const [])
          .map(parseInt)
          .toList(),
      total: parseInt(json['total']),
      resolutionRate: parseInt(json['resolution_rate']),
    );
  }

  final String label;
  final List<int> counts;
  final int total;
  final int resolutionRate;
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: AdminThemeColors.of(context).mutedText,
          fontSize: 11,
        ),
      ),
    ],
  );
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.buckets,
    required this.maxValue,
    required this.gridColor,
  });

  final List<_Bucket> buckets;
  final double maxValue;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const chartColors = <Color>[
      Color(0xFF557DFF),
      Color(0xFFF4B04F),
      Color(0xFFD19A43),
      Color(0xFF76D0B6),
      Color(0xFFE16A74),
    ];
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < buckets.length; i++) {
      final x = buckets.length == 1
          ? 0.0
          : size.width * (i / (buckets.length - 1));
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint..color = gridColor.withValues(alpha: 0.65),
      );
    }

    final series = <List<int>>[
      buckets.map((bucket) => bucket.total).toList(),
      buckets.map((bucket) => bucket.pending).toList(),
      buckets.map((bucket) => bucket.progress).toList(),
      buckets.map((bucket) => bucket.resolved).toList(),
      buckets.map((bucket) => bucket.rejected).toList(),
    ];

    for (var s = 0; s < series.length; s++) {
      final values = series[s];
      final color = chartColors[s];
      final path = Path();
      final dotPaint = Paint()..color = color;
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? size.width / 2
            : size.width * (i / (values.length - 1));
        final normalized = maxValue <= 0 ? 0.0 : values[i] / maxValue;
        final y = size.height - (normalized * (size.height - 10)) - 5;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (s == 0 && values.isNotEmpty) {
        final areaPath = Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        final areaPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(Offset.zero & size);
        canvas.drawPath(areaPath, areaPaint);
      }
      canvas.drawPath(path, linePaint);

      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? size.width / 2
            : size.width * (i / (values.length - 1));
        final normalized = maxValue <= 0 ? 0.0 : values[i] / maxValue;
        final y = size.height - (normalized * (size.height - 10)) - 5;
        canvas.drawCircle(
          Offset(x, y),
          s == 0 ? 5 : 3.5,
          Paint()..color = color.withValues(alpha: s == 0 ? 0.18 : 0.0),
        );
        canvas.drawCircle(Offset(x, y), s == 0 ? 3.8 : 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.gridColor != gridColor;
  }
}
