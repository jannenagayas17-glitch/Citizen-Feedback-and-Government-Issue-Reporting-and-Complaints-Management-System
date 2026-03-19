import 'package:flutter/material.dart';

import '../../services/report_service.dart';
import 'complaint_detail_screen.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  final ReportService _reportService = ReportService();
  late Future<List<dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _reportService.getReports();
  }

  Future<void> _refresh() async {
    final future = _reportService.getReports();
    setState(() => _reportsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        title: const Text('My Reports'),
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
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );
            }

            final reports = snapshot.data ?? const [];

            if (reports.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  Text(
                    'No reports found.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = reports[index] as Map<String, dynamic>;
                final status = (report['status'] ?? 'Pending').toString();

                return Card(
                  color: Colors.white.withOpacity(0.10),
                  child: ListTile(
                    title: Text(
                      (report['title'] ?? 'Untitled report').toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${report['location'] ?? 'No location'}\n$status',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right, color: Colors.white),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ComplaintDetailScreen(
                            reportId: report['id'] as int,
                          ),
                        ),
                      );
                    },
                  ),
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
