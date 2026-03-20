import 'dart:ui';

import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../services/report_service.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.reportId,
  });

  final int reportId;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final ReportService _reportService = ReportService();
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _reportService.getReportDetail(widget.reportId);
  }

  Future<void> _refresh() async {
    final future = _reportService.getReportDetail(widget.reportId);
    setState(() => _detailFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1E293B),
              Color(0xFF463327),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<Map<String, dynamic>>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );
            }

            final report = snapshot.data ?? const <String, dynamic>{};
            final statusHistories = (report['status_histories'] as List<dynamic>? ??
                report['statusHistories'] as List<dynamic>? ??
                const []);
            final adminResponses = (report['admin_responses'] as List<dynamic>? ??
                report['adminResponses'] as List<dynamic>? ??
                const []);
            final images = (report['images'] as List<dynamic>? ?? const []);
            final categoryName =
                ((report['category'] as Map<String, dynamic>?)?['name'] ??
                        'Uncategorized')
                    .toString();
            final status = (report['status'] ?? 'Pending').toString();
            final submittedBy =
                ((report['user'] as Map<String, dynamic>?)?['name'] ?? 'Unknown')
                    .toString();
            final location = (report['location'] ?? 'No location').toString();
            final createdAt = (report['created_at'] ?? '').toString();

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                _buildGlassSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoBadge(
                            label: status,
                            color: _statusColor(status),
                            icon: Icons.flag_outlined,
                          ),
                          _InfoBadge(
                            label: categoryName,
                            color: _categoryColor(categoryName),
                            icon: _categoryIcon(categoryName),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        (report['title'] ?? 'Untitled report').toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Location',
                        value: location,
                      ),
                      _DetailRow(
                        label: 'Submitted by',
                        value: submittedBy,
                      ),
                      _DetailRow(
                        label: 'Date created',
                        value: createdAt.isEmpty ? 'Not available' : createdAt.substring(0, 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildGlassSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (report['description'] ?? 'No description').toString(),
                        style: TextStyle(color: Colors.white.withOpacity(0.78)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildGlassSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uploaded Images',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (images.isEmpty)
                        Text(
                          'No images uploaded for this report.',
                          style: TextStyle(color: Colors.white.withOpacity(0.72)),
                        )
                      else
                        SizedBox(
                          height: 148,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final image = images[index] as Map<String, dynamic>;
                              final imageUrl = _buildImageUrl(
                                (image['image_path'] ?? '').toString(),
                              );

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 180,
                                  color: Colors.white.withOpacity(0.10),
                                  child: imageUrl == null
                                      ? Center(
                                          child: Text(
                                            'Invalid image path',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.72),
                                            ),
                                          ),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return const Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            );
                                          },
                                          errorBuilder: (_, __, ___) {
                                            return Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Text(
                                                  'Unable to load image',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.72),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Status History'),
                const SizedBox(height: 8),
                if (statusHistories.isEmpty)
                  _buildEmptyMessage('No status updates yet.')
                else
                  ...statusHistories.map(
                    (item) => _TimelineCard(
                      title:
                          '${item['old_status'] ?? 'Unspecified'} -> ${item['new_status'] ?? 'Pending'}',
                      subtitle: ((item['user'] as Map<String, dynamic>?)?['name'] ??
                              'System')
                          .toString(),
                      details: (item['remarks'] ?? 'No remarks').toString(),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildSectionTitle('Admin Responses'),
                const SizedBox(height: 8),
                if (adminResponses.isEmpty)
                  _buildEmptyMessage('No admin responses yet.')
                else
                  ...adminResponses.map(
                    (item) => _TimelineCard(
                      title: ((item['user'] as Map<String, dynamic>?)?['name'] ??
                              'Admin')
                          .toString(),
                      subtitle: 'Official update',
                      details: (item['response'] ?? '').toString(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  String? _buildImageUrl(String imagePath) {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    var normalizedPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    if (normalizedPath.startsWith('public/')) {
      normalizedPath = normalizedPath.substring('public/'.length);
    }
    if (normalizedPath.startsWith('storage/')) {
      normalizedPath = normalizedPath.substring('storage/'.length);
    }

    return baseUri
        .replace(
          path: '/api/report-images/$normalizedPath',
          queryParameters: null,
          fragment: null,
        )
        .toString();
  }

  Widget _buildGlassSection({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.08),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.white.withOpacity(0.72)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF69DB7C);
      case 'In Progress':
        return const Color(0xFFFFC078);
      case 'Pending':
        return const Color(0xFF74C0FC);
      case 'New':
        return const Color(0xFFE599F7);
      default:
        return Colors.white70;
    }
  }

  IconData _categoryIcon(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('road')) return Icons.construction;
    if (normalized.contains('water')) return Icons.water_drop;
    if (normalized.contains('electric')) return Icons.bolt;
    if (normalized.contains('waste')) return Icons.delete_outline;
    return Icons.report_problem_outlined;
  }

  Color _categoryColor(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('road')) return const Color(0xFFFF8A65);
    if (normalized.contains('water')) return const Color(0xFF4FC3F7);
    if (normalized.contains('electric')) return const Color(0xFFFFD54F);
    if (normalized.contains('waste')) return const Color(0xFFA5D6A7);
    return const Color(0xFFD8B15A);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final String title;
  final String subtitle;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.62)),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: TextStyle(color: Colors.white.withOpacity(0.78)),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
