import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/report_feedback_service.dart';
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
  int? _selectedRating;
  bool _isSavingRating = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    final detail = await _reportService.getReportDetail(widget.reportId);
    final savedRating =
        await ReportFeedbackService.getRatingForReport(widget.reportId);
    if (mounted) {
      setState(() {
        _selectedRating = savedRating;
      });
    } else {
      _selectedRating = savedRating;
    }
    return detail;
  }

  Future<void> _refresh() async {
    final future = _loadDetail();
    setState(() {
      _detailFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        title: const Text('Complaint Tracker'),
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
              final statusHistories =
                  (report['status_histories'] as List<dynamic>? ??
                      report['statusHistories'] as List<dynamic>? ??
                      const []);
              final adminResponses =
                  (report['admin_responses'] as List<dynamic>? ??
                      report['adminResponses'] as List<dynamic>? ??
                      const []);
              final attachments = (report['images'] as List<dynamic>? ?? const []);
              final categoryName =
                  ((report['category'] as Map<String, dynamic>?)?['name'] ??
                          'Uncategorized')
                      .toString();
              final officeName =
                  ((report['office'] as Map<String, dynamic>?)?['name'] ??
                          'Unassigned office')
                      .toString();
              final rawStatus = (report['status'] ?? 'New').toString();
              final status = _normalizedStatus(rawStatus);
              final submittedBy =
                  ((report['user'] as Map<String, dynamic>?)?['name'] ?? 'Unknown')
                      .toString();
              final location = (report['location'] ?? 'No location').toString();
              final barangay = (report['barangay'] ?? '').toString();
              final createdAt = (report['created_at'] ?? '').toString();
              final latitude = (report['latitude'] ?? '').toString();
              final longitude = (report['longitude'] ?? '').toString();
              final trackingId =
                  ReportFeedbackService.buildTrackingId(widget.reportId);

              return ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSafeArea + 24),
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
                              label: trackingId,
                              color: const Color(0xFF2563EB),
                              icon: Icons.tag_outlined,
                            ),
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
                        _DetailRow(label: 'Office', value: officeName),
                        _DetailRow(label: 'Location', value: location),
                        if (barangay.isNotEmpty)
                          _DetailRow(label: 'Barangay', value: barangay),
                        _DetailRow(label: 'Submitted by', value: submittedBy),
                        _DetailRow(
                          label: 'Date created',
                          value: createdAt.isEmpty
                              ? 'Not available'
                              : createdAt.substring(0, 10),
                        ),
                        if (latitude.isNotEmpty || longitude.isNotEmpty)
                          _DetailRow(
                            label: 'GPS tag',
                            value: [latitude, longitude]
                                .where((value) => value.isNotEmpty)
                                .join(', '),
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
                          'Flow progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._buildStepItems(status),
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
                  const SizedBox(height: 16),
                  _buildGlassSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (attachments.isEmpty)
                          Text(
                            'No attachments uploaded for this report.',
                            style:
                                TextStyle(color: Colors.white.withOpacity(0.72)),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: attachments.map((item) {
                              final attachment = item as Map<String, dynamic>;
                              final mediaType =
                                  (attachment['media_type'] ?? 'image').toString();
                              final attachmentUrl = _buildImageUrl(
                                (attachment['image_path'] ?? '').toString(),
                              );

                              if (mediaType == 'video') {
                                return _VideoAttachmentCard(
                                  fileName: (attachment['original_name'] ?? 'video')
                                      .toString(),
                                  onOpen: attachmentUrl == null
                                      ? null
                                      : () => _openAttachment(attachmentUrl),
                                );
                              }

                              return _ImageAttachmentCard(imageUrl: attachmentUrl);
                            }).toList(),
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
                          'Service rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status == 'Resolved'
                              ? 'Rate the service you received from 1 to 5 stars.'
                              : 'Rating will unlock once the complaint reaches Resolved.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: List.generate(5, (index) {
                            final value = index + 1;
                            final filled =
                                (_selectedRating ?? 0) >= value;
                            return IconButton(
                              onPressed: status == 'Resolved' && !_isSavingRating
                                  ? () => _saveRating(value)
                                  : null,
                              icon: Icon(
                                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: filled
                                    ? const Color(0xFFFBBF24)
                                    : Colors.white54,
                                size: 32,
                              ),
                            );
                          }),
                        ),
                        if (_selectedRating != null)
                          Text(
                            'Your rating: $_selectedRating/5',
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Status history'),
                  const SizedBox(height: 8),
                  if (statusHistories.isEmpty)
                    _buildEmptyMessage('No status updates yet.')
                  else
                    ...statusHistories.map(
                      (item) {
                        final oldStatus =
                            _normalizedStatus((item['old_status'] ?? 'Submitted').toString());
                        final newStatus =
                            _normalizedStatus((item['new_status'] ?? 'Submitted').toString());

                        return _TimelineCard(
                          title: '$oldStatus -> $newStatus',
                          subtitle: ((item['user'] as Map<String, dynamic>?)?['name'] ??
                                  'System')
                              .toString(),
                          details: (item['remarks'] ?? 'No remarks').toString(),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Office responses'),
                  const SizedBox(height: 8),
                  if (adminResponses.isEmpty)
                    _buildEmptyMessage('No official updates yet.')
                  else
                    ...adminResponses.map(
                      (item) => _TimelineCard(
                        title:
                            ((item['user'] as Map<String, dynamic>?)?['name'] ?? 'Admin')
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

  List<Widget> _buildStepItems(String status) {
    const steps = [
      'Submitted',
      'Under Review',
      'In Progress',
      'Resolved',
    ];
    final currentIndex = steps.indexOf(status);

    return List<Widget>.generate(steps.length, (index) {
      final step = steps[index];
      final completed = currentIndex >= index;
      final active = currentIndex == index;
      return Padding(
        padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 12),
        child: _FlowProgressItem(
          label: step,
          active: active,
          completed: completed,
          description: _stepDescription(step),
        ),
      );
    });
  }

  Future<void> _saveRating(int rating) async {
    setState(() {
      _isSavingRating = true;
    });

    try {
      await ReportFeedbackService.saveRating(
        reportId: widget.reportId,
        rating: rating,
      );

      if (!mounted) return;

      setState(() {
        _selectedRating = rating;
        _isSavingRating = false;
      });

      _showSnack('Service rating saved.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSavingRating = false;
      });
      _showSnack('Unable to save service rating.');
    }
  }

  String _stepDescription(String step) {
    switch (step) {
      case 'Submitted':
        return 'Your complaint was received and assigned a tracking ID.';
      case 'Under Review':
        return 'The selected office is reviewing the details of your complaint.';
      case 'In Progress':
        return 'The office is actively working on the concern.';
      case 'Resolved':
        return 'The office marked the concern as resolved. You can now rate the service.';
      default:
        return '';
    }
  }

  String _normalizedStatus(String status) {
    switch (status) {
      case 'New':
        return 'Submitted';
      case 'Pending':
        return 'Under Review';
      default:
        return status;
    }
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
    var normalizedPath =
        trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
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

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnack('Invalid attachment link.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnack('Unable to open attachment.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        return const Color(0xFF22C55E);
      case 'In Progress':
        return const Color(0xFFF59E0B);
      case 'Under Review':
        return const Color(0xFF38BDF8);
      case 'Submitted':
        return const Color(0xFFA78BFA);
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

class _FlowProgressItem extends StatelessWidget {
  const _FlowProgressItem({
    required this.label,
    required this.active,
    required this.completed,
    required this.description,
  });

  final String label;
  final bool active;
  final bool completed;
  final String description;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? const Color(0xFF22C55E)
        : active
            ? const Color(0xFF38BDF8)
            : Colors.white24;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.16),
            border: Border.all(color: color),
          ),
          alignment: Alignment.center,
          child: Icon(
            completed ? Icons.check : Icons.circle,
            size: completed ? 16 : 10,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _ImageAttachmentCard extends StatelessWidget {
  const _ImageAttachmentCard({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 180,
        height: 148,
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
                imageUrl!,
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
  }
}

class _VideoAttachmentCard extends StatelessWidget {
  const _VideoAttachmentCard({
    required this.fileName,
    required this.onOpen,
  });

  final String fileName;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.videocam_outlined, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            fileName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open video'),
          ),
        ],
      ),
    );
  }
}
