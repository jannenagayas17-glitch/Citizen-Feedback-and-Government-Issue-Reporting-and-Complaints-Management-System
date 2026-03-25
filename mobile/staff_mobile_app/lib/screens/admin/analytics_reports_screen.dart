import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/dashboard_service.dart';
import '../../services/report_service.dart';
import '../../utils/file_download.dart';

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ReportService _reportService = ReportService();

  late Future<Map<String, dynamic>> _analyticsFuture;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _dashboardService.getAnalytics();
  }

  Future<void> _refresh() async {
    final future = _dashboardService.getAnalytics();
    setState(() {
      _analyticsFuture = future;
    });
    await future;
  }

  Future<void> _exportReports() async {
    setState(() {
      _exporting = true;
    });

    try {
      final file = await _reportService.exportAdminReports();
      await downloadFile(
        bytes: file.bytes,
        fileName: file.fileName,
        mimeType: file.mimeType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${file.fileName} successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Analytics & Reports'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _exporting ? null : _exportReports,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              icon: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_exporting ? 'Exporting...' : 'Export Excel-ready CSV'),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1A2940),
              Color(0xFF463327),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _GlassPanel(
                      child: _SectionHeader(
                        title: 'Unable to load analytics',
                        subtitle: snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      ),
                    ),
                  ],
                );
              }

              final analytics = snapshot.data ?? const <String, dynamic>{};
              final overview =
                  (analytics['overview'] as Map<String, dynamic>?) ??
                      const <String, dynamic>{};
              final statuses =
                  (analytics['status_breakdown'] as List<dynamic>? ?? const []);
              final priorities =
                  (analytics['priority_breakdown'] as List<dynamic>? ?? const []);
              final categories =
                  (analytics['category_breakdown'] as List<dynamic>? ?? const []);
              final locations =
                  (analytics['location_breakdown'] as List<dynamic>? ?? const []);
              final monthly =
                  (analytics['monthly_trend'] as List<dynamic>? ?? const []);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1100;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      28 + bottomSafeArea,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            children: [
                              _AnalyticsHeroCard(
                                generatedAt:
                                    (analytics['generated_at'] ?? '').toString(),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _StatCard(
                                    label: 'Total reports',
                                    value:
                                        '${overview['total_reports'] ?? 0}',
                                    color: const Color(0xFF60A5FA),
                                    icon: Icons.assignment_outlined,
                                  ),
                                  _StatCard(
                                    label: 'New',
                                    value: '${overview['new'] ?? 0}',
                                    color: const Color(0xFF94A3B8),
                                    icon: Icons.fiber_new_rounded,
                                  ),
                                  _StatCard(
                                    label: 'Pending',
                                    value: '${overview['pending'] ?? 0}',
                                    color: const Color(0xFFF59E0B),
                                    icon: Icons.hourglass_top_rounded,
                                  ),
                                  _StatCard(
                                    label: 'In progress',
                                    value:
                                        '${overview['in_progress'] ?? 0}',
                                    color: const Color(0xFF8B5CF6),
                                    icon: Icons.construction_rounded,
                                  ),
                                  _StatCard(
                                    label: 'Resolved',
                                    value: '${overview['resolved'] ?? 0}',
                                    color: const Color(0xFF22C55E),
                                    icon: Icons.task_alt_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _BreakdownPanel(
                                        title: 'Status overview',
                                        subtitle:
                                            'Track current workload by report state.',
                                        items: statuses,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _BreakdownPanel(
                                        title: 'Priority overview',
                                        subtitle:
                                            'See which reports need faster action.',
                                        items: priorities,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _BreakdownPanel(
                                  title: 'Status overview',
                                  subtitle:
                                      'Track current workload by report state.',
                                  items: statuses,
                                ),
                                const SizedBox(height: 16),
                                _BreakdownPanel(
                                  title: 'Priority overview',
                                  subtitle:
                                      'See which reports need faster action.',
                                  items: priorities,
                                ),
                              ],
                              const SizedBox(height: 16),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _BreakdownPanel(
                                        title: 'Top categories',
                                        subtitle:
                                            'The issue types citizens raise most often.',
                                        items: categories,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _BreakdownPanel(
                                        title: 'Location hotspots',
                                        subtitle:
                                            'Areas receiving the highest complaint volume.',
                                        items: locations,
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                _BreakdownPanel(
                                  title: 'Top categories',
                                  subtitle:
                                      'The issue types citizens raise most often.',
                                  items: categories,
                                ),
                                const SizedBox(height: 16),
                                _BreakdownPanel(
                                  title: 'Location hotspots',
                                  subtitle:
                                      'Areas receiving the highest complaint volume.',
                                  items: locations,
                                ),
                              ],
                              const SizedBox(height: 16),
                              _TrendPanel(items: monthly),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  const _AnalyticsHeroCard({
    required this.generatedAt,
  });

  final String generatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF2563EB),
            Color(0xFF0F172A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.14),
              border: Border.all(
                color: const Color(0xFFD8B15A),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Engineering analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use this command view to spot trends, monitor workload, and download an Excel-ready report file for weekly or monthly reviews.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    height: 1.45,
                  ),
                ),
                if (generatedAt.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Generated: $generatedAt',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      child: _GlassPanel(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
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
}

class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.isEmpty
        ? 1
        : items
            .map((item) => ((item as Map<String, dynamic>)['count'] ?? 0) as num)
            .fold<num>(1, math.max)
            .toDouble();

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'No data available yet.',
              style: TextStyle(color: Colors.white.withOpacity(0.70)),
            )
          else
            ...items.map((item) {
              final record = item as Map<String, dynamic>;
              final label = (record['label'] ?? 'Unknown').toString();
              final count = ((record['count'] ?? 0) as num).toDouble();
              final ratio = maxCount == 0 ? 0.0 : count / maxCount;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          count.toInt().toString(),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: ratio.clamp(0, 1),
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF60A5FA)),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.items,
  });

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final maxCount = items.isEmpty
        ? 1
        : items
            .map((item) => ((item as Map<String, dynamic>)['count'] ?? 0) as num)
            .fold<num>(1, math.max)
            .toDouble();

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Monthly report volume',
            subtitle: 'Quick trend view for the last six months.',
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Text(
              'No monthly trend data available yet.',
              style: TextStyle(color: Colors.white.withOpacity(0.70)),
            )
          else
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map((item) {
                  final record = item as Map<String, dynamic>;
                  final label = (record['label'] ?? '').toString();
                  final count = ((record['count'] ?? 0) as num).toDouble();
                  final barHeight = maxCount == 0 ? 0.0 : (count / maxCount) * 150;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            count.toInt().toString(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.74),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: barHeight.clamp(6, 150),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF60A5FA),
                                  Color(0xFF2563EB),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: child,
    );
  }
}
