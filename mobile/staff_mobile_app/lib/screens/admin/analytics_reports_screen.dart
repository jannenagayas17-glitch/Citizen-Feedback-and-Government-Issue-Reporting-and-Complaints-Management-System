import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/file_download.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();

  late Future<_Payload> _payloadFuture;
  bool _exporting = false;
  String _department = 'All Departments';
  String _barangay = 'All Barangays';
  String _category = 'All Categories';
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day),
    );
    _payloadFuture = _load();
  }

  Future<_Payload> _load() async {
    final results = await Future.wait<dynamic>([
      _authService.getCurrentUser(),
      _reportService.getAdminReports(),
      _authService.getOffices(includeInactive: true),
    ]);
    return _Payload(
      user: results[0] as Map<String, dynamic>,
      reports: (results[1] as List).whereType<Map<String, dynamic>>().toList(),
      offices: (results[2] as List).whereType<Map<String, dynamic>>().toList(),
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await _reportService.exportAdminReports();
      await downloadFile(bytes: file.bytes, fileName: file.fileName, mimeType: file.mimeType);
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

  bool _isSuperAdmin(Map<String, dynamic> user) => (user['role'] ?? '').toString() == 'super_admin';

  String _officeName(Map<String, dynamic> report) => ((report['office'] as Map<String, dynamic>?)?['name'] ?? '').toString().trim();
  String _categoryName(Map<String, dynamic> report) => (((report['category'] as Map<String, dynamic>?)?['name'] ?? 'Other').toString().trim().isEmpty) ? 'Other' : ((report['category'] as Map<String, dynamic>?)?['name'] ?? 'Other').toString().trim();
  String _barangayName(Map<String, dynamic> report) => (report['barangay'] ?? '').toString().trim();
  String _status(Map<String, dynamic> report) => (report['status'] ?? 'New').toString();
  DateTime? _createdAt(Map<String, dynamic> report) => DateTime.tryParse((report['created_at'] ?? '').toString())?.toLocal();

  List<String> _options(List<String> raw, String allLabel) {
    final items = raw.where((e) => e.trim().isNotEmpty).toSet().toList()..sort();
    return [allLabel, ...items];
  }

  List<Map<String, dynamic>> _filtered(_Payload payload) {
    return _filteredForRange(payload, _range);
  }

  List<Map<String, dynamic>> _filteredForRange(
    _Payload payload,
    DateTimeRange range,
  ) {
    return payload.reports.where((report) {
      final created = _createdAt(report);
      if (created == null) return false;
      final date = DateTime(created.year, created.month, created.day);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      if (date.isBefore(start) || date.isAfter(end)) return false;
      if (_department != 'All Departments' && _officeName(report) != _department) return false;
      if (_barangay != 'All Barangays' && _barangayName(report) != _barangay) return false;
      if (_category != 'All Categories' && _categoryName(report) != _category) return false;
      return true;
    }).toList();
  }

  Map<String, int> _counts(List<Map<String, dynamic>> reports) {
    int countStatus(String value) => reports.where((r) => _status(r) == value).length;
    return {
      'total': reports.length,
      'pending': countStatus('Pending'),
      'progress': countStatus('In Progress'),
      'resolved': countStatus('Resolved'),
      'rejected': countStatus('Rejected'),
    };
  }

  List<MapEntry<String, int>> _grouped(List<Map<String, dynamic>> reports, String Function(Map<String, dynamic>) keyOf) {
    final map = <String, int>{};
    for (final report in reports) {
      final key = keyOf(report);
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    final items = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return items;
  }

  int _deltaPercent(int current, int previous) {
    if (previous <= 0) {
      return current > 0 ? 100 : 0;
    }
    return (((current - previous) / previous) * 100).round();
  }

  List<_Bucket> _buckets(List<Map<String, dynamic>> reports) {
    const segments = 7;
    final span = _range.end.difference(_range.start).inDays + 1;
    final bucketSize = math.max(1, (span / segments).ceil());
    final out = <_Bucket>[];
    for (var i = 0; i < segments; i++) {
      final start = _range.start.add(Duration(days: bucketSize * i));
      if (start.isAfter(_range.end)) break;
      final end = start.add(Duration(days: bucketSize - 1)).isAfter(_range.end) ? _range.end : start.add(Duration(days: bucketSize - 1));
      final items = reports.where((r) {
        final created = _createdAt(r);
        if (created == null) return false;
        final day = DateTime(created.year, created.month, created.day);
        return !day.isBefore(start) && !day.isAfter(end);
      }).toList();
      out.add(_Bucket(
        label: '${start.month}/${start.day}',
        total: items.length,
        pending: items.where((r) => _status(r) == 'Pending').length,
        progress: items.where((r) => _status(r) == 'In Progress').length,
        resolved: items.where((r) => _status(r) == 'Resolved').length,
        rejected: items.where((r) => _status(r) == 'Rejected').length,
      ));
    }
    return out;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1B),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_Payload>(
            future: _payloadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(20), children: [_panel(Text(snapshot.error.toString(), style: const TextStyle(color: Colors.white)))]);
              final payload = snapshot.data!;
              final departments = _options(payload.offices.map((o) => (o['name'] ?? '').toString()).toList(), 'All Departments');
              final barangays = _options(payload.reports.map(_barangayName).toList(), 'All Barangays');
              final categories = _options(payload.reports.map(_categoryName).toList(), 'All Categories');
              if (!departments.contains(_department)) _department = departments.first;
              if (!barangays.contains(_barangay)) _barangay = barangays.first;
              if (!categories.contains(_category)) _category = categories.first;
              final reports = _filtered(payload);
              final counts = _counts(reports);
              final spanDays = _range.end.difference(_range.start).inDays + 1;
              final previousRange = DateTimeRange(
                start: _range.start.subtract(Duration(days: spanDays)),
                end: _range.start.subtract(const Duration(days: 1)),
              );
              final previousCounts = _counts(_filteredForRange(payload, previousRange));
              final categoryBreakdown = _grouped(reports, _categoryName).take(6).toList();
              final barangayBreakdown = _grouped(reports, _barangayName).take(6).toList();
              final resolutionRate = counts['total'] == 0 ? 0 : (((counts['resolved'] ?? 0) / (counts['total'] ?? 1)) * 100).round();
              final screenWidth = MediaQuery.of(context).size.width;
              final isWide = screenWidth >= 1180;
              final useWideFilters = screenWidth >= 1380;
              final superAdmin = _isSuperAdmin(payload.user);

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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hint,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_deltaPercent(counts[key] ?? 0, previousCounts[key] ?? 0) >= 0 ? '+' : ''}${_deltaPercent(counts[key] ?? 0, previousCounts[key] ?? 0)}% from last period',
                          style: TextStyle(
                            color: _deltaPercent(counts[key] ?? 0, previousCounts[key] ?? 0) >= 0
                                ? const Color(0xFF7FE2B5)
                                : const Color(0xFFF38A8A),
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

              return ListView(
                padding: EdgeInsets.fromLTRB(14, 14, 14, bottom + 24),
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
                            const Text(
                              'Analytics',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              superAdmin
                                  ? 'View and manage all issue reports from across the city.'
                                  : 'Live analytics from your assigned office.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                              ),
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
                          label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (useWideFilters)
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _dropdown(
                                  _department,
                                  departments,
                                  (v) => setState(() => _department = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _dropdown(
                                  _barangay,
                                  barangays,
                                  (v) => setState(() => _barangay = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _dropdown(
                                  _category,
                                  categories,
                                  (v) => setState(() => _category = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 5,
                                child: _rangeButton(),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _dropdown(
                                _department,
                                departments,
                                (v) => setState(() => _department = v!),
                                width: 240,
                              ),
                              _dropdown(
                                _barangay,
                                barangays,
                                (v) => setState(() => _barangay = v!),
                                width: 240,
                              ),
                              _dropdown(
                                _category,
                                categories,
                                (v) => setState(() => _category = v!),
                                width: 240,
                              ),
                              SizedBox(
                                width: 280,
                                child: _rangeButton(),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
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
                        else
                          Wrap(
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
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isWide)
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 8, child: Column(children: [
                        _metricPanel(
                          'Reports Overview',
                          _trendBuckets(_buckets(reports)),
                          trailing: 'Last 30 Days',
                        ),
                        const SizedBox(height: 16),
                        _metricPanel(
                          'Report Resolution Rate',
                          _resolutionPanel(resolutionRate, categoryBreakdown),
                        ),
                      ])),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: Column(children: [
                        _metricPanel(
                          'Reports by Category',
                          _bars(
                            categoryBreakdown,
                            const Color(0xFF6678FF),
                            usePalette: true,
                          ),
                          trailing: 'All Time',
                        ),
                        const SizedBox(height: 16),
                        _metricPanel(
                          'Issues by Barangay',
                          _bars(barangayBreakdown, const Color(0xFF557DFF)),
                          trailing: 'Last 30 Days',
                        ),
                      ])),
                    ])
                  else ...[
                    _metricPanel(
                      'Reports Overview',
                      _trendBuckets(_buckets(reports)),
                      trailing: 'Last 30 Days',
                    ),
                    const SizedBox(height: 16),
                    _metricPanel(
                      'Reports by Category',
                      _bars(
                        categoryBreakdown,
                        const Color(0xFF6678FF),
                        usePalette: true,
                      ),
                      trailing: 'All Time',
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
                      trailing: 'Last 30 Days',
                    ),
                  ],
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
                        label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _topBar(Map<String, dynamic> user, bool superAdmin) {
    final name = (user['name'] ?? 'Admin').toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111426),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFF4C6FFF), borderRadius: BorderRadius.circular(10)), child: Icon(superAdmin ? Icons.star_rounded : Icons.chevron_right_rounded, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        const Text('CityTrack PH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        if (superAdmin) ...[
          const SizedBox(width: 14),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: const Color(0xFF2C2018), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF6F4D2C))), child: const Text('SUPER ADMIN', style: TextStyle(color: Color(0xFFF0A43B), fontWeight: FontWeight.w800))),
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
        CircleAvatar(radius: 12, backgroundColor: superAdmin ? const Color(0xFF6B5CF6) : const Color(0xFF4C6FFF), child: Text(name.isEmpty ? 'A' : name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _panel(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF111426),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: child,
      );

  Widget _rangeButton() => OutlinedButton(
        onPressed: _pickRange,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF181C2E),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_range.start.month}/${_range.start.day}/${_range.start.year}   \u2192   ${_range.end.month}/${_range.end.day}/${_range.end.year}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 18),
          ],
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
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
                      color: const Color(0xFF171B2B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          trailing,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.72),
                          size: 16,
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

  Widget _dropdown(String value, List<String> items, ValueChanged<String?> onChanged, {double? width}) => SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: const Color(0xFF181C2E),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF181C2E),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          iconEnabledColor: Colors.white70,
          selectedItemBuilder: (context) => items
              .map(
                (e) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    e,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)))).toList(),
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
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      );
    }
    final maxValue = entries.fold<int>(1, (max, item) => math.max(max, item.value));
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
                decoration: BoxDecoration(color: rowColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: Text(entry.key, style: const TextStyle(color: Colors.white)),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
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
                style: const TextStyle(
                  color: Colors.white,
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
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      );
    }
    final maxValue = buckets
        .map((bucket) => [
              bucket.total,
              bucket.pending,
              bucket.progress,
              bucket.resolved,
              bucket.rejected,
            ].reduce(math.max))
        .fold<int>(1, math.max);
    final ySteps = <int>[
      maxValue,
      (maxValue * 0.66).round(),
      (maxValue * 0.33).round(),
      0,
    ];

    return Column(
      children: [
        Row(children: const [
          _TrendLegend('Total', Color(0xFF557DFF)),
          SizedBox(width: 12),
          _TrendLegend('Pending', Color(0xFFF4B04F)),
          SizedBox(width: 12),
          _TrendLegend('In Progress', Color(0xFFD19A43)),
          SizedBox(width: 12),
          _TrendLegend('Resolved', Color(0xFF76D0B6)),
          SizedBox(width: 12),
          _TrendLegend('Rejected', Color(0xFFE16A74)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
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
                            color: Colors.white.withValues(alpha: 0.46),
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
                                  color: Colors.white.withValues(alpha: 0.56),
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

  Widget _resolutionPanel(int rate, List<MapEntry<String, int>> categories) => Row(children: [
    SizedBox(
      width: 150,
      height: 150,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CircularProgressIndicator(
            value: rate / 100,
            strokeWidth: 12,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6678FF)),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$rate%', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          Text(
            'Resolution Rate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
            ),
          ),
        ]),
      ]),
    ),
    const SizedBox(width: 18),
    Expanded(child: Column(children: categories.take(5).toList().asMap().entries.map((entry) {
      final color = _palette(entry.key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(entry.value.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          Text('${entry.value.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      );
    }).toList())),
  ]);

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
    const colors = [Color(0xFF557DFF), Color(0xFFF2B45A), Color(0xFF8FD6B6), Color(0xFF7AB6FF), Color(0xFFE16A74)];
    return colors[index % colors.length];
  }
}

