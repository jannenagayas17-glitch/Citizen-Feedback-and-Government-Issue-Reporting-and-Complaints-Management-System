import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/feedback_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/tacloban_barangays.dart';

class FeedbackManagementScreen extends StatefulWidget {
  const FeedbackManagementScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FeedbackManagementScreen> createState() =>
      _FeedbackManagementScreenState();
}

class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
  static const int _pageSize = 20;
  static const Map<String, String?> _datePresets = <String, String?>{
    'All Time': null,
    'Last 7 Days': 'last_7_days',
    'Last 30 Days': 'last_30_days',
    'Last 90 Days': 'last_90_days',
    'This Year': 'this_year',
  };
  static const List<String> _ratingOptions = <String>[
    'All Ratings',
    '5 Stars',
    '4 Stars',
    '3 Stars',
    '2 Stars',
    '1 Star',
  ];
  static const List<String> _typeOptions = <String>[
    'All Feedback',
    'Suggestion',
    'Complaint',
    'Praise',
  ];

  final FeedbackService _feedbackService = FeedbackService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  _FeedbackContext? _contextCache;
  late Future<_FeedbackPayload> _payloadFuture;
  _FeedbackPayload? _resolvedPayload;
  int _requestVersion = 0;
  Timer? _searchDebounce;
  String _search = '';
  String _selectedDateLabel = 'All Time';
  String _selectedType = 'All Feedback';
  String _selectedBarangay = 'All Barangays';
  String _selectedOffice = 'All Departments';
  String _selectedRating = 'All Ratings';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _payloadFuture = _queueLoad(refreshContext: true);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
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
  }

  Future<_FeedbackContext> _loadContext({bool refresh = false}) async {
    if (!refresh && _contextCache != null) {
      return _contextCache!;
    }

    final user = await _authService.getCurrentUser();
    final isSuperAdmin = _isSuperAdmin(user);
    final offices = await _authService.getOffices(
      includeInactive: isSuperAdmin,
    );

    final context = _FeedbackContext(
      user: Map<String, dynamic>.from(user),
      offices: offices
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList(),
    );
    _contextCache = context;
    return context;
  }

  _FeedbackQuery _currentQuery({int? page}) {
    return _FeedbackQuery(
      page: page ?? _page,
      perPage: _pageSize,
      search: _search,
      type: _selectedType == 'All Feedback' ? null : _selectedType,
      barangay: _selectedBarangay == 'All Barangays'
          ? null
          : _selectedBarangay,
      office: _selectedOffice == 'All Departments' ? null : _selectedOffice,
      rating: _selectedRatingValue(),
      datePreset: _datePresets[_selectedDateLabel],
    );
  }

  Future<_FeedbackPayload> _queueLoad({
    bool refreshContext = false,
    _FeedbackQuery? query,
    bool pageOnly = false,
  }) {
    final requestId = ++_requestVersion;
    final request = query ?? _currentQuery();

    return pageOnly
        ? _loadPageOnly(request, requestId: requestId)
        : _loadPayload(
            refreshContext: refreshContext,
            query: request,
            requestId: requestId,
          );
  }

  _FeedbackQuery _normalizeQuery(
    _FeedbackQuery query,
    _FeedbackContext context,
  ) {
    String? normalizedOffice = query.office;
    if (!_isSuperAdmin(context.user)) {
      normalizedOffice = null;
    } else if (normalizedOffice != null &&
        !_officeOptions(context).skip(1).contains(normalizedOffice)) {
      normalizedOffice = null;
    }

    final normalizedBarangay =
        query.barangay != null &&
            !_barangayOptions().skip(1).contains(query.barangay)
        ? null
        : query.barangay;

    final normalizedType =
        query.type != null && !_typeOptions.skip(1).contains(query.type)
        ? null
        : query.type;

    final normalizedRating =
        query.rating != null && (query.rating! < 1 || query.rating! > 5)
        ? null
        : query.rating;

    return _FeedbackQuery(
      page: query.page,
      perPage: query.perPage,
      search: query.search,
      type: normalizedType,
      barangay: normalizedBarangay,
      office: normalizedOffice,
      rating: normalizedRating,
      datePreset: query.datePreset,
    );
  }

  Future<FeedbackPage> _fetchFeedbackPage(_FeedbackQuery query) {
    return _feedbackService.getFeedbackPage(
      page: query.page,
      perPage: query.perPage,
      search: query.search,
      type: query.type,
      barangay: query.barangay,
      office: query.office,
      rating: query.rating,
      datePreset: query.datePreset,
    );
  }

  Future<FeedbackPage> _normalizePageForQuery(
    _FeedbackQuery query,
    FeedbackPage page,
  ) async {
    if (page.entries.isNotEmpty || page.total == 0 || query.page <= 1) {
      return page;
    }

    final resolvedPage = math.max(1, page.lastPage);
    if (resolvedPage >= query.page) {
      return page;
    }

    return _fetchFeedbackPage(query.copyWith(page: resolvedPage));
  }

  Future<_FeedbackPayload> _loadPayload({
    bool refreshContext = false,
    _FeedbackQuery? query,
    required int requestId,
  }) async {
    final context = await _loadContext(refresh: refreshContext);
    final request = _normalizeQuery(query ?? _currentQuery(), context);

    final results = await Future.wait<dynamic>([
      _feedbackService.getFeedbackSummary(
        search: request.search,
        type: request.type,
        barangay: request.barangay,
        office: request.office,
        rating: request.rating,
        datePreset: request.datePreset,
      ),
      _feedbackService.getFeedbackCharts(
        search: request.search,
        type: request.type,
        barangay: request.barangay,
        office: request.office,
        rating: request.rating,
        datePreset: request.datePreset,
      ),
      _fetchFeedbackPage(request),
    ]);

    final page = await _normalizePageForQuery(request, results[2] as FeedbackPage);

    final payload = _FeedbackPayload(
      context: context,
      summary: results[0] as FeedbackSummaryData,
      charts: results[1] as FeedbackChartsData,
      page: page,
      query: request.copyWith(page: page.currentPage),
    );
    if (requestId == _requestVersion) {
      _resolvedPayload = payload;
      _page = page.currentPage;
    }

    return payload;
  }

  Future<_FeedbackPayload> _loadPageOnly(
    _FeedbackQuery query, {
    required int requestId,
  }) async {
    final cachedPayload = _resolvedPayload;
    if (cachedPayload == null) {
      return _loadPayload(query: query, requestId: requestId);
    }

    final normalizedQuery = _normalizeQuery(query, cachedPayload.context);
    final page = await _normalizePageForQuery(
      normalizedQuery,
      await _fetchFeedbackPage(normalizedQuery),
    );

    final payload = _FeedbackPayload(
      context: cachedPayload.context,
      summary: cachedPayload.summary,
      charts: cachedPayload.charts,
      page: page,
      query: normalizedQuery.copyWith(page: page.currentPage),
    );
    if (requestId == _requestVersion) {
      _resolvedPayload = payload;
      _page = page.currentPage;
    }
    return payload;
  }

  Future<void> _refresh() async {
    final future = _queueLoad(
      refreshContext: true,
      query: _currentQuery(),
    );
    setState(() => _payloadFuture = future);
    await future;
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page == _page) {
      return;
    }

    setState(() {
      _page = page;
      _payloadFuture = _queueLoad(
        query: _currentQuery(page: page),
        pageOnly: true,
      );
    });
    await _payloadFuture;
  }

  bool _isSuperAdmin(Map<String, dynamic> user) =>
      (user['role'] ?? '').toString().trim() == 'super_admin';

  String _departmentLabel(Map<String, dynamic> user) {
    final office = user['office'];
    if (office is Map<String, dynamic>) {
      final officeName = (office['name'] ?? '').toString().trim();
      if (officeName.isNotEmpty) {
        return officeName;
      }
    }

    final department = (user['department'] ?? '').toString().trim();
    return department.isEmpty ? 'Assigned Department' : department;
  }

  List<String> _officeOptions(_FeedbackContext context) {
    if (!_isSuperAdmin(context.user)) {
      final department = _departmentLabel(context.user);
      return department.isEmpty ? ['Assigned Department'] : [department];
    }

    final values = <String, String>{};
    for (final office in context.offices) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }
      values.putIfAbsent(name.toLowerCase(), () => name);
    }

    final offices = values.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['All Departments', ...offices];
  }

  List<String> _barangayOptions() {
    final values = <String, String>{};
    for (final barangay in taclobanBarangays) {
      final trimmed = barangay.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      values.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }

    final items = values.values.toList()..sort(_compareBarangays);
    return ['All Barangays', ...items];
  }

  int _compareBarangays(String a, String b) {
    final aNumber = _barangayNumber(a);
    final bNumber = _barangayNumber(b);
    if (aNumber != null && bNumber != null && aNumber != bNumber) {
      return aNumber.compareTo(bNumber);
    }
    if (aNumber != null && bNumber == null) {
      return -1;
    }
    if (aNumber == null && bNumber != null) {
      return 1;
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  double? _barangayNumber(String value) {
    final match = RegExp(
      r'^barangay\s+(\d+)(?:-([a-z]))?',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    final number = double.tryParse(match.group(1)!);
    if (number == null) {
      return null;
    }

    final suffix = match.group(2);
    if (suffix == null) {
      return number;
    }

    return number + ((suffix.toLowerCase().codeUnitAt(0) - 96) / 10);
  }

  int? _selectedRatingValue() {
    if (_selectedRating == 'All Ratings') {
      return null;
    }
    return int.tryParse(_selectedRating.substring(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final body = LayoutBuilder(
      builder: (context, viewportConstraints) {
        final bottomSafeArea = MediaQuery.of(context).padding.bottom;
        final contentWidth = viewportConstraints.maxWidth;
        final showSplitHeader = contentWidth >= 760;
        final showWideCharts = contentWidth >= 1100;

        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2557D6),
          child: FutureBuilder<_FeedbackPayload>(
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
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomSafeArea),
                  children: [
                    _FeedbackErrorCard(
                      message: snapshot.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                      onRetry: _refresh,
                    ),
                  ],
                );
              }

              if (payload == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final officeOptions = _officeOptions(payload.context);
              final barangayOptions = _barangayOptions();

              final effectiveOffice = officeOptions.contains(_selectedOffice)
                  ? _selectedOffice
                  : officeOptions.first;
              final effectiveBarangay =
                  barangayOptions.contains(_selectedBarangay)
                  ? _selectedBarangay
                  : barangayOptions.first;

              if (effectiveOffice != _selectedOffice ||
                  effectiveBarangay != _selectedBarangay) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _selectedOffice = effectiveOffice;
                    _selectedBarangay = effectiveBarangay;
                  });
                });
              }

              final summary = payload.summary;
              final charts = payload.charts;
              final page = payload.page;
              final headerBadge = _FeedbackHeaderBadge(
                icon: _isSuperAdmin(payload.context.user)
                    ? Icons.hub_outlined
                    : Icons.apartment_rounded,
                title: _isSuperAdmin(payload.context.user)
                    ? 'All departments'
                    : _departmentLabel(payload.context.user),
                subtitle: _isSuperAdmin(payload.context.user)
                    ? 'Focused feedback monitoring across the whole system.'
                    : 'Focused feedback monitoring for your assigned department.',
              );

              final ratingItems = charts.ratingBreakdown
                  .map(
                    (item) => FeedbackBreakdownItem(
                      label: item.label,
                      count: item.count,
                    ),
                  )
                  .toList();

              return ListView(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + bottomSafeArea),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (isLoading) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: Color(0xFF2557D6),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (snapshot.hasError) ...[
                    _FeedbackStatusBanner(
                      message: snapshot.error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (showSplitHeader)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Feedback',
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isSuperAdmin(payload.context.user)
                                    ? 'Review scoped citizen feedback, ratings, and trends across all departments.'
                                    : 'Review citizen feedback, ratings, and trends for your assigned department.',
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(width: 290, child: headerBadge),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSuperAdmin(payload.context.user)
                              ? 'Review scoped citizen feedback, ratings, and trends across all departments.'
                              : 'Review citizen feedback, ratings, and trends for your assigned department.',
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 14),
                        headerBadge,
                      ],
                    ),
                  const SizedBox(height: 16),
                  _FeedbackFilterCard(
                    searchController: _searchController,
                    selectedDateLabel: _selectedDateLabel,
                    selectedType: _selectedType,
                    selectedOffice: effectiveOffice,
                    selectedBarangay: effectiveBarangay,
                    selectedRating: _selectedRating,
                    dateOptions: _datePresets.keys.toList(),
                    typeOptions: _typeOptions,
                    officeOptions: officeOptions,
                    barangayOptions: barangayOptions,
                    ratingOptions: _ratingOptions,
                    showOfficeFilter: _isSuperAdmin(payload.context.user),
                    onDateChanged: (value) =>
                        _applyFilter(() => _selectedDateLabel = value),
                    onTypeChanged: (value) =>
                        _applyFilter(() => _selectedType = value),
                    onOfficeChanged: (value) =>
                        _applyFilter(() => _selectedOffice = value),
                    onBarangayChanged: (value) =>
                        _applyFilter(() => _selectedBarangay = value),
                    onRatingChanged: (value) =>
                        _applyFilter(() => _selectedRating = value),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _FeedbackMetricCard(
                        width: _metricCardWidth(contentWidth),
                        label: 'Total Feedback',
                        value: '${summary.totalFeedback}',
                        subtitle: 'Matching current filters',
                        color: const Color(0xFF5F92FF),
                        icon: Icons.forum_outlined,
                      ),
                      _FeedbackMetricCard(
                        width: _metricCardWidth(contentWidth),
                        label: 'Average Rating',
                        value: summary.averageRating.toStringAsFixed(1),
                        subtitle: 'Across visible feedback',
                        color: const Color(0xFFF6C54E),
                        icon: Icons.star_rounded,
                      ),
                      _FeedbackMetricCard(
                        width: _metricCardWidth(contentWidth),
                        label: 'Recent Feedback',
                        value: '${summary.recentFeedbackCount}',
                        subtitle: 'Submitted in the last 7 days',
                        color: const Color(0xFF8B5CF6),
                        icon: Icons.schedule_rounded,
                      ),
                      _FeedbackMetricCard(
                        width: _metricCardWidth(contentWidth),
                        label: 'Suggestions',
                        value: '${summary.typeCounts['Suggestion'] ?? 0}',
                        subtitle: 'Constructive input',
                        color: const Color(0xFF38BDF8),
                        icon: Icons.lightbulb_outline_rounded,
                      ),
                      _FeedbackMetricCard(
                        width: _metricCardWidth(contentWidth),
                        label: 'Complaints',
                        value: '${summary.typeCounts['Complaint'] ?? 0}',
                        subtitle: 'Negative experience reports',
                        color: const Color(0xFFEF4444),
                        icon: Icons.report_problem_outlined,
                      ),
                      _FeedbackMetricCard(
                        width: _metricCardWidth(contentWidth),
                        label: 'Praise',
                        value: '${summary.typeCounts['Praise'] ?? 0}',
                        subtitle: 'Positive feedback',
                        color: const Color(0xFF22C55E),
                        icon: Icons.thumb_up_off_alt_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (showWideCharts)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: RepaintBoundary(
                            child: _FeedbackSectionCard(
                              title: 'Feedback Trend',
                              subtitle:
                                  'Grouped over time for the current filters',
                              minContentHeight: 302,
                              child: _FeedbackTrendChart(
                                points: charts.trendBreakdown,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 5,
                          child: RepaintBoundary(
                            child: _FeedbackSectionCard(
                              title: 'Rating Breakdown',
                              subtitle: '1 to 5 star distribution',
                              minContentHeight: 302,
                              child: _FeedbackBreakdownBars(items: ratingItems),
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    RepaintBoundary(
                      child: _FeedbackSectionCard(
                        title: 'Feedback Trend',
                        subtitle: 'Grouped over time for the current filters',
                        minContentHeight: 302,
                        child: _FeedbackTrendChart(
                          points: charts.trendBreakdown,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RepaintBoundary(
                      child: _FeedbackSectionCard(
                        title: 'Rating Breakdown',
                        subtitle: '1 to 5 star distribution',
                        minContentHeight: 302,
                        child: _FeedbackBreakdownBars(items: ratingItems),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  RepaintBoundary(
                    child: _FeedbackTableCard(
                      page: page,
                      isLoading: isLoading,
                      onPrevious: !isLoading && page.hasPreviousPage
                          ? () => _goToPage(page.currentPage - 1)
                          : null,
                      onNext: !isLoading && page.hasNextPage
                          ? () => _goToPage(page.currentPage + 1)
                          : null,
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
      return ColoredBox(color: colors.background, child: body);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text('Feedback'),
      ),
      body: body,
    );
  }

  void _applyFilter(VoidCallback update) {
    setState(() {
      update();
      _page = 1;
      _payloadFuture = _queueLoad();
    });
  }

  double _metricCardWidth(double width) {
    final columns = _metricCardColumns(width);
    if (columns <= 1) {
      return width;
    }

    final totalSpacing = 14.0 * (columns - 1);
    return ((width - totalSpacing) / columns).clamp(220.0, width).toDouble();
  }

  int _metricCardColumns(double width) {
    if (width >= 1120) {
      return 3;
    }
    if (width >= 720) {
      return 2;
    }
    return 1;
  }

}

class _FeedbackContext {
  const _FeedbackContext({required this.user, required this.offices});

  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> offices;
}

class _FeedbackPayload {
  const _FeedbackPayload({
    required this.context,
    required this.summary,
    required this.charts,
    required this.page,
    required this.query,
  });

  final _FeedbackContext context;
  final FeedbackSummaryData summary;
  final FeedbackChartsData charts;
  final FeedbackPage page;
  final _FeedbackQuery query;
}

class _FeedbackFilterCard extends StatelessWidget {
  const _FeedbackFilterCard({
    required this.searchController,
    required this.selectedDateLabel,
    required this.selectedType,
    required this.selectedOffice,
    required this.selectedBarangay,
    required this.selectedRating,
    required this.dateOptions,
    required this.typeOptions,
    required this.officeOptions,
    required this.barangayOptions,
    required this.ratingOptions,
    required this.showOfficeFilter,
    required this.onDateChanged,
    required this.onTypeChanged,
    required this.onOfficeChanged,
    required this.onBarangayChanged,
    required this.onRatingChanged,
  });

  final TextEditingController searchController;
  final String selectedDateLabel;
  final String selectedType;
  final String selectedOffice;
  final String selectedBarangay;
  final String selectedRating;
  final List<String> dateOptions;
  final List<String> typeOptions;
  final List<String> officeOptions;
  final List<String> barangayOptions;
  final List<String> ratingOptions;
  final bool showOfficeFilter;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onOfficeChanged;
  final ValueChanged<String> onBarangayChanged;
  final ValueChanged<String> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final useWrappedFilters = width < 1260;

          double filterWidth(double idealWidth) {
            if (!useWrappedFilters) {
              return idealWidth;
            }
            if (width < 620) {
              return width;
            }
            if (width < 980) {
              return ((width - 12) / 2).clamp(180.0, width).toDouble();
            }
            return idealWidth;
          }

          final filters = [
            _FeedbackDropdown(
              value: selectedDateLabel,
              items: dateOptions,
              width: filterWidth(180),
              onChanged: onDateChanged,
            ),
            _FeedbackDropdown(
              value: selectedType,
              items: typeOptions,
              width: filterWidth(160),
              onChanged: onTypeChanged,
            ),
            if (showOfficeFilter)
              _FeedbackDropdown(
                value: selectedOffice,
                items: officeOptions,
                width: filterWidth(220),
                onChanged: onOfficeChanged,
              ),
            _FeedbackDropdown(
              value: selectedBarangay,
              items: barangayOptions,
              width: filterWidth(220),
              onChanged: onBarangayChanged,
            ),
            _FeedbackDropdown(
              value: selectedRating,
              items: ratingOptions,
              width: filterWidth(150),
              onChanged: onRatingChanged,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: searchController,
                style: TextStyle(color: colors.text),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.mutedText,
                  ),
                  hintText:
                      'Search by feedback ID, report title, message, department, or citizen',
                  hintStyle: TextStyle(color: colors.mutedText),
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
                ),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 12, runSpacing: 12, children: filters),
            ],
          );
        },
      ),
    );
  }
}

class _FeedbackDropdown extends StatelessWidget {
  const _FeedbackDropdown({
    required this.value,
    required this.items,
    required this.width,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final double width;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
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
            horizontal: 12,
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
        ),
        iconEnabledColor: colors.mutedText,
        style: TextStyle(color: colors.text),
        selectedItemBuilder: (context) => items
            .map(
              (item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text),
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
                  style: TextStyle(color: colors.text),
                ),
              ),
            )
            .toList(),
        onChanged: (nextValue) {
          if (nextValue != null) {
            onChanged(nextValue);
          }
        },
      ),
    );
  }
}

