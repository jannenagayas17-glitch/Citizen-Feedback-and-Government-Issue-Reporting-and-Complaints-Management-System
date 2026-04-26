import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/file_download.dart';
import '../../utils/tacloban_barangays.dart';

class FeedbackManagementScreen extends StatefulWidget {
  const FeedbackManagementScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FeedbackManagementScreen> createState() =>
      _FeedbackManagementScreenState();
}

enum _FeedbackTone { positive, neutral, negative, dissatisfied }

class _FeedbackBucket {
  const _FeedbackBucket({
    required this.positive,
    required this.neutral,
    required this.negative,
    required this.dissatisfied,
  });

  const _FeedbackBucket.empty()
    : positive = 0,
      neutral = 0,
      negative = 0,
      dissatisfied = 0;

  final int positive;
  final int neutral;
  final int negative;
  final int dissatisfied;

  _FeedbackBucket withTone(_FeedbackTone tone) {
    switch (tone) {
      case _FeedbackTone.positive:
        return _FeedbackBucket(
          positive: positive + 1,
          neutral: neutral,
          negative: negative,
          dissatisfied: dissatisfied,
        );
      case _FeedbackTone.neutral:
        return _FeedbackBucket(
          positive: positive,
          neutral: neutral + 1,
          negative: negative,
          dissatisfied: dissatisfied,
        );
      case _FeedbackTone.negative:
        return _FeedbackBucket(
          positive: positive,
          neutral: neutral,
          negative: negative + 1,
          dissatisfied: dissatisfied,
        );
      case _FeedbackTone.dissatisfied:
        return _FeedbackBucket(
          positive: positive,
          neutral: neutral,
          negative: negative,
          dissatisfied: dissatisfied + 1,
        );
    }
  }
}

class _FeedbackSummary {
  const _FeedbackSummary({
    required this.positiveCount,
    required this.neutralCount,
    required this.negativeCount,
    required this.dissatisfiedCount,
    required this.positiveChange,
    required this.neutralChange,
    required this.negativeChange,
    required this.dissatisfiedChange,
    required this.buckets,
  });

  final int positiveCount;
  final int neutralCount;
  final int negativeCount;
  final int dissatisfiedCount;
  final int positiveChange;
  final int neutralChange;
  final int negativeChange;
  final int dissatisfiedChange;
  final List<_FeedbackBucket> buckets;
}

