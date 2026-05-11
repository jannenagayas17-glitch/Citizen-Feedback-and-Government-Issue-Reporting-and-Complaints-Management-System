Map<String, dynamic> pickPreferredManagedUser(
  Map<String, dynamic> current,
  Map<String, dynamic> candidate,
) {
  if (_isPreferredManagedUser(candidate, current)) {
    return Map<String, dynamic>.from(candidate);
  }

  return Map<String, dynamic>.from(current);
}

List<Map<String, dynamic>> deduplicateManagedUsers(Iterable<dynamic> users) {
  final uniqueUsers = <String, Map<String, dynamic>>{};

  for (final rawUser in users) {
    if (rawUser is! Map<String, dynamic>) {
      continue;
    }

    final user = Map<String, dynamic>.from(rawUser);
    final key = managedUserDeduplicationKey(user);
    final existing = uniqueUsers[key];
    if (existing == null) {
      uniqueUsers[key] = user;
      continue;
    }

    uniqueUsers[key] = pickPreferredManagedUser(existing, user);
  }

  return uniqueUsers.values.map(Map<String, dynamic>.from).toList();
}

Map<String, List<Map<String, dynamic>>> duplicateManagedUserEmailGroups(
  Iterable<dynamic> users,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};

  for (final rawUser in users) {
    if (rawUser is! Map<String, dynamic>) {
      continue;
    }

    final user = Map<String, dynamic>.from(rawUser);
    final normalizedEmail = normalizedManagedUserEmail(user);
    if (normalizedEmail.isEmpty) {
      continue;
    }

    grouped
        .putIfAbsent(normalizedEmail, () => <Map<String, dynamic>>[])
        .add(user);
  }

  grouped.removeWhere((key, value) => value.length < 2);

  return grouped;
}

String managedUserDeduplicationKey(Map<String, dynamic> user) {
  final normalizedEmail = normalizedManagedUserEmail(user);
  if (normalizedEmail.isNotEmpty) {
    return 'email:$normalizedEmail';
  }

  return 'id:${_userId(user)}';
}

String normalizedManagedUserEmail(Map<String, dynamic> user) {
  return (user['email'] ?? '').toString().trim().toLowerCase();
}

bool _isPreferredManagedUser(
  Map<String, dynamic> candidate,
  Map<String, dynamic> current,
) {
  final candidateArchived = _isArchived(candidate);
  final currentArchived = _isArchived(current);
  if (candidateArchived != currentArchived) {
    return !candidateArchived;
  }

  final candidateActive = candidate['is_active'] != false;
  final currentActive = current['is_active'] != false;
  if (candidateActive != currentActive) {
    return candidateActive;
  }

  final rolePriorityDiff =
      _rolePriority(candidate['role']) - _rolePriority(current['role']);
  if (rolePriorityDiff != 0) {
    return rolePriorityDiff > 0;
  }

  final candidateTimestamp = _latestTimestamp(candidate);
  final currentTimestamp = _latestTimestamp(current);
  if (candidateTimestamp != currentTimestamp) {
    return candidateTimestamp.isAfter(currentTimestamp);
  }

  return _userId(candidate) > _userId(current);
}

bool _isArchived(Map<String, dynamic> user) {
  final deletedAt = user['deleted_at'];
  return deletedAt != null && deletedAt.toString().trim().isNotEmpty;
}

int _rolePriority(dynamic roleValue) {
  switch ((roleValue ?? '').toString().trim()) {
    case 'super_admin':
      return 4;
    case 'admin':
      return 3;
    case 'pending_admin':
      return 2;
    case 'citizen':
      return 1;
    default:
      return 0;
  }
}

DateTime _latestTimestamp(Map<String, dynamic> user) {
  final updatedAt = DateTime.tryParse((user['updated_at'] ?? '').toString());
  if (updatedAt != null) {
    return updatedAt;
  }

  final createdAt = DateTime.tryParse((user['created_at'] ?? '').toString());
  if (createdAt != null) {
    return createdAt;
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

int _userId(Map<String, dynamic> user) {
  final rawId = user['id'];
  if (rawId is int) {
    return rawId;
  }

  if (rawId is num) {
    return rawId.toInt();
  }

  return int.tryParse('$rawId') ?? 0;
}
