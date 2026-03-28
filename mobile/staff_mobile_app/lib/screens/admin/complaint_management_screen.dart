import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import '../../utils/file_download.dart';
import '../citizen/complaint_detail_screen.dart';
import 'analytics_reports_screen.dart';

class ComplaintManagementScreen extends StatefulWidget {
  const ComplaintManagementScreen({super.key});

  @override
  State<ComplaintManagementScreen> createState() =>
      _ComplaintManagementScreenState();
}

class _ComplaintManagementScreenState extends State<ComplaintManagementScreen> {
  final ReportService _reportService = ReportService();
  String _selectedStatus = '';
  late Future<List<dynamic>> _reportsFuture;
  bool _exporting = false;

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
    setState(() {
      _reportsFuture = future;
    });
    await future;
  }

  Future<void> _openAnalytics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AnalyticsReportsScreen()),
    );
    await _refresh();
  }

  Future<void> _exportReports() async {
    setState(() {
      _exporting = true;
    });

    try {
      final file = await _reportService.exportAdminReports(
        status: _selectedStatus,
      );
      await downloadFile(
        bytes: file.bytes,
        fileName: file.fileName,
        mimeType: file.mimeType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${file.fileName} successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
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
              backgroundColor: const Color(0xFF233246),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Update Report Status',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      dropdownColor: const Color(0xFF233246),
                      decoration: _dialogInputDecoration('Status'),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'New', child: Text('New')),
                        DropdownMenuItem(
                          value: 'Pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'In Progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'Resolved',
                          child: Text('Resolved'),
                        ),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: _dialogInputDecoration('Remarks (optional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white.withOpacity(0.82)),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
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
            response['message']?.toString() ??
                'Report status updated successfully',
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

  InputDecoration _dialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.70)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    const statuses = ['', 'New', 'Pending', 'In Progress', 'Resolved'];

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Report Management'),
        actions: [
          IconButton(
            onPressed: _openAnalytics,
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Analytics',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: _exporting ? null : _exportReports,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C1727),
              Color(0xFF1A2940),
              Color(0xFF463327),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
          child: FutureBuilder<List<dynamic>>(
            future: _reportsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _GlassNoticeCard(
                      title: 'Unable to load reports',
                      message: snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
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

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;
                  final mainContent = [
                    const _ManagementHeroCard(),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, cardConstraints) {
                        final cardWidth = cardConstraints.maxWidth > 520
                            ? (cardConstraints.maxWidth - 12) / 2
                            : cardConstraints.maxWidth;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SummaryCard(
                              width: cardWidth,
                              label: 'All Reports',
                              value: '${reports.length}',
                              color: const Color(0xFF60A5FA),
                              icon: Icons.library_books_outlined,
                            ),
                            _SummaryCard(
                              width: cardWidth,
                              label: 'New',
                              value: '$newCount',
                              color: const Color(0xFF94A3B8),
                              icon: Icons.fiber_new_rounded,
                            ),
                            _SummaryCard(
                              width: cardWidth,
                              label: 'Pending',
                              value: '$pendingCount',
                              color: const Color(0xFFF59E0B),
                              icon: Icons.hourglass_top_rounded,
                            ),
                            _SummaryCard(
                              width: cardWidth,
                              label: 'Resolved',
                              value: '$resolvedCount',
                              color: const Color(0xFF22C55E),
                              icon: Icons.task_alt_rounded,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const _SectionTitle(
                      title: 'Reports Queue',
                      subtitle:
                          'Open a report to review details or update its current engineering status.',
                    ),
                    const SizedBox(height: 12),
                    if (reports.isEmpty)
                      const _GlassNoticeCard(
                        title: 'No reports found',
                        message:
                            'There are no reports matching this filter right now.',
                      )
                    else
                      ...reports.map((item) {
                        final report = item as Map<String, dynamic>;
                        final user = report['user'] as Map<String, dynamic>?;

                        return _ReportCard(
                          title:
                              (report['title'] ?? 'Untitled report').toString(),
                          citizen:
                              (user?['name'] ?? 'Citizen Reporter').toString(),
                          location:
                              (report['location'] ?? 'No location').toString(),
                          category:
                              (report['category_name'] ??
                                      report['category']?['name'] ??
                                      'General')
                                  .toString(),
                          office:
                              (report['office']?['name'] ?? 'Unassigned office')
                                  .toString(),
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
                  ];

                  final rightRail = [
                    const _SectionTitle(
                      title: 'Status Filters',
                      subtitle:
                          'Focus on the queue your engineering team needs to handle next.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: isWide ? null : 46,
                      child: isWide
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: statuses.map((status) {
                                final isSelected = _selectedStatus == status;
                                return _StatusFilterChip(
                                  status: status,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedStatus = status;
                                      _reportsFuture = _loadReports();
                                    });
                                  },
                                );
                              }).toList(),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: statuses.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final status = statuses[index];
                                final isSelected = _selectedStatus == status;
                                return _StatusFilterChip(
                                  status: status,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedStatus = status;
                                      _reportsFuture = _loadReports();
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 18),
                    _GlassNoticeCard(
                      title: 'Reporting tools',
                      message: _selectedStatus.isEmpty
                          ? 'Download the full engineering report list as an Excel-ready CSV file, or open analytics for deeper trend tracking.'
                          : 'Current export will include only ${_selectedStatus.toLowerCase()} reports. Open analytics for a wider trend view.',
                      action: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.icon(
                            onPressed: _exporting ? null : _exportReports,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            icon: _exporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: Text(
                              _exporting ? 'Exporting...' : 'Export report file',
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openAnalytics,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.20),
                              ),
                            ),
                            icon: const Icon(Icons.insights_outlined),
                            label: const Text('Open analytics'),
                          ),
                        ],
                      ),
                    ),
                  ];

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      24 + bottomSafeArea,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                              child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 8,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: mainContent,
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: rightRail,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...rightRail,
                                    const SizedBox(height: 22),
                                    ...mainContent,
                                  ],
                                ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ManagementHeroCard extends StatelessWidget {
  const _ManagementHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF2563EB),
            Color(0xFF0F172A),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.14),
                  border: Border.all(
                    color: const Color(0xFFD8B15A),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Complaint Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Keep report intake organized, monitor progress across engineering teams, and close the loop with citizens quickly.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.citizen,
    required this.location,
    required this.category,
    required this.office,
    required this.status,
    required this.onOpen,
    required this.onUpdate,
  });

  final String title;
  final String citizen;
  final String location;
  final String category;
  final String office;
  final String status;
  final VoidCallback onOpen;
  final VoidCallback onUpdate;

  Color _statusColor() {
    switch (status) {
      case 'Resolved':
        return const Color(0xFF22C55E);
      case 'In Progress':
        return const Color(0xFF8B5CF6);
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'New':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF60A5FA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
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
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      citizen,
                      style: TextStyle(color: Colors.white.withOpacity(0.72)),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: status, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(icon: Icons.account_balance_outlined, label: office),
              _MetaChip(icon: Icons.category_outlined, label: category),
              _MetaChip(icon: Icons.place_outlined, label: location),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onUpdate,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Update Status'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.20)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFFB8D3FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassNoticeCard extends StatelessWidget {
  const _GlassNoticeCard({
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.4,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  final String status;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : Colors.white.withOpacity(0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              status.isEmpty ? 'All' : status,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.78),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
