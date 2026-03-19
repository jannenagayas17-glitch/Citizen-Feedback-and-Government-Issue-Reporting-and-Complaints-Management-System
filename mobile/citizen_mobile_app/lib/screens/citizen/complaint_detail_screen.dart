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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGlassSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        label: 'Status',
                        value: (report['status'] ?? 'Pending').toString(),
                      ),
                      _DetailRow(
                        label: 'Category',
                        value: ((report['category'] as Map<String, dynamic>?)?['name'] ??
                                'Uncategorized')
                            .toString(),
                      ),
                      _DetailRow(
                        label: 'Location',
                        value: (report['location'] ?? 'No location').toString(),
                      ),
                      _DetailRow(
                        label: 'Submitted By',
                        value: ((report['user'] as Map<String, dynamic>?)?['name'] ??
                                'Unknown')
                            .toString(),
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
                          height: 120,
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
                                  width: 150,
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
                const Text(
                  'Status History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (statusHistories.isEmpty)
                  Text(
                    'No status updates yet.',
                    style: TextStyle(color: Colors.white.withOpacity(0.72)),
                  )
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
                const Text(
                  'Admin Responses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (adminResponses.isEmpty)
                  Text(
                    'No admin responses yet.',
                    style: TextStyle(color: Colors.white.withOpacity(0.72)),
                  )
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white.withOpacity(0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
      ),
    );
  }
}