class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
  final FeedbackService _feedbackService = FeedbackService();

  String _selectedRange = 'Last 30 Days';
  String _selectedType = 'All Feedback';
  String _selectedBarangay = 'All Barangays';
  bool _exporting = false;
  bool _loadingFeedback = true;
  int _page = 1;
  String? _loadError;
  List<Map<String, dynamic>> _feedbackEntries = const [];
  static const int _pageSize = 8;

  static const Map<String, int?> _rangeDays = <String, int?>{
    'Last 7 Days': 7,
    'Last 30 Days': 30,
    'Last 90 Days': 90,
    'All Time': null,
  };

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<List<Map<String, dynamic>>> _loadFeedback() async {
    final rangeDays = _rangeDays[_selectedRange];
    final entries = await _feedbackService
        .getFeedbackEntries(
          days: rangeDays == null ? null : rangeDays * 2,
          type: _selectedType,
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception(
            'Feedback request timed out. Please try again.',
          ),
        );
    if (!mounted) {
      return entries;
    }
    setState(() {
      _feedbackEntries = entries;
      _loadError = null;
    });
    return entries;
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _loadingFeedback = true;
      _loadError = null;
    });
    try {
      await _loadFeedback();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loadingFeedback = false);
      }
    }
  }

  Future<void> _exportFeedback() async {
    setState(() => _exporting = true);
    try {
      final file = await _feedbackService.exportFeedback(
        days: _rangeDays[_selectedRange],
        type: _selectedType,
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
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final entries = _feedbackEntries;
    final barangays = _barangayOptions(entries);
    final effectiveBarangay = barangays.contains(_selectedBarangay)
        ? _selectedBarangay
        : 'All Barangays';
    if (effectiveBarangay != _selectedBarangay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedBarangay = effectiveBarangay);
        }
      });
    }
    final barangayScopedEntries = _filterByBarangay(
      entries,
      selectedBarangay: effectiveBarangay,
    );
    final filteredEntries = _filterByCurrentRange(barangayScopedEntries);
    final summary = _buildSummary(barangayScopedEntries);
    final totalPages = math.max(1, (filteredEntries.length / _pageSize).ceil());
    final currentPage = _page.clamp(1, totalPages);
    final startIndex = filteredEntries.isEmpty ? 0 : (currentPage - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, filteredEntries.length);
    final pagedEntries = filteredEntries.sublist(startIndex, endIndex);
    final isWide = MediaQuery.of(context).size.width >= 1180;

    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          widget.embedded ? 0 : 24,
          widget.embedded ? 0 : 20,
          widget.embedded ? 0 : 24,
          28,
        ),
        children: [
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
                      'View and manage feedback submitted by citizens regarding their reports.',
                      style: TextStyle(color: colors.mutedText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (isWide)
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportFeedback,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF294FCF),
                    foregroundColor: Colors.white,
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
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _FeedbackDropdown(
                    value: _selectedRange,
                    items: _rangeDays.keys.toList(),
                    onChanged: (value) {
                      setState(() {
                        _page = 1;
                        _selectedRange = value;
                      });
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeedbackDropdown(
                    value: _selectedType,
                    items: const <String>[
                      'All Feedback',
                      'Praise',
                      'Suggestion',
                      'Complaint',
                    ],
                    onChanged: (value) {
                      setState(() {
                        _page = 1;
                        _selectedType = value;
                      });
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeedbackDropdown(
                    value: effectiveBarangay,
                    items: barangays,
                    onChanged: (value) {
                      setState(() {
                        _page = 1;
                        _selectedBarangay = value;
                      });
                    },
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FeedbackDropdown(
                  value: _selectedRange,
                  items: _rangeDays.keys.toList(),
                  onChanged: (value) {
                    setState(() {
                      _page = 1;
                      _selectedRange = value;
                    });
                    _refresh();
                  },
                ),
                _FeedbackDropdown(
                  value: _selectedType,
                  items: const <String>[
                    'All Feedback',
                    'Praise',
                    'Suggestion',
                    'Complaint',
                  ],
                  onChanged: (value) {
                    setState(() {
                      _page = 1;
                      _selectedType = value;
                    });
                    _refresh();
                  },
                ),
                _FeedbackDropdown(
                  value: effectiveBarangay,
                  items: barangays,
                  onChanged: (value) {
                    setState(() {
                      _page = 1;
                      _selectedBarangay = value;
                    });
                  },
                ),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportFeedback,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF294FCF),
                    foregroundColor: Colors.white,
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
                      : const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(_exporting ? 'Exporting...' : 'Export CSV'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          if (_loadError != null) ...[
            _FeedbackInlineNotice(
              title: entries.isEmpty
                  ? 'Unable to load feedback right now'
                  : 'Showing the latest loaded feedback',
              message: _loadError!,
              isError: true,
            ),
            const SizedBox(height: 16),
          ] else if (_loadingFeedback && entries.isNotEmpty) ...[
            const _FeedbackInlineNotice(
              title: 'Refreshing feedback',
              message: 'Updating the latest feedback entries in the background.',
            ),
            const SizedBox(height: 16),
          ],
          if (_loadingFeedback && entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: _FeedbackEmptyState(
                  title: 'No feedback yet',
                  message:
                      'Citizen feedback will appear here once reports receive comments and ratings.',
                ),
              ),
            )
          else ...[
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FeedbackSummaryCard(
                      label: 'Positive Feedback',
                      value: summary.positiveCount.toString(),
                      delta:
                          '${summary.positiveChange >= 0 ? '+' : ''}${summary.positiveChange}%',
                      color: const Color(0xFF67D8A2),
                      icon: Icons.sentiment_very_satisfied_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeedbackSummaryCard(
                      label: 'Neutral Feedback',
                      value: summary.neutralCount.toString(),
                      delta:
                          '${summary.neutralChange >= 0 ? '+' : ''}${summary.neutralChange}%',
                      color: const Color(0xFFE5B15F),
                      icon: Icons.sentiment_neutral_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeedbackSummaryCard(
                      label: 'Negative Feedback',
                      value: summary.negativeCount.toString(),
                      delta:
                          '${summary.negativeChange >= 0 ? '+' : ''}${summary.negativeChange}%',
                      color: const Color(0xFFE57A7A),
                      icon: Icons.sentiment_dissatisfied_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FeedbackSummaryCard(
                      label: 'Dissatisfied Feedback',
                      value: summary.dissatisfiedCount.toString(),
                      delta:
                          '${summary.dissatisfiedChange >= 0 ? '+' : ''}${summary.dissatisfiedChange}%',
                      color: const Color(0xFFF05B5B),
                      icon: Icons.sentiment_very_dissatisfied_rounded,
                    ),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FeedbackSummaryCard(
                    label: 'Positive Feedback',
                    value: summary.positiveCount.toString(),
                    delta:
                        '${summary.positiveChange >= 0 ? '+' : ''}${summary.positiveChange}%',
                    color: const Color(0xFF67D8A2),
                    icon: Icons.sentiment_very_satisfied_rounded,
                  ),
                  _FeedbackSummaryCard(
                    label: 'Neutral Feedback',
                    value: summary.neutralCount.toString(),
                    delta:
                        '${summary.neutralChange >= 0 ? '+' : ''}${summary.neutralChange}%',
                    color: const Color(0xFFE5B15F),
                    icon: Icons.sentiment_neutral_rounded,
                  ),
                  _FeedbackSummaryCard(
                    label: 'Negative Feedback',
                    value: summary.negativeCount.toString(),
                    delta:
                        '${summary.negativeChange >= 0 ? '+' : ''}${summary.negativeChange}%',
                    color: const Color(0xFFE57A7A),
                    icon: Icons.sentiment_dissatisfied_rounded,
                  ),
                  _FeedbackSummaryCard(
                    label: 'Dissatisfied Feedback',
                    value: summary.dissatisfiedCount.toString(),
                    delta:
                        '${summary.dissatisfiedChange >= 0 ? '+' : ''}${summary.dissatisfiedChange}%',
                    color: const Color(0xFFF05B5B),
                    icon: Icons.sentiment_very_dissatisfied_rounded,
                  ),
                ],
              ),
            const SizedBox(height: 16),
            _FeedbackOverviewCard(
              selectedRange: _selectedRange,
              summary: summary,
              totalEntries: filteredEntries.length,
            ),
            const SizedBox(height: 16),
            _FeedbackTable(
              entries: pagedEntries,
              totalEntries: filteredEntries.length,
              page: currentPage,
              pageSize: _pageSize,
              totalPages: totalPages,
              onPrevious: currentPage > 1
                  ? () => setState(() => _page = currentPage - 1)
                  : null,
              onNext: currentPage < totalPages
                  ? () => setState(() => _page = currentPage + 1)
                  : null,
            ),
          ],
        ],
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
        title: const Text('Feedback'),
      ),
      body: body,
    );
  }

  List<String> _barangayOptions(List<Map<String, dynamic>> entries) {
    final values = <String, String>{};
    void addValue(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      values.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }

    for (final barangay in taclobanBarangays) {
      addValue(barangay);
    }

    for (final entry in entries) {
      final report = entry['report'];
      if (report is Map<String, dynamic>) {
        addValue((report['barangay'] ?? '').toString());
      }
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

  bool _matchesBarangay(String reportBarangay, String selectedBarangay) {
    if (reportBarangay.trim().toLowerCase() ==
        selectedBarangay.trim().toLowerCase()) {
      return true;
    }

    final reportNumber = _barangayNumber(reportBarangay);
    final selectedNumber = _barangayNumber(selectedBarangay);
    return reportNumber != null &&
        selectedNumber != null &&
        reportNumber == selectedNumber;
  }

  List<Map<String, dynamic>> _filterByCurrentRange(
    List<Map<String, dynamic>> entries,
  ) {
    final days = _rangeDays[_selectedRange];
    if (days == null) {
      return entries;
    }

    final start = DateTime.now().subtract(Duration(days: days));
    return entries.where((entry) {
      final createdAt = DateTime.tryParse(
        (entry['created_at'] ?? '').toString(),
      );
      return createdAt != null && !createdAt.isBefore(start);
    }).toList();
  }

  List<Map<String, dynamic>> _filterByBarangay(
    List<Map<String, dynamic>> entries, {
    required String selectedBarangay,
  }) {
    if (selectedBarangay == 'All Barangays') {
      return entries;
    }

    return entries.where((entry) {
      final report = entry['report'];
      if (report is! Map<String, dynamic>) {
        return false;
      }
      return _matchesBarangay(
        (report['barangay'] ?? '').toString(),
        selectedBarangay,
      );
    }).toList();
  }

  _FeedbackSummary _buildSummary(List<Map<String, dynamic>> entries) {
    final now = DateTime.now();
    final currentDays =
        _rangeDays[_selectedRange] ?? _allTimeWindow(entries, now);
    final currentStart = now.subtract(Duration(days: currentDays));
    final previousStart = currentStart.subtract(Duration(days: currentDays));

    int currentPositive = 0;
    int currentNeutral = 0;
    int currentNegative = 0;
    int currentDissatisfied = 0;
    int previousPositive = 0;
    int previousNeutral = 0;
    int previousNegative = 0;
    int previousDissatisfied = 0;
    final buckets = List.generate(
      currentDays,
      (_) => const _FeedbackBucket.empty(),
    );

    for (final entry in entries) {
      final createdAt = DateTime.tryParse(
        (entry['created_at'] ?? '').toString(),
      );
      if (createdAt == null) {
        continue;
      }

      final tone = _tone(entry);
      if (!createdAt.isBefore(currentStart)) {
        switch (tone) {
          case _FeedbackTone.positive:
            currentPositive++;
            break;
          case _FeedbackTone.neutral:
            currentNeutral++;
            break;
          case _FeedbackTone.negative:
            currentNegative++;
            break;
          case _FeedbackTone.dissatisfied:
            currentDissatisfied++;
            break;
        }

        final diff = now.difference(createdAt).inDays;
        final index = currentDays - diff - 1;
        if (index >= 0 && index < buckets.length) {
          buckets[index] = buckets[index].withTone(tone);
        }
      } else if (!createdAt.isBefore(previousStart)) {
        switch (tone) {
          case _FeedbackTone.positive:
            previousPositive++;
            break;
          case _FeedbackTone.neutral:
            previousNeutral++;
            break;
          case _FeedbackTone.negative:
            previousNegative++;
            break;
          case _FeedbackTone.dissatisfied:
            previousDissatisfied++;
            break;
        }
      }
    }

    return _FeedbackSummary(
      positiveCount: currentPositive,
      neutralCount: currentNeutral,
      negativeCount: currentNegative,
      dissatisfiedCount: currentDissatisfied,
      positiveChange: _delta(currentPositive, previousPositive),
      neutralChange: _delta(currentNeutral, previousNeutral),
      negativeChange: _delta(currentNegative, previousNegative),
      dissatisfiedChange: _delta(currentDissatisfied, previousDissatisfied),
      buckets: buckets,
    );
  }

  int _delta(int current, int previous) {
    if (previous == 0) {
      return current == 0 ? 0 : 100;
    }
    return (((current - previous) / previous) * 100).round();
  }

  _FeedbackTone _tone(Map<String, dynamic> entry) {
    final rating = int.tryParse('${entry['rating'] ?? 0}') ?? 0;
    final type = (entry['type'] ?? '').toString();

    if (rating <= 1) return _FeedbackTone.dissatisfied;
    if (rating == 2) return _FeedbackTone.negative;
    if (type == 'Complaint' && rating <= 3) return _FeedbackTone.negative;
    if (rating == 3) return _FeedbackTone.neutral;
    return _FeedbackTone.positive;
  }

  int _allTimeWindow(List<Map<String, dynamic>> entries, DateTime now) {
    DateTime? oldest;
    for (final entry in entries) {
      final createdAt = DateTime.tryParse(
        (entry['created_at'] ?? '').toString(),
      );
      if (createdAt == null) {
        continue;
      }
      if (oldest == null || createdAt.isBefore(oldest)) {
        oldest = createdAt;
      }
    }

    if (oldest == null) {
      return 30;
    }

    return math.max(30, now.difference(oldest).inDays + 1);
  }
}

class _FeedbackDropdown extends StatelessWidget {
  const _FeedbackDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 360,
          dropdownColor: colors.panel,
          style: TextStyle(color: colors.text),
          iconEnabledColor: colors.mutedText,
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
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

class _FeedbackSummaryCard extends StatelessWidget {
  const _FeedbackSummaryCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String delta;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 152),
      padding: const EdgeInsets.all(18),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(icon, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: delta,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: '  from last period',
                  style: TextStyle(color: colors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackOverviewCard extends StatelessWidget {
  const _FeedbackOverviewCard({
    required this.selectedRange,
    required this.summary,
    required this.totalEntries,
  });

  final String selectedRange;
  final _FeedbackSummary summary;
  final int totalEntries;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Feedback Overview',
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  selectedRange,
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              child: _FeedbackTrendChart(summary: summary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(
              children: [
                const Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _FeedbackLegend(
                        label: 'Positive Feedback',
                        color: Color(0xFF67D8A2),
                      ),
                      _FeedbackLegend(
                        label: 'Neutral Feedback',
                        color: Color(0xFFE5B15F),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$totalEntries Reports',
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTrendChart extends StatelessWidget {
  const _FeedbackTrendChart({required this.summary});

  final _FeedbackSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return CustomPaint(
      painter: _FeedbackTrendPainter(summary, gridColor: colors.border),
      child: Container(),
    );
  }
}

class _FeedbackTrendPainter extends CustomPainter {
  const _FeedbackTrendPainter(this.summary, {required this.gridColor});

  final _FeedbackSummary summary;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawSeries(
      canvas,
      size,
      summary.buckets.map((bucket) => bucket.positive.toDouble()).toList(),
      const Color(0xFF67D8A2),
    );
    _drawSeries(
      canvas,
      size,
      summary.buckets.map((bucket) => bucket.neutral.toDouble()).toList(),
      const Color(0xFFE5B15F),
    );
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, Color color) {
    if (values.isEmpty) {
      return;
    }

    final maxValue = math.max<double>(
      1,
      values.fold<double>(0, (current, value) => math.max(current, value)),
    );
    final path = Path();

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? 0.0
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / maxValue) * (size.height - 12)) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? 0.0
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / maxValue) * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 2.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FeedbackTrendPainter oldDelegate) {
    return oldDelegate.summary != summary || oldDelegate.gridColor != gridColor;
  }
}

class _FeedbackLegend extends StatelessWidget {
  const _FeedbackLegend({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FeedbackTable extends StatelessWidget {
  const _FeedbackTable({
    required this.entries,
    required this.totalEntries,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final List<Map<String, dynamic>> entries;
  final int totalEntries;
  final int page;
  final int pageSize;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(34),
              child: _FeedbackEmptyState(
                title: 'No feedback found yet',
                message:
                    'Citizen feedback will appear here after residents submit ratings, suggestions, or complaints.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing ${((page - 1) * pageSize) + 1} to ${math.min(page * pageSize, totalEntries)} of $totalEntries entries',
                      style: TextStyle(color: colors.mutedText, fontSize: 13),
                    ),
                  ),
                  _PagerButton(label: 'Previous', onTap: onPrevious),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.activeNav,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      '$page',
                      style: TextStyle(
                        color: colors.activeText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PagerButton(label: 'Next', onTap: onNext),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1180),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _FeedbackTableLabel('ID', flex: 2),
                          _FeedbackTableLabel('Report Title', flex: 4),
                          _FeedbackTableLabel('Reporter', flex: 3),
                          _FeedbackTableLabel('Barangay', flex: 2),
                          _FeedbackTableLabel('Status', flex: 2),
                          _FeedbackTableLabel('Feedback', flex: 5),
                          _FeedbackTableLabel('Rating', flex: 2),
                          _FeedbackTableLabel('Date', flex: 2),
                        ],
                      ),
                    ),
                    ...entries.map((entry) => _FeedbackTableRow(entry: entry)),
                  ],
                ),
              ),
            ),
          ],
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
    final user = entry['user'] as Map<String, dynamic>?;
    final office = entry['office'] as Map<String, dynamic>?;
    final title = (report?['title'] ?? office?['name'] ?? 'General Feedback')
        .toString();
    final barangay = (report?['barangay'] ?? '-').toString();
    final status = (report?['status'] ?? 'General').toString();
    final feedbackText = (entry['message'] ?? '').toString();
    final rating = int.tryParse('${entry['rating'] ?? 0}') ?? 0;
    final date = DateTime.tryParse(
      (entry['created_at'] ?? '').toString(),
    )?.toLocal();
    final reportTracking =
        (report?['tracking_number'] ?? report?['tracking_id'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackTableCell(
            flex: 2,
            child: Text(
              reportTracking.isNotEmpty
                  ? reportTracking
                  : 'FDB-${(entry['id'] ?? '').toString().padLeft(4, '0')}',
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
            ),
          ),
          _FeedbackTableCell(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (office?['name'] ?? 'Department').toString(),
                  style: TextStyle(color: colors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
          _FeedbackTableCell(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?['name'] ?? 'Citizen').toString(),
                  style: TextStyle(color: colors.text),
                ),
                if ((user?['email'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    (user?['email'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.mutedText, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          _FeedbackTableCell(
            flex: 2,
            child: Text(barangay, style: TextStyle(color: colors.mutedText)),
          ),
          _FeedbackTableCell(flex: 2, child: _MiniStatusChip(status: status)),
          _FeedbackTableCell(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                feedbackText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.text),
              ),
            ),
          ),
          _FeedbackTableCell(
            flex: 2,
            child: Row(
              children: List.generate(
                5,
                (index) => Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: index < rating
                      ? const Color(0xFFF6C54E)
                      : const Color(0xFF4B4258),
                ),
              ),
            ),
          ),
          _FeedbackTableCell(
            flex: 2,
            child: Text(
              _dateLabel(date),
              style: TextStyle(color: colors.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return '-';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) {
      return '${math.max(1, diff.inMinutes)} minutes ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _FeedbackTableLabel extends StatelessWidget {
  const _FeedbackTableLabel(this.text, {required this.flex});

  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeedbackTableCell extends StatelessWidget {
  const _FeedbackTableCell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(flex: flex, child: child);
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final color = lower.contains('resolved')
        ? const Color(0xFF67D8A2)
        : lower.contains('progress')
        ? const Color(0xFF5F92FF)
        : lower.contains('pending')
        ? const Color(0xFFE5B15F)
        : lower.contains('reject')
        ? const Color(0xFFE57A7A)
        : const Color(0xFF8E96B2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FeedbackInlineNotice extends StatelessWidget {
  const _FeedbackInlineNotice({
    required this.title,
    required this.message,
    this.isError = false,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final accent = isError ? const Color(0xFFE57A7A) : const Color(0xFF5F92FF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isError ? Icons.error_outline : Icons.sync,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: colors.mutedText, fontSize: 13),
                ),
              ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