class _FeedbackMetricCard extends StatelessWidget {
  const _FeedbackMetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: colors.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSectionCard extends StatelessWidget {
  const _FeedbackSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.minContentHeight,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double? minContentHeight;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: colors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minContentHeight ?? 0),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _FeedbackHeaderBadge extends StatelessWidget {
  const _FeedbackHeaderBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.activeNav,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.mutedText, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackChartSurface extends StatelessWidget {
  const _FeedbackChartSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _FeedbackBreakdownBars extends StatelessWidget {
  const _FeedbackBreakdownBars({
    required this.items,
  });

  final List<FeedbackBreakdownItem> items;

  static const List<Color> _palette = <Color>[
    Color(0xFF5F92FF),
    Color(0xFF8B5CF6),
    Color(0xFFF6C54E),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFF38BDF8),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || items.every((item) => item.count == 0)) {
      return _FeedbackBreakdownPlaceholder(
        labels: items
            .map((item) => item.label.trim())
            .where((label) => label.isNotEmpty)
            .toList(),
      );
    }

    final colors = AdminThemeColors.of(context);
    final maxCount = items.fold<int>(
      1,
      (current, item) => math.max(current, item.count),
    );

    return _FeedbackChartSurface(
      child: SizedBox(
        height: 232,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final color = _palette[index % _palette.length];

            return Row(
              children: [
                SizedBox(
                  width: 116,
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.text),
                  ),
                ),
                const SizedBox(width: 12),
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
                        widthFactor: item.count / maxCount,
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.72), color],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${item.count}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FeedbackTrendChart extends StatelessWidget {
  const _FeedbackTrendChart({required this.points});

  final List<FeedbackTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || points.every((point) => point.count == 0)) {
      return const _FeedbackTrendPlaceholderChart();
    }

    final colors = AdminThemeColors.of(context);
    final maxCount = points.fold<int>(
      1,
      (current, point) => math.max(current, point.count),
    );

    return _FeedbackChartSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: SizedBox(
        height: 232,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pointWidth = points.length >= 10 ? 72.0 : 64.0;
            final chartWidth = math.max(
              constraints.maxWidth,
              points.length * pointWidth,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (index) => Container(
                          height: 1,
                          color: colors.border.withValues(
                            alpha: index == 3 ? 1 : 0.72,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: chartWidth > constraints.maxWidth
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: chartWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: points.map((point) {
                        final height = math.max(
                          16.0,
                          (point.count / maxCount) * 132,
                        );

                        return SizedBox(
                          width: pointWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${point.count}',
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: height,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF7FB6FF),
                                        Color(0xFF2557D6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  point.label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackBreakdownPlaceholder extends StatelessWidget {
  const _FeedbackBreakdownPlaceholder({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final resolvedLabels = labels.take(5).toList();
    while (resolvedLabels.length < 5) {
      resolvedLabels.add('${resolvedLabels.length + 1} Star');
    }

    const widthFactors = <double>[0.82, 0.66, 0.54, 0.42, 0.30];

    return _FeedbackChartSurface(
      child: SizedBox(
        height: 232,
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  resolvedLabels.length,
                  (index) => _FeedbackBreakdownPlaceholderRow(
                    label: resolvedLabels[index],
                    widthFactor: widthFactors[index % widthFactors.length],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const _FeedbackChartMessage(
              title: 'No data available yet',
              message:
                  'Ratings will populate here when feedback matches the current filters.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBreakdownPlaceholderRow extends StatelessWidget {
  const _FeedbackBreakdownPlaceholderRow({
    required this.label,
    required this.widthFactor,
  });

  final String label;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.mutedText),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7FB6FF).withValues(alpha: 0.24),
                        const Color(0xFF2557D6).withValues(alpha: 0.42),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text(
            '0',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: colors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedbackTrendPlaceholderChart extends StatelessWidget {
  const _FeedbackTrendPlaceholderChart();

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    const heights = <double>[40, 78, 56, 92, 68, 86];
    const labels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6'];

    return _FeedbackChartSurface(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: SizedBox(
        height: 232,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          4,
                          (index) => Container(
                            height: 1,
                            color: colors.border.withValues(
                              alpha: index == 3 ? 1 : 0.72,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(
                      heights.length,
                      (index) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '0',
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: heights[index],
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF7FB6FF).withValues(
                                        alpha: 0.32,
                                      ),
                                      const Color(0xFF2557D6).withValues(
                                        alpha: 0.54,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                labels[index],
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _FeedbackChartMessage(
              title: 'No data available yet',
              message:
                  'Trend activity will appear here when feedback matches the current filters.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackChartMessage extends StatelessWidget {
  const _FeedbackChartMessage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.insights_outlined, color: colors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(color: colors.mutedText, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTableCard extends StatelessWidget {
  const _FeedbackTableCard({
    required this.page,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
  });

  final FeedbackPage page;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useCardLayout = constraints.maxWidth < 1040;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Feedback Records',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    page.total == 0
                        ? '0 entries'
                        : 'Showing ${page.from} to ${page.to} of ${page.total}',
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (page.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: _FeedbackEmptyState(
                    title: 'No feedback found',
                    message:
                        'Try adjusting the filters or search terms to see matching feedback.',
                  ),
                )
              else ...[
                if (useCardLayout)
                  Column(
                    children: page.entries
                        .map((entry) => _FeedbackRecordCard(entry: entry))
                        .toList(),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1180),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: colors.border),
                              ),
                            ),
                            child: const Row(
                              children: [
                                _FeedbackHeaderCell('ID', flex: 2),
                                _FeedbackHeaderCell('Type', flex: 2),
                                _FeedbackHeaderCell('Report / Office', flex: 4),
                                _FeedbackHeaderCell('Reporter', flex: 3),
                                _FeedbackHeaderCell('Barangay', flex: 3),
                                _FeedbackHeaderCell('Rating', flex: 2),
                                _FeedbackHeaderCell('Submitted', flex: 2),
                              ],
                            ),
                          ),
                          ...page.entries.map(
                            (entry) => _FeedbackTableRow(entry: entry),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      page.total == 0
                          ? 'No results'
                          : 'Page ${page.currentPage} of ${page.lastPage}',
                      style: TextStyle(color: colors.mutedText, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.activeNav,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${page.currentPage}/${page.lastPage}',
                        style: TextStyle(
                          color: colors.activeText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _PagerButton(label: 'Previous', onTap: onPrevious),
                    _PagerButton(
                      label: isLoading ? 'Loading...' : 'Next',
                      onTap: onNext,
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FeedbackRecordCard extends StatelessWidget {
  const _FeedbackRecordCard({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final report = entry['report'] as Map<String, dynamic>?;
    final office = entry['office'] as Map<String, dynamic>?;
    final user = entry['user'] as Map<String, dynamic>?;
    final message = (entry['message'] ?? '').toString().trim();
    final rating = int.tryParse('${entry['rating'] ?? 0}') ?? 0;
    final createdAt = DateTime.tryParse(
      (entry['created_at'] ?? '').toString(),
    )?.toLocal();
    final reportTitle = (report?['title'] ?? 'General feedback').toString();
    final officeName = (office?['name'] ?? 'Unassigned office').toString();
    final barangay = (report?['barangay'] ?? '-').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.input,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'FDB-${(entry['id'] ?? '').toString().padLeft(4, '0')}',
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              _FeedbackTypePill(type: (entry['type'] ?? '').toString()),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reportTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            officeName,
            style: TextStyle(color: colors.mutedText, fontSize: 12),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.text, height: 1.45),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final detailWidth = constraints.maxWidth < 540
                  ? constraints.maxWidth
                  : ((constraints.maxWidth - 12) / 2)
                        .clamp(180.0, constraints.maxWidth)
                        .toDouble();

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: detailWidth,
                    child: _FeedbackRecordDetail(
                      label: 'Reporter',
                      value:
                          '${(user?['name'] ?? 'Citizen').toString()}\n${(user?['email'] ?? '').toString()}',
                    ),
                  ),
                  SizedBox(
                    width: detailWidth,
                    child: _FeedbackRecordDetail(
                      label: 'Barangay',
                      value: barangay,
                    ),
                  ),
                  SizedBox(
                    width: detailWidth,
                    child: _FeedbackRecordDetail(
                      label: 'Rating',
                      valueWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: index < rating
                                  ? const Color(0xFFF6C54E)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$rating/5',
                            style: TextStyle(color: colors.text),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: detailWidth,
                    child: _FeedbackRecordDetail(
                      label: 'Submitted',
                      value: _FeedbackTableRow.formatDate(createdAt),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedbackTableRow extends StatelessWidget {
  const _FeedbackTableRow({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final report = entry['report'] as Map<String, dynamic>?;
    final office = entry['office'] as Map<String, dynamic>?;
    final user = entry['user'] as Map<String, dynamic>?;
    final rating = int.tryParse('${entry['rating'] ?? 0}') ?? 0;
    final createdAt = DateTime.tryParse(
      (entry['created_at'] ?? '').toString(),
    )?.toLocal();
    final reportTitle = (report?['title'] ?? 'General feedback').toString();
    final officeName = (office?['name'] ?? 'Unassigned office').toString();
    final barangay = (report?['barangay'] ?? '-').toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackBodyCell(
            flex: 2,
            child: Text(
              'FDB-${(entry['id'] ?? '').toString().padLeft(4, '0')}',
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
            ),
          ),
          _FeedbackBodyCell(
            flex: 2,
            child: _FeedbackTypePill(type: (entry['type'] ?? '').toString()),
          ),
          _FeedbackBodyCell(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  officeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          _FeedbackBodyCell(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?['name'] ?? 'Citizen').toString(),
                  style: TextStyle(color: colors.text),
                ),
                const SizedBox(height: 4),
                Text(
                  (user?['email'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          _FeedbackBodyCell(
            flex: 3,
            child: Text(
              barangay,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.mutedText),
            ),
          ),
          _FeedbackBodyCell(
            flex: 2,
            child: Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: index < rating
                      ? const Color(0xFFF6C54E)
                      : const Color(0xFF4B5563),
                ),
              ),
            ),
          ),
          _FeedbackBodyCell(
            flex: 2,
            child: Text(
              formatDate(createdAt),
              style: TextStyle(color: colors.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  static String formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return '${value.month}/${value.day}/${value.year}';
  }
}

class _FeedbackTypePill extends StatelessWidget {
  const _FeedbackTypePill({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final normalized = type.toLowerCase();
    final color = normalized == 'praise'
        ? const Color(0xFF22C55E)
        : normalized == 'complaint'
        ? const Color(0xFFEF4444)
        : const Color(0xFF38BDF8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FeedbackHeaderCell extends StatelessWidget {
  const _FeedbackHeaderCell(this.label, {required this.flex});

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

class _FeedbackBodyCell extends StatelessWidget {
  const _FeedbackBodyCell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: child);
  }
}

class _FeedbackErrorCard extends StatelessWidget {
  const _FeedbackErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load feedback',
            style: TextStyle(
              color: colors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: colors.mutedText)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2557D6),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackStatusBanner extends StatelessWidget {
  const _FeedbackStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF8A5B14).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE9B55A).withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFE9B55A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.text, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEmptyState extends StatelessWidget {
  const _FeedbackEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Column(
      children: [
        const Icon(Icons.forum_outlined, size: 38, color: Color(0xFF7184B7)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.mutedText),
        ),
      ],
    );
  }
}

class _FeedbackRecordDetail extends StatelessWidget {
  const _FeedbackRecordDetail({
    required this.label,
    this.value,
    this.valueWidget,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        valueWidget ??
            Text(
              value ?? '-',
              style: TextStyle(color: colors.text, height: 1.4),
            ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: onTap == null ? colors.panelAlt : colors.input,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null
                ? colors.mutedText.withValues(alpha: 0.45)
                : colors.text,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FeedbackQuery {
  const _FeedbackQuery({
    required this.page,
    required this.perPage,
    required this.search,
    required this.type,
    required this.barangay,
    required this.office,
    required this.rating,
    required this.datePreset,
  });

  final int page;
  final int perPage;
  final String search;
  final String? type;
  final String? barangay;
  final String? office;
  final int? rating;
  final String? datePreset;

  _FeedbackQuery copyWith({
    int? page,
    int? perPage,
    String? search,
    String? type,
    String? barangay,
    String? office,
    int? rating,
    String? datePreset,
  }) {
    return _FeedbackQuery(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      type: type ?? this.type,
      barangay: barangay ?? this.barangay,
      office: office ?? this.office,
      rating: rating ?? this.rating,
      datePreset: datePreset ?? this.datePreset,
    );
  }
}
