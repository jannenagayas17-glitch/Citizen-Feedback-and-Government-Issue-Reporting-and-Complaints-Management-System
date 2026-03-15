import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../citizen/complaint_detail_screen.dart';

class ComplaintManagementScreen extends StatefulWidget {
  const ComplaintManagementScreen({super.key});

  @override
  State<ComplaintManagementScreen> createState() => _ComplaintManagementScreenState();
}

class _ComplaintManagementScreenState extends State<ComplaintManagementScreen> {
  final ReportService _reportService = ReportService();
  String _selectedStatus = '';
  late Future<List<dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _loadReports();
  }

  Future<List<dynamic>> _loadReports() {
    return _reportService.getAdminReports(status: _selectedStatus);
  }

  Future<void> _refresh() async {
    final future = _loadReports();
    setState(() => _reportsFuture = future);
    await future;
  }

  Future<void> _openStatusDialog(Map<String, dynamic> report) async {
    String selectedStatus = (report['status'] ?? 'Pending').toString();
    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Report Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'New', child: Text('New')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedStatus = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      remarksController.dispose();
      return;
    }

    try {
      final response = await _reportService.updateReportStatus(
        reportId: report['id'] as int,
        status: selectedStatus,
        remarks: remarksController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Report status updated successfully',
          ),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      remarksController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    const statuses = ['', 'New', 'Pending', 'In Progress', 'Resolved'];

    return Scaffold(
      appBar: AppBar(title: const Text('Report Management')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _reportsFuture,
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
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              );
            }

            final reports = snapshot.data ?? const [];

            final newCount = reports.where((report) {
              return ((report as Map<String, dynamic>)['status'] ?? '')
                      .toString() ==
                  'New';
            }).length;
            final pendingCount = reports.where((report) {
              return ((report as Map<String, dynamic>)['status'] ?? '')
                      .toString() ==
                  'Pending';
            }).length;
            final resolvedCount = reports.where((report) {
              return ((report as Map<String, dynamic>)['status'] ?? '')
                      .toString() ==
                  'Resolved';
            }).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF153B9E),
                        Color(0xFF0C2B7A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complaint Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Filter reports, review complaint details, and update progress for field operations.',
                        style: TextStyle(
                          color: Color(0xFFD7E3FF),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryCard(
                      label: 'All Reports',
                      value: '${reports.length}',
                      color: const Color(0xFF2E6CF6),
                    ),
                    _SummaryCard(
                      label: 'New',
                      value: '$newCount',
                      color: const Color(0xFF64748B),
                    ),
                    _SummaryCard(
                      label: 'Pending',
                      value: '$pendingCount',
                      color: const Color(0xFFF59E0B),
                    ),
                    _SummaryCard(
                      label: 'Resolved',
                      value: '$resolvedCount',
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Filter by Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final status = statuses[index];
                      final isSelected = _selectedStatus == status;
                      return ChoiceChip(
                        label: Text(status.isEmpty ? 'All' : status),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedStatus = status;
                            _reportsFuture = _loadReports();
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (reports.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No reports found for this filter.'),
                    ),
                  )
                else
                  ...reports.map((item) {
                    final report = item as Map<String, dynamic>;
                    return _ReportCard(
                      title: (report['title'] ?? 'Untitled report').toString(),
                      citizen:
                          ((report['user'] as Map<String, dynamic>?)?['name'] ??
                                  'Citizen')
                              .toString(),
                      location: (report['location'] ?? 'No location').toString(),
                      status: (report['status'] ?? 'Pending').toString(),
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComplaintDetailScreen(
                              reportId: report['id'] as int,
                            ),
                          ),
                        );
                      },
                      onUpdate: () => _openStatusDialog(report),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.citizen,
    required this.location,
    required this.status,
    required this.onOpen,
    required this.onUpdate,
  });

  final String title;
  final String citizen;
  final String location;
  final String status;
  final VoidCallback onOpen;
  final VoidCallback onUpdate;

  Color _statusColor() {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF16A34A);
      case 'In Progress':
        return const Color(0xFF8B5CF6);
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'New':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF2E6CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.report_problem_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$citizen - $location',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF153B9E),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update Status'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
