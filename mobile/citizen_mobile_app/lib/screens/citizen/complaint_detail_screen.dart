import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Report Details')),
      body: RefreshIndicator(
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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  (report['title'] ?? 'Untitled report').toString(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
                const SizedBox(height: 16),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text((report['description'] ?? 'No description').toString()),
                const SizedBox(height: 24),
                const Text(
                  'Status History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (statusHistories.isEmpty)
                  const Text('No status updates yet.')
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (adminResponses.isEmpty)
                  const Text('No admin responses yet.')
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            Text(details),
          ],
        ),
      ),
    );
  }
}
