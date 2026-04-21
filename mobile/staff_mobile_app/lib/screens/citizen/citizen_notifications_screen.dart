import 'package:flutter/material.dart';

class CitizenNotificationsScreen extends StatelessWidget {
  const CitizenNotificationsScreen({super.key, required this.reports});

  final List<dynamic> reports;

  @override
  Widget build(BuildContext context) {
    final notifications =
        reports
            .map((item) => item as Map<String, dynamic>)
            .map(_buildNotification)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1727), Color(0xFF1E293B), Color(0xFF463327)],
          ),
        ),
        child: notifications.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    title: 'Notifications',
                    subtitle: 'Stay updated on your submitted reports.',
                    countLabel: '0 updates',
                  ),
                  const SizedBox(height: 16),
                  _EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No notifications yet',
                    message:
                        'When your reports are reviewed, updated, or resolved, you will see them here.',
                  ),
                ],
              )
            : ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final resolvedCount = notifications
                        .where((item) => item.title == 'Issue resolved')
                        .length;
                    return _SummaryCard(
                      title: 'Notifications',
                      subtitle: 'Latest updates on your submitted reports.',
                      countLabel:
                          '${notifications.length} updates • $resolvedCount resolved',
                    );
                  }

                  final item = notifications[index - 1];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: item.color.withValues(alpha: 0.12),
                          child: Icon(item.icon, color: item.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _timeAgo(item.timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.52,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.message,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: item.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  item.caption,
                                  style: TextStyle(
                                    color: item.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _timeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }

  _CitizenNotification _buildNotification(Map<String, dynamic> report) {
    final title = (report['title'] ?? 'Untitled report').toString();
    final status = (report['status'] ?? 'New').toString();
    final location = (report['location'] ?? report['barangay'] ?? 'No location')
        .toString();
    final createdAt =
        DateTime.tryParse((report['created_at'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    switch (status) {
      case 'In Progress':
        return _CitizenNotification(
          title: 'Work has started',
          message: 'Your report "$title" is now In Progress.',
          caption: location,
          color: const Color(0xFFF59E0B),
          icon: Icons.engineering_outlined,
          timestamp: createdAt,
        );
      case 'Pending':
        return _CitizenNotification(
          title: 'Report under review',
          message: 'Your report "$title" is waiting for review.',
          caption: location,
          color: const Color(0xFF3B82F6),
          icon: Icons.hourglass_top_rounded,
          timestamp: createdAt,
        );
      case 'Resolved':
        return _CitizenNotification(
          title: 'Issue resolved',
          message: 'Your report "$title" has been marked Resolved.',
          caption: location,
          color: const Color(0xFF22C55E),
          icon: Icons.check_circle_outline,
          timestamp: createdAt,
        );
      case 'New':
      default:
        return _CitizenNotification(
          title: 'Report received',
          message: 'Your report "$title" was submitted successfully.',
          caption: location,
          color: const Color(0xFF8B5CF6),
          icon: Icons.mark_email_read_outlined,
          timestamp: createdAt,
        );
    }
  }
}

class _CitizenNotification {
  const _CitizenNotification({
    required this.title,
    required this.message,
    required this.caption,
    required this.color,
    required this.icon,
    required this.timestamp,
  });

  final String title;
  final String message;
  final String caption;
  final Color color;
  final IconData icon;
  final DateTime timestamp;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.countLabel,
  });

  final String title;
  final String subtitle;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              countLabel,
              style: const TextStyle(
                color: Color(0xFFB8D3FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.white.withValues(alpha: 0.72)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
          ),
        ],
      ),
    );
  }
}
