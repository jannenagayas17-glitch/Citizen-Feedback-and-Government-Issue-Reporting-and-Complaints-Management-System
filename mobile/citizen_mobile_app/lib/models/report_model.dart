class CitizenReportTimelineStep {
  const CitizenReportTimelineStep({
    required this.key,
    required this.title,
    required this.caption,
    required this.completed,
    required this.active,
  });

  final String key;
  final String title;
  final String caption;
  final bool completed;
  final bool active;

  bool get pending => !completed && !active;
}

class CitizenReportModel {
  CitizenReportModel._();

  static List<Map<String, dynamic>> normalizeReportList(List<dynamic> reports) {
    final normalizedReports = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (final item in reports) {
      final report = _mapFromAny(item);
      if (report == null) {
        continue;
      }

      final normalized = normalizeReport(report);
      final reportKey = _dedupeKeyFor(normalized);
      if (!seenKeys.add(reportKey)) {
        continue;
      }

      normalizedReports.add(normalized);
    }

    normalizedReports.sort(_compareReports);
    return normalizedReports;
  }

  static Map<String, dynamic> normalizeReport(Map<String, dynamic> report) {
    final source = _unwrapReportEnvelope(report);
    final normalized = Map<String, dynamic>.from(source);

    normalized['status_histories'] = _dedupeMapList(
      source['status_histories'] ?? source['statusHistories'],
      keyBuilder: (item) => _dedupeIdOrFallback(
        item,
        fallbackFields: const ['new_status', 'remarks', 'created_at'],
      ),
      sortBuilder: (item) =>
          timestampOf(item['created_at'] ?? item['updated_at']),
    );
    normalized['admin_responses'] = _dedupeMapList(
      source['admin_responses'] ?? source['adminResponses'],
      keyBuilder: (item) => _dedupeIdOrFallback(
        item,
        fallbackFields: const ['response', 'created_at'],
      ),
      sortBuilder: (item) =>
          timestampOf(item['created_at'] ?? item['updated_at']),
    );
    normalized['images'] = _dedupeMapList(
      source['images'],
      keyBuilder: (item) => _dedupeIdOrFallback(
        item,
        fallbackFields: const ['image_path', 'original_name', 'media_type'],
      ),
      sortBuilder: (item) =>
          timestampOf(item['created_at'] ?? item['updated_at']),
    );

    final assignedAdmin = _mapFromAny(
      source['assigned_admin'] ?? source['assignedAdmin'],
    );
    if (assignedAdmin != null) {
      normalized['assigned_admin'] = Map<String, dynamic>.from(assignedAdmin);
    }

    final latestStatusHistory = _mapFromAny(
      source['latest_status_history'] ?? source['latestStatusHistory'],
    );
    if (latestStatusHistory != null) {
      normalized['latest_status_history'] = Map<String, dynamic>.from(
        latestStatusHistory,
      );
    }

    final latestAdminResponse = _mapFromAny(
      source['latest_admin_response'] ?? source['latestAdminResponse'],
    );
    if (latestAdminResponse != null) {
      normalized['latest_admin_response'] = Map<String, dynamic>.from(
        latestAdminResponse,
      );
    }

    return normalized;
  }

  static int? reportIdOf(Map<String, dynamic> report) {
    final directId = _intFromAny(report['id']);
    if (directId != null) {
      return directId;
    }

    final nestedReport = _mapFromAny(report['report']);
    return nestedReport == null ? null : _intFromAny(nestedReport['id']);
  }

  static String titleOf(Map<String, dynamic> report) {
    return (_unwrapReportEnvelope(report)['title'] ?? 'Untitled report')
        .toString()
        .trim();
  }

  static String descriptionOf(Map<String, dynamic> report) {
    final description = (_unwrapReportEnvelope(report)['description'] ?? '')
        .toString()
        .trim();
    return description.isEmpty ? 'No description provided.' : description;
  }

  static String categoryNameOf(Map<String, dynamic> report) {
    final normalized = _unwrapReportEnvelope(report);
    final directName = (normalized['category_name'] ?? '').toString().trim();
    if (directName.isNotEmpty) {
      return directName;
    }

    final category = _mapFromAny(normalized['category']);
    final categoryName = (category?['name'] ?? '').toString().trim();
    return categoryName.isEmpty ? 'Uncategorized' : categoryName;
  }

