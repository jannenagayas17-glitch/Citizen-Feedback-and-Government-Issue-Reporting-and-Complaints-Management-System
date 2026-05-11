import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';

typedef ReportStatusUpdateCallback =
    Future<bool> Function(Map<String, dynamic> report);

Future<bool?> showAdminReportDetailDialog({
  required BuildContext context,
  required int reportId,
  ReportStatusUpdateCallback? onUpdateStatus,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _AdminReportDetailDialog(
      reportId: reportId,
      onUpdateStatus: onUpdateStatus,
    ),
  );
}

class _AdminReportDetailDialog extends StatefulWidget {
  const _AdminReportDetailDialog({required this.reportId, this.onUpdateStatus});

  final int reportId;
  final ReportStatusUpdateCallback? onUpdateStatus;

  @override
  State<_AdminReportDetailDialog> createState() =>
      _AdminReportDetailDialogState();
}

class _AdminReportDetailDialogState extends State<_AdminReportDetailDialog> {
  final ReportService _reportService = ReportService();

  late Future<Map<String, dynamic>> _detailFuture;
  Map<String, dynamic>? _report;
  bool _statusActionBusy = false;
  bool _didMutate = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    final detail = await _reportService.getReportDetail(widget.reportId);
    _report = Map<String, dynamic>.from(detail);
    return _report!;
  }

  Future<void> _refresh() async {
    final future = _loadDetail();
    setState(() => _detailFuture = future);
    await future;
  }

  Future<void> _handleStatusUpdate() async {
    final callback = widget.onUpdateStatus;
    final report = _report;
    if (callback == null || report == null || _statusActionBusy) {
      return;
    }

    setState(() => _statusActionBusy = true);
    try {
      final changed = await callback(Map<String, dynamic>.from(report));
      if (changed) {
        _didMutate = true;
        await _refresh();
      }
    } finally {
      if (mounted) {
        setState(() => _statusActionBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width >= 1100 ? 820 : 700,
          maxHeight: size.height * 0.84,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.panel,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 40,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _detailFuture,
            builder: (context, snapshot) {
              final report = snapshot.data ?? _report;
              final title = (report?['title'] ?? 'Report Details').toString();
              final trackingId = _trackingId(report?['id']);
              final status = _status(report);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Details',
                                style: TextStyle(
                                  color: colors.mutedText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _InfoPill(
                                    label: trackingId,
                                    icon: Icons.badge_outlined,
                                    color: colors.primary,
                                  ),
                                  if (report != null)
                                    _InfoPill(
                                      label: status,
                                      icon: Icons.flag_outlined,
                                      color: _statusColor(status),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () =>
                              Navigator.of(context).pop(_didMutate),
                          style: IconButton.styleFrom(
                            foregroundColor: colors.text,
                            backgroundColor: colors.input,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  Expanded(child: _buildBody(snapshot, colors)),
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_didMutate),
                          child: const Text('Close'),
                        ),
                        if (widget.onUpdateStatus != null) ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed:
                                snapshot.connectionState !=
                                        ConnectionState.done ||
                                    snapshot.hasError ||
                                    _statusActionBusy
                                ? null
                                : _handleStatusUpdate,
                            icon: _statusActionBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.edit_outlined),
                            label: Text(
                              _statusActionBusy
                                  ? 'Updating...'
                                  : 'Update Status',
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildBody(
    AsyncSnapshot<Map<String, dynamic>> snapshot,
    AdminThemeColors colors,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: colors.mutedText,
              ),
              const SizedBox(height: 12),
              Text(
                snapshot.error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.text, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final report = snapshot.data ?? const <String, dynamic>{};
    final statusHistories =
        (report['status_histories'] as List<dynamic>? ??
                report['statusHistories'] as List<dynamic>? ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final adminResponses =
        (report['admin_responses'] as List<dynamic>? ??
                report['adminResponses'] as List<dynamic>? ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final attachments =
        (report['images'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final assignedAdmin =
        (report['assigned_admin'] as Map<String, dynamic>?) ??
        (report['assignedAdmin'] as Map<String, dynamic>?);
    final latestRemark = adminResponses.isEmpty
        ? 'No admin remarks yet.'
        : (adminResponses.first['response'] ?? 'No admin remarks yet.')
              .toString()
              .trim();

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailTile(
                  label: 'Category',
                  value: _category(report),
                  colors: colors,
                ),
                _DetailTile(
                  label: 'Department / Office',
                  value: _office(report),
                  colors: colors,
                ),
                _DetailTile(
                  label: 'Barangay / Location',
                  value: _locationSummary(report),
                  colors: colors,
                ),
                _DetailTile(
                  label: 'Submitted By',
                  value: _submittedBy(report),
                  colors: colors,
                ),
                _DetailTile(
                  label: 'Date Created',
                  value: _formatDate(report['created_at']),
                  colors: colors,
                ),
                _DetailTile(
                  label: 'Assigned Staff',
                  value: _assignedStaff(assignedAdmin),
                  colors: colors,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              colors: colors,
              title: 'Description',
              child: Text(
                (report['description'] ?? 'No description provided.')
                    .toString(),
                style: TextStyle(color: colors.text, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              colors: colors,
              title: 'Admin Remark',
              child: Text(
                latestRemark.isEmpty ? 'No admin remarks yet.' : latestRemark,
                style: TextStyle(color: colors.text, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              colors: colors,
              title: 'Attachments',
              child: attachments.isEmpty
                  ? _EmptyHint(
                      message: 'No attachments uploaded for this report.',
                      colors: colors,
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: attachments
                          .map(
                            (attachment) => _AttachmentCard(
                              attachment: attachment,
                              colors: colors,
                              onOpen: _openAttachment,
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              colors: colors,
              title: 'Status History',
              child: statusHistories.isEmpty
                  ? _EmptyHint(
                      message: 'No status updates yet.',
                      colors: colors,
                    )
                  : Column(
                      children: statusHistories
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TimelineEntry(
                                colors: colors,
                                title:
                                    '${(entry['old_status'] ?? 'Submitted').toString()} -> ${(entry['new_status'] ?? 'Pending').toString()}',
                                subtitle: _timelineActor(entry),
                                description: (entry['remarks'] ?? 'No remarks')
                                    .toString(),
                                meta: _formatDate(
                                  entry['created_at'] ?? entry['updated_at'],
                                ),
                                accent: _statusColor(
                                  (entry['new_status'] ?? 'Pending').toString(),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              colors: colors,
              title: 'Admin Responses',
              child: adminResponses.isEmpty
                  ? _EmptyHint(
                      message: 'No admin responses yet.',
                      colors: colors,
                    )
                  : Column(
                      children: adminResponses
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TimelineEntry(
                                colors: colors,
                                title: _timelineActor(entry, fallback: 'Admin'),
                                subtitle: 'Official update',
                                description:
                                    (entry['response'] ?? 'No response details')
                                        .toString(),
                                meta: _formatDate(
                                  entry['created_at'] ?? entry['updated_at'],
                                ),
                                accent: colors.primary,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _trackingId(dynamic rawId) {
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? widget.reportId;
    return 'CTR-${id.toString().padLeft(4, '0')}';
  }

  String _status(Map<String, dynamic>? report) {
    return (report?['status'] ?? 'Pending').toString().trim();
  }

  String _category(Map<String, dynamic> report) {
    final categoryName = (report['category_name'] ?? '').toString().trim();
    if (categoryName.isNotEmpty) {
      return categoryName;
    }

    final category = report['category'];
    if (category is Map<String, dynamic>) {
      final name = (category['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Uncategorized';
  }

  String _office(Map<String, dynamic> report) {
    final office = report['office'];
    if (office is Map<String, dynamic>) {
      final name = (office['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Unassigned office';
  }

  String _submittedBy(Map<String, dynamic> report) {
    final user = report['user'];
    if (user is Map<String, dynamic>) {
      final name = (user['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Unknown citizen';
  }

  String _assignedStaff(Map<String, dynamic>? assignedAdmin) {
    if (assignedAdmin == null) {
      return 'Unassigned';
    }

    final name = (assignedAdmin['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      return name;
    }

    return 'Unassigned';
  }

  String _locationSummary(Map<String, dynamic> report) {
    final barangay = (report['barangay'] ?? '').toString().trim();
    final location = (report['location'] ?? '').toString().trim();
    if (barangay.isNotEmpty && location.isNotEmpty) {
      return '$barangay - $location';
    }
    if (barangay.isNotEmpty) {
      return barangay;
    }
    if (location.isNotEmpty) {
      return location;
    }

    return 'Location not provided';
  }

  String _timelineActor(
    Map<String, dynamic> entry, {
    String fallback = 'System',
  }) {
    final user = entry['user'];
    if (user is Map<String, dynamic>) {
      final name = (user['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }

    return fallback;
  }

  String _formatDate(dynamic rawDate) {
    final parsed = DateTime.tryParse((rawDate ?? '').toString())?.toLocal();
    if (parsed == null) {
      return 'Not available';
    }

    final month = _monthLabel(parsed.month);
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${parsed.year} · $hour:$minute $suffix';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month < 1 || month > months.length) {
      return 'Date';
    }
    return months[month - 1];
  }

  String? _buildAttachmentUrl(String path) {
    final trimmed = path.trim();
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

  Future<void> _openAttachment(String path) async {
    final resolved = _buildAttachmentUrl(path);
    final uri = resolved == null ? null : Uri.tryParse(resolved);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _statusColor(String status) {
    switch (status.trim()) {
      case 'Resolved':
        return const Color(0xFF10B981);
      case 'In Progress':
        return const Color(0xFFF59E0B);
      case 'Rejected':
        return const Color(0xFFEF4444);
      case 'Pending':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AdminThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tileWidth = width >= 1000 ? 235.0 : 280.0;

    return SizedBox(
      width: tileWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.panelAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.mutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.colors,
    required this.title,
    required this.child,
  });

  final AdminThemeColors colors;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.meta,
    required this.accent,
  });

  final AdminThemeColors colors;
  final String title;
  final String subtitle;
  final String description;
  final String meta;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.input,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        meta,
                        style: TextStyle(color: colors.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(color: colors.text, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message, required this.colors});

  final String message;
  final AdminThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: colors.mutedText, height: 1.5),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.colors,
    required this.onOpen,
  });

  final Map<String, dynamic> attachment;
  final AdminThemeColors colors;
  final Future<void> Function(String path) onOpen;

  @override
  Widget build(BuildContext context) {
    final mediaType = (attachment['media_type'] ?? 'image').toString();
    final imagePath = (attachment['image_path'] ?? '').toString();
    final fileName = (attachment['original_name'] ?? mediaType).toString();
    final isVideo = mediaType == 'video';

    return InkWell(
      onTap: imagePath.trim().isEmpty ? null : () => onOpen(imagePath),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 112,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 92,
                height: 78,
                color: colors.panel,
                alignment: Alignment.center,
                child: isVideo
                    ? Icon(
                        Icons.play_circle_outline_rounded,
                        color: colors.primary,
                        size: 30,
                      )
                    : imagePath.trim().isEmpty
                    ? Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.mutedText,
                      )
                    : Image.network(
                        Uri.tryParse(imagePath)?.hasScheme == true
                            ? imagePath
                            : Uri.parse(ApiConfig.baseUrl)
                                  .replace(
                                    path:
                                        '/api/report-images/${imagePath.replaceAll('\\', '/').replaceFirst(RegExp(r'^/?(?:public/)?(?:storage/)?'), '')}',
                                    queryParameters: null,
                                    fragment: null,
                                  )
                                  .toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: colors.mutedText,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