class _Payload {
  const _Payload({required this.user, required this.reports, required this.offices});
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> reports;
  final List<Map<String, dynamic>> offices;
}

class _Bucket {
  const _Bucket({required this.label, required this.total, required this.pending, required this.progress, required this.resolved, required this.rejected});
  final String label;
  final int total;
  final int pending;
  final int progress;
  final int resolved;
  final int rejected;
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.68),
        fontSize: 11,
      ),
    ),
  ]);
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.buckets,
    required this.maxValue,
  });

  final List<_Bucket> buckets;
  final double maxValue;

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
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < buckets.length; i++) {
      final x = buckets.length == 1 ? 0.0 : size.width * (i / (buckets.length - 1));
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint..color = Colors.white.withValues(alpha: 0.03),
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
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1 ? size.width / 2 : size.width * (i / (values.length - 1));
        final normalized = maxValue <= 0 ? 0.0 : values[i] / maxValue;
        final y = size.height - (normalized * (size.height - 10)) - 5;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);

      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1 ? size.width / 2 : size.width * (i / (values.length - 1));
        final normalized = maxValue <= 0 ? 0.0 : values[i] / maxValue;
        final y = size.height - (normalized * (size.height - 10)) - 5;
        canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets || oldDelegate.maxValue != maxValue;
  }
}