  static String officeNameOf(Map<String, dynamic> report) {
    final office = _mapFromAny(_unwrapReportEnvelope(report)['office']);
    final officeName = (office?['name'] ?? '').toString().trim();
    return officeName.isEmpty ? 'Unassigned office' : officeName;
  }

  static String locationOf(Map<String, dynamic> report) {
    final location = (_unwrapReportEnvelope(report)['location'] ?? '')
        .toString()
        .trim();
    return location.isEmpty ? 'No location provided' : location;
  }

  static String barangayOf(Map<String, dynamic> report) {
    return (_unwrapReportEnvelope(report)['barangay'] ?? '').toString().trim();
  }

  static String displayStatusOf(Map<String, dynamic> report) {
    return normalizeStatus(
      (_unwrapReportEnvelope(report)['status'] ?? 'New').toString(),
    );
  }

  static String normalizeStatus(String rawStatus) {
    switch (rawStatus.trim()) {
      case 'New':
      case 'Pending':
        return 'Submitted';
      default:
        return rawStatus.trim().isEmpty ? 'Submitted' : rawStatus.trim();
    }
  }

  static DateTime? createdAtOf(Map<String, dynamic> report) {
    return timestampOf(_unwrapReportEnvelope(report)['created_at']);
  }

  static DateTime? updatedAtOf(Map<String, dynamic> report) {
    return timestampOf(_unwrapReportEnvelope(report)['updated_at']);
  }

  static DateTime? resolvedAtOf(Map<String, dynamic> report) {
    return timestampOf(_unwrapReportEnvelope(report)['resolved_at']);
  }

