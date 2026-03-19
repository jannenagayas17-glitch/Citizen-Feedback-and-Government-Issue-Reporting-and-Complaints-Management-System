import 'package:flutter/material.dart';

class CitizenNotificationsScreen extends StatelessWidget {
  const CitizenNotificationsScreen({
    super.key,
    required this.reports,
  });

  final List<dynamic> reports;

  @override
  Widget build(BuildContext context) {
    final notifications = reports
        .map((item) => item as Map<String, dynamic>)
        .map(_buildNotification)
        .toList()
      ..sort(
        (a, b) => b.timestamp.compareTo(a.timestamp),
      );

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
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1E293B),
              Color(0xFF463327),
            ],
          ),
        ),
        child: notifications.isEmpty
          ? const Center(
              child: Text('No notifications yet.', style: TextStyle(color: Colors.white)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];

                return Card(
                  color: Colors.white.withOpacity(0.10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.color.withOpacity(0.12),
                      child: Icon(item.icon, color: item.color),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      '${item.message}\n${item.caption}',
                      style: TextStyle(color: Colors.white.withOpacity(0.72)),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      ),
    );
  }

  _CitizenNotification _buildNotification(Map<String, dynamic> report) {
    final title = (report['title'] ?? 'Untitled report').toString();
    final status = (report['status'] ?? 'New').toString();
    final location = (report['location'] ?? report['barangay'] ?? 'No location')
        .toString();
    final createdAt = DateTime.tryParse((report['created_at'] ?? '').toString()) ??
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
