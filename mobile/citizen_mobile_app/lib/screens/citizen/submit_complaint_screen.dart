import 'package:flutter/material.dart';

import '../../services/report_service.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final ReportService _reportService = ReportService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  late Future<List<dynamic>> _categoriesFuture;
  int? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _reportService.getCategories();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (_selectedCategoryId == null ||
        title.isEmpty ||
        description.isEmpty ||
        location.isEmpty) {
      _showSnack('Please fill in all required fields');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _reportService.createReport(
        categoryId: _selectedCategoryId!,
        title: title,
        description: description,
        location: location,
      );

      if (!mounted) return;
      _showSnack('Report submitted successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Road Issue')),
      body: FutureBuilder<List<dynamic>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                ),
              ),
            );
          }

          final categories = snapshot.data ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Report Type',
                  border: OutlineInputBorder(),
                ),
                items: categories.map((item) {
                  final category = item as Map<String, dynamic>;
                  return DropdownMenuItem<int>(
                    value: category['id'] as int,
                    child: Text((category['name'] ?? 'Unnamed').toString()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Issue Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location or Barangay',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Report'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