  static List<Map<String, dynamic>> statusHistoriesOf(
    Map<String, dynamic> report,
  ) {
    final normalized = normalizeReport(report);
    return ((normalized['status_histories'] as List<dynamic>? ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>())
        .map(Map<String, dynamic>.from)
        .toList();
  }

  static List<Map<String, dynamic>> adminResponsesOf(
    Map<String, dynamic> report,
  ) {
    final normalized = normalizeReport(report);
    return ((normalized['admin_responses'] as List<dynamic>? ??
                const <dynamic>[])
            .whereType<Map<String, dynamic>>())
        .map(Map<String, dynamic>.from)
        .toList();
  }

  static List<Map<String, dynamic>> attachmentsOf(Map<String, dynamic> report) {
    final normalized = normalizeReport(report);
    return ((normalized['images'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>())
        .map(Map<String, dynamic>.from)
        .toList();
  }

  static String? latestAdminRemarkOrNull(Map<String, dynamic> report) {
    final normalized = normalizeReport(report);

    final latestAdminResponse = _textValue(
      _mapFromAny(
        normalized['latest_admin_response'] ??
            normalized['latestAdminResponse'],
      )?['response'],
    );
    if (latestAdminResponse != null) {
      return latestAdminResponse;
    }

    for (final response in adminResponsesOf(normalized)) {
      final message = _textValue(response['response']);
      if (message != null) {
        return message;
      }
    }

    final latestStatusRemark = _textValue(
      _mapFromAny(
        normalized['latest_status_history'] ??
            normalized['latestStatusHistory'],
      )?['remarks'],
    );
    if (latestStatusRemark != null) {
      return latestStatusRemark;
    }

    for (final history in statusHistoriesOf(normalized)) {
      final remarks = _textValue(history['remarks']);
      if (remarks != null) {
        return remarks;
      }
    }

    return null;
  }

  static String adminRemarkOf(Map<String, dynamic> report) {
    return latestAdminRemarkOrNull(report) ?? 'No admin remarks yet.';
  }

  static Map<String, dynamic>? assignedAdminOf(Map<String, dynamic> report) {
    final normalized = normalizeReport(report);
    final assignedAdmin = _mapFromAny(
      normalized['assigned_admin'] ?? normalized['assignedAdmin'],
    );
    return assignedAdmin == null
        ? null
        : Map<String, dynamic>.from(assignedAdmin);
  }

  static String assignedStaffNameOf(Map<String, dynamic> report) {
    final assignedAdmin = assignedAdminOf(report);
    final assignedName = _textValue(assignedAdmin?['name']);
    if (assignedName != null) {
      return assignedName;
    }

    for (final response in adminResponsesOf(report)) {
      final actorName = _textValue(_mapFromAny(response['user'])?['name']);
      if (actorName != null) {
        return actorName;
      }
    }

    for (final history in statusHistoriesOf(report)) {
      final actorName = _textValue(_mapFromAny(history['user'])?['name']);
      if (actorName != null) {
        return actorName;
      }
    }

    return 'Awaiting assignment';
  }

  static String assignedStaffRoleOf(Map<String, dynamic> report) {
    final assignedAdmin = assignedAdminOf(report);
    final assignedRole = _textValue(
      assignedAdmin?['job_title'] ?? assignedAdmin?['role'],
    );
    if (assignedRole != null) {
      return assignedRole;
    }

    for (final response in adminResponsesOf(report)) {
      final actor = _mapFromAny(response['user']);
      final actorRole = _textValue(actor?['job_title'] ?? actor?['role']);
      if (actorRole != null) {
        return actorRole;
      }
    }

    for (final history in statusHistoriesOf(report)) {
      final actor = _mapFromAny(history['user']);
      final actorRole = _textValue(actor?['job_title'] ?? actor?['role']);
      if (actorRole != null) {
        return actorRole;
      }
    }

    return 'Department staff';
  }

  static List<CitizenReportTimelineStep> timelineFor(
    Map<String, dynamic> report,
  ) {
    final currentStatus = displayStatusOf(report);
    final createdAt = createdAtOf(report);
    final updatedAt = updatedAtOf(report);
    final resolvedAt = resolvedAtOf(report);

    final inProgressHistory = _latestHistoryForStatus(report, 'In Progress');
    final resolvedHistory = _latestHistoryForStatus(report, 'Resolved');
    final rejectedHistory = _latestHistoryForStatus(report, 'Rejected');

    final inProgressReached =
        inProgressHistory != null ||
        currentStatus == 'In Progress' ||
        currentStatus == 'Resolved';
    final resolvedReached =
        resolvedHistory != null || currentStatus == 'Resolved';
    final rejectedReached =
        rejectedHistory != null || currentStatus == 'Rejected';

    return <CitizenReportTimelineStep>[
      CitizenReportTimelineStep(
        key: 'submitted',
        title: 'Submitted',
        caption: createdAt == null
            ? 'Submitted to the system'
            : 'Submitted ${formatDateTime(createdAt)}',
        completed: true,
        active: currentStatus == 'Submitted',
      ),
      CitizenReportTimelineStep(
        key: 'in_progress',
        title: 'In Progress',
        caption: _historyCaption(
          history: inProgressHistory,
          fallbackDate: currentStatus == 'In Progress' ? updatedAt : null,
          active: currentStatus == 'In Progress',
          reached: inProgressReached,
        ),
        completed: inProgressReached,
        active: currentStatus == 'In Progress',
      ),
      CitizenReportTimelineStep(
        key: 'resolved',
        title: 'Resolved',
        caption: _historyCaption(
          history: resolvedHistory,
          fallbackDate: currentStatus == 'Resolved'
              ? (resolvedAt ?? updatedAt)
              : null,
          active: currentStatus == 'Resolved',
          reached: resolvedReached,
        ),
        completed: resolvedReached,
        active: currentStatus == 'Resolved',
      ),
      CitizenReportTimelineStep(
        key: 'rejected',
        title: 'Rejected',
        caption: _historyCaption(
          history: rejectedHistory,
          fallbackDate: currentStatus == 'Rejected' ? updatedAt : null,
          active: currentStatus == 'Rejected',
          reached: rejectedReached,
        ),
        completed: rejectedReached,
        active: currentStatus == 'Rejected',
      ),
    ];
  }

  static String formatDateTime(DateTime date) {
    final local = date.toLocal();
    const months = <String>[
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
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} $hour:$minute $period';
  }

  static DateTime? timestampOf(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  static Map<String, dynamic> _unwrapReportEnvelope(
    Map<String, dynamic> report,
  ) {
    final nestedReport = _mapFromAny(report['report']);
    if (_intFromAny(report['id']) == null &&
        nestedReport != null &&
        _intFromAny(nestedReport['id']) != null) {
      return nestedReport;
    }

    return report;
  }

  static int _compareReports(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftCreatedAt = createdAtOf(left);
    final rightCreatedAt = createdAtOf(right);

    if (leftCreatedAt != null && rightCreatedAt != null) {
      final byDate = rightCreatedAt.compareTo(leftCreatedAt);
      if (byDate != 0) {
        return byDate;
      }
    } else if (leftCreatedAt != null) {
      return -1;
    } else if (rightCreatedAt != null) {
      return 1;
    }

    final leftId = reportIdOf(left) ?? 0;
    final rightId = reportIdOf(right) ?? 0;
    return rightId.compareTo(leftId);
  }

  static String _dedupeKeyFor(Map<String, dynamic> report) {
    final reportId = reportIdOf(report);
    if (reportId != null) {
      return 'id:$reportId';
    }

    return _dedupeIdOrFallback(
      report,
      fallbackFields: const ['title', 'status', 'location', 'created_at'],
    );
  }

  static List<Map<String, dynamic>> _dedupeMapList(
    dynamic source, {
    required String Function(Map<String, dynamic> item) keyBuilder,
    DateTime? Function(Map<String, dynamic> item)? sortBuilder,
  }) {
    final seenKeys = <String>{};
    final items = <Map<String, dynamic>>[];

    for (final item in _listFromAny(source)) {
      final mapItem = _mapFromAny(item);
      if (mapItem == null) {
        continue;
      }

      final normalizedItem = Map<String, dynamic>.from(mapItem);
      final key = keyBuilder(normalizedItem);
      if (!seenKeys.add(key)) {
        continue;
      }

      items.add(normalizedItem);
    }

    if (sortBuilder != null) {
      items.sort((left, right) {
        final leftValue = sortBuilder(left);
        final rightValue = sortBuilder(right);
        if (leftValue != null && rightValue != null) {
          return rightValue.compareTo(leftValue);
        }
        if (leftValue != null) {
          return -1;
        }
        if (rightValue != null) {
          return 1;
        }
        return 0;
      });
    }

    return items;
  }

  static Map<String, dynamic>? _latestHistoryForStatus(
    Map<String, dynamic> report,
    String targetStatus,
  ) {
    for (final history in statusHistoriesOf(report)) {
      if (normalizeStatus((history['new_status'] ?? '').toString()) ==
          targetStatus) {
        return history;
      }
    }

    return null;
  }

  static String _historyCaption({
    required Map<String, dynamic>? history,
    required DateTime? fallbackDate,
    required bool active,
    required bool reached,
  }) {
    final historyDate = history == null
        ? null
        : timestampOf(history['created_at'] ?? history['updated_at']);
    if (historyDate != null) {
      return 'Updated ${formatDateTime(historyDate)}';
    }

    if (fallbackDate != null) {
      return active
          ? 'Current status since ${formatDateTime(fallbackDate)}'
          : 'Updated ${formatDateTime(fallbackDate)}';
    }

    if (reached) {
      return active ? 'Current status' : 'Completed';
    }

    return 'Awaiting status update';
  }

  static List<dynamic> _listFromAny(dynamic value) {
    return value is List<dynamic> ? value : const <dynamic>[];
  }

  static Map<String, dynamic>? _mapFromAny(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }

    return null;
  }

  static int? _intFromAny(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('${value ?? ''}');
  }

  static String? _textValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _dedupeIdOrFallback(
    Map<String, dynamic> item, {
    required List<String> fallbackFields,
  }) {
    final itemId = _intFromAny(item['id']);
    if (itemId != null) {
      return 'id:$itemId';
    }

    final buffer = StringBuffer();
    for (final field in fallbackFields) {
      buffer.write('|');
      buffer.write(item[field]?.toString().trim().toLowerCase() ?? '');
    }

    return buffer.toString();
  }
}
