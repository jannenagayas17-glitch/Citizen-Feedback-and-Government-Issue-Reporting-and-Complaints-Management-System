import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/report_feedback_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/citizen_theme_colors.dart';

class ComplaintDetailScreen extends StatefulWidget {
  const ComplaintDetailScreen({super.key, required this.reportId});

  final int reportId;

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  late Future<Map<String, dynamic>> _detailFuture;
  int? _selectedRating;
  bool _isSavingRating = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<Map<String, dynamic>> _loadDetail({bool refresh = false}) async {
    final detail = CitizenReportModel.normalizeReport(
      await CitizenDataCache.getReportDetail(widget.reportId, refresh: refresh),
    );
    final savedRating = await ReportFeedbackService.getRatingForReport(
      widget.reportId,
    );

    if (mounted) {
      setState(() => _selectedRating = savedRating);
    } else {
      _selectedRating = savedRating;
    }

    return detail;
  }

  Future<void> _refresh() async {
    final future = _loadDetail(refresh: true);
    setState(() => _detailFuture = future);
    await future;
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        title: const Text('Complaint Details'),
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: citizenIsDark(context)
                ? const [
                    Color(0xFF0B1322),
                    Color(0xFF10192E),
                    Color(0xFF0E1525),
                  ]
                : const [
                    Color(0xFFF8FBFF),
                    Color(0xFFEFF5FF),
                    Color(0xFFF6F8FC),
                  ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _detailFuture,
            builder: (context, snapshot) {
              final padding = EdgeInsets.fromLTRB(
                14,
                14,
                14,
                bottomSafeArea + 24,
              );

              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return _DetailLoadingState(padding: padding);
              }

              if (snapshot.hasError) {
                final error = snapshot.error;
                if (error is AuthSessionExpiredException) {
                  _redirectToLogin();
                  return _DetailLoadingState(padding: padding);
                }

                return _DetailErrorState(
                  padding: padding,
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: _refresh,
                );
              }

              final report = CitizenReportModel.normalizeReport(
                snapshot.data ?? const <String, dynamic>{},
              );
              final reportId = CitizenReportModel.reportIdOf(report);
              final trackingId = reportId == null
                  ? 'Tracking ID pending'
                  : ReportFeedbackService.buildTrackingId(reportId);
              final status = CitizenReportModel.displayStatusOf(report);
              final timeline = CitizenReportModel.timelineFor(report);
              final adminResponses = CitizenReportModel.adminResponsesOf(
                report,
              );
              final statusHistories = CitizenReportModel.statusHistoriesOf(
                report,
              );
              final attachments = CitizenReportModel.attachmentsOf(report);
              final latestRemark = CitizenReportModel.latestAdminRemarkOrNull(
                report,
              );
              final submittedBy =
                  ((_mapValue(report['user'])?['name'] ?? 'Unknown citizen'))
                      .toString();
              final assignedStaff = CitizenReportModel.assignedStaffNameOf(
                report,
              );
              final assignedRole = CitizenReportModel.assignedStaffRoleOf(
                report,
              );

              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: padding,
                children: [
                  _HeroCard(
                    trackingId: trackingId,
                    status: status,
                    category: CitizenReportModel.categoryNameOf(report),
                    title: CitizenReportModel.titleOf(report),
                    latestRemark: latestRemark,
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Report Information',
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Report ID',
                          value: reportId == null
                              ? 'Unavailable'
                              : '#$reportId',
                        ),
                        _DetailRow(label: 'Tracking ID', value: trackingId),
                        _DetailRow(
                          label: 'Department',
                          value: CitizenReportModel.officeNameOf(report),
                        ),
                        _DetailRow(
                          label: 'Issue type',
                          value: CitizenReportModel.categoryNameOf(report),
                        ),
                        _DetailRow(
                          label: 'Barangay',
                          value: _fallbackValue(
                            CitizenReportModel.barangayOf(report),
                          ),
                        ),
                        _DetailRow(
                          label: 'Location',
                          value: CitizenReportModel.locationOf(report),
                        ),
                        _DetailRow(label: 'Submitted by', value: submittedBy),
                        _DetailRow(
                          label: 'Submitted date',
                          value: _formattedDate(
                            CitizenReportModel.createdAtOf(report),
                          ),
                        ),
                        _DetailRow(
                          label: 'Current status',
                          value: status,
                          highlight: _statusColor(status),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Description',
                    child: Text(
                      CitizenReportModel.descriptionOf(report),
                      style: TextStyle(
                        color: citizenBodyColor(context),
                        height: 1.5,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Status Timeline',
                    subtitle:
                        'This timeline reflects the selected complaint only.',
                    child: Column(
                      children: timeline
                          .asMap()
                          .entries
                          .map(
                            (entry) => _TimelineStepCard(
                              step: entry.value,
                              isLast: entry.key == timeline.length - 1,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Admin Remarks',
                    child: Text(
                      CitizenReportModel.adminRemarkOf(report),
                      style: TextStyle(
                        color: citizenBodyColor(context),
                        height: 1.5,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Assigned Staff',
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignedStaff,
                                style: TextStyle(
                                  color: citizenTitleColor(context),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                assignedRole,
                                style: TextStyle(
                                  color: citizenBodyColor(context),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Attachments',
                    child: attachments.isEmpty
                        ? _EmptyInfoMessage(
                            message:
                                'No attachments uploaded for this complaint.',
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: attachments.map((attachment) {
                              final mediaType =
                                  (attachment['media_type'] ?? 'image')
                                      .toString();
                              final attachmentUrl = _buildAttachmentUrl(
                                (attachment['image_path'] ?? '').toString(),
                              );

                              if (mediaType == 'video') {
                                return _VideoAttachmentCard(
                                  fileName:
                                      (attachment['original_name'] ?? 'video')
                                          .toString(),
                                  onOpen: attachmentUrl == null
                                      ? null
                                      : () => _openAttachment(attachmentUrl),
                                );
                              }

                              return _ImageAttachmentCard(
                                imageUrl: attachmentUrl,
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Service Rating',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status == 'Resolved'
                              ? 'Rate the service you received for this completed complaint.'
                              : 'Rating unlocks once this complaint is marked Resolved.',
                          style: TextStyle(
                            color: citizenBodyColor(context),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 4,
                          children: List.generate(5, (index) {
                            final value = index + 1;
                            final filled = (_selectedRating ?? 0) >= value;
                            return IconButton(
                              onPressed:
                                  status == 'Resolved' && !_isSavingRating
                                  ? () => _saveRating(value)
                                  : null,
                              icon: Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: filled
                                    ? const Color(0xFFFBBF24)
                                    : citizenMutedColor(context),
                                size: 30,
                              ),
                            );
                          }),
                        ),
                        if (_selectedRating != null)
                          Text(
                            'Your rating: $_selectedRating/5',
                            style: const TextStyle(
                              color: Color(0xFFFBBF24),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Status History',
                    child: statusHistories.isEmpty
                        ? const _EmptyInfoMessage(
                            message: 'No status updates recorded yet.',
                          )
                        : Column(
                            children: statusHistories
                                .map(
                                  (history) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ActivityCard(
                                      title:
                                          '${CitizenReportModel.normalizeStatus((history['old_status'] ?? 'Submitted').toString())} -> ${CitizenReportModel.normalizeStatus((history['new_status'] ?? 'Submitted').toString())}',
                                      subtitle: _activitySubtitle(
                                        actor:
                                            (_mapValue(
                                                      history['user'],
                                                    )?['name'] ??
                                                    'System')
                                                .toString(),
                                        timestamp:
                                            CitizenReportModel.timestampOf(
                                              history['created_at'] ??
                                                  history['updated_at'],
                                            ),
                                      ),
                                      details: _fallbackValue(
                                        (history['remarks'] ?? '')
                                            .toString()
                                            .trim(),
                                        fallback: 'No remarks provided.',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Office Responses',
                    child: adminResponses.isEmpty
                        ? const _EmptyInfoMessage(
                            message: 'No official responses yet.',
                          )
                        : Column(
                            children: adminResponses
                                .map(
                                  (response) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ActivityCard(
                                      title:
                                          (_mapValue(
                                                    response['user'],
                                                  )?['name'] ??
                                                  'Assigned office')
                                              .toString(),
                                      subtitle: _activitySubtitle(
                                        actor: 'Official update',
                                        timestamp:
                                            CitizenReportModel.timestampOf(
                                              response['created_at'] ??
                                                  response['updated_at'],
                                            ),
                                      ),
                                      details: _fallbackValue(
                                        (response['response'] ?? '')
                                            .toString()
                                            .trim(),
                                        fallback:
                                            'No response details provided.',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
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

  Future<void> _saveRating(int rating) async {
    setState(() => _isSavingRating = true);

    try {
      await ReportFeedbackService.saveRating(
        reportId: widget.reportId,
        rating: rating,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedRating = rating;
        _isSavingRating = false;
      });
      _showSnack('Service rating saved.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isSavingRating = false);
      _showSnack('Unable to save service rating.');
    }
  }

  String? _buildAttachmentUrl(String imagePath) {
    final trimmed = imagePath.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final baseUri = Uri.parse(ApiConfig.baseUrl);
    var normalizedPath = trimmed.startsWith('/')
        ? trimmed.substring(1)
        : trimmed;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }

    return null;
  }

  static String _fallbackValue(
    String value, {
    String fallback = 'Not available',
  }) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  static String _formattedDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    return CitizenReportModel.formatDateTime(date);
  }

  static String _activitySubtitle({
    required String actor,
    required DateTime? timestamp,
  }) {
    final timeText = timestamp == null
        ? 'Time unavailable'
        : CitizenReportModel.formatDateTime(timestamp);
    return '$actor . $timeText';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF22C55E);
      case 'In Progress':
        return const Color(0xFF3B82F6);
      case 'Rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.trackingId,
    required this.status,
    required this.category,
    required this.title,
    required this.latestRemark,
  });

  final String trackingId;
  final String status;
  final String category;
  final String title;
  final String? latestRemark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.tag_rounded,
                label: trackingId,
                accent: const Color(0xFF3B82F6),
              ),
              _HeroPill(
                icon: Icons.flag_outlined,
                label: status,
                accent: _ComplaintDetailScreenState._statusColor(status),
              ),
              _HeroPill(
                icon: Icons.category_outlined,
                label: category,
                accent: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (latestRemark != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                latestRemark!,
                style: TextStyle(
                  color: citizenBodyColor(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: citizenBodyColor(context),
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.highlight});

  final String label;
  final String value;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: citizenMutedColor(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ?? citizenTitleColor(context),
                fontSize: 13.5,
                fontWeight: highlight == null
                    ? FontWeight.w600
                    : FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStepCard extends StatelessWidget {
  const _TimelineStepCard({required this.step, required this.isLast});

  final CitizenReportTimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = _timelineColor(step);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent),
                ),
                child: Icon(
                  step.completed ? Icons.check_rounded : Icons.circle,
                  size: step.completed ? 14 : 10,
                  color: accent,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: step.completed ? accent : citizenBorderColor(context),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.caption,
                    style: TextStyle(
                      color: citizenBodyColor(context),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _timelineColor(CitizenReportTimelineStep step) {
    switch (step.key) {
      case 'resolved':
        return step.completed || step.active
            ? const Color(0xFF22C55E)
            : const Color(0xFF64748B);
      case 'rejected':
        return step.completed || step.active
            ? const Color(0xFFEF4444)
            : const Color(0xFF64748B);
      case 'in_progress':
        return step.completed || step.active
            ? const Color(0xFF3B82F6)
            : const Color(0xFF64748B);
      default:
        return step.completed || step.active
            ? const Color(0xFFF59E0B)
            : const Color(0xFF64748B);
    }
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: citizenInputColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: citizenMutedColor(context), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: TextStyle(
              color: citizenBodyColor(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyInfoMessage extends StatelessWidget {
  const _EmptyInfoMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: citizenInputColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: citizenBodyColor(context),
          fontSize: 13,
          height: 1.45,
        ),
      ),
    );
  }
}

class _ImageAttachmentCard extends StatelessWidget {
  const _ImageAttachmentCard({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 180,
        height: 148,
        color: citizenInputColor(context),
        child: imageUrl == null
            ? Center(
                child: Text(
                  'Invalid image path',
                  style: TextStyle(color: citizenBodyColor(context)),
                ),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, _, _) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Unable to load image',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: citizenBodyColor(context)),
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
  const _VideoAttachmentCard({required this.fileName, required this.onOpen});

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
        color: citizenInputColor(context),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.videocam_outlined, color: citizenTitleColor(context)),
          const SizedBox(height: 10),
          Text(
            fileName,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
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

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: List.generate(
        6,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 5 ? 0 : 14),
          child: Container(
            height: index == 0 ? 180 : 150,
            decoration: BoxDecoration(
              color: citizenCardColor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: citizenBorderColor(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({
    required this.padding,
    required this.message,
    required this.onRetry,
  });

  final EdgeInsets padding;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: citizenCardColor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: citizenBorderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load complaint details',
                style: TextStyle(
                  color: citizenTitleColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: citizenBodyColor(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
