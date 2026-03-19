import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/report_service.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final ReportService _reportService = ReportService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  late Future<List<dynamic>> _categoriesFuture;
  int? _selectedCategoryId;
  String _selectedPriority = 'Normal';
  bool _isSubmitting = false;
  final List<XFile> _selectedImages = [];

  static const List<String> _priorities = [
    'Low',
    'Normal',
    'High',
    'Urgent',
  ];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _reportService.getCategories();
  }

  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (files.isEmpty) return;

      setState(() {
        final remainingSlots = 3 - _selectedImages.length;
        _selectedImages.addAll(files.take(remainingSlots));
      });
    } catch (e) {
      _showSnack('Unable to select images: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _removeImageAt(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _reloadCategories() {
    setState(() {
      _selectedCategoryId = null;
      _categoriesFuture = _reportService.getCategories();
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final barangay = _barangayController.text.trim();

    if (_selectedCategoryId == null ||
        title.isEmpty ||
        description.isEmpty ||
        location.isEmpty) {
      _showSnack('Please complete the category, title, location, and description.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final categories = await _categoriesFuture.catchError(
        (_) => <dynamic>[],
      );
      final selectedCategory = _selectedCategory(categories);

      final response = await _reportService.createReport(
        categoryId: selectedCategory == null
            ? _selectedCategoryId
            : _categoryIdOf(selectedCategory),
        categoryName: selectedCategory == null
            ? null
            : (selectedCategory['name'] ?? '').toString(),
        title: title,
        description: description,
        location: location,
        barangay: barangay,
        priority: _selectedPriority,
      );

      if (!mounted) return;

      final report = response['report'] as Map<String, dynamic>?;
      final rawReportId = report?['id'];
      final reportId = rawReportId is int
          ? rawReportId
          : int.tryParse('${report?['id']}');

      if (reportId != null && _selectedImages.isNotEmpty) {
        for (final image in _selectedImages) {
          await _reportService.uploadImage(
            reportId: reportId,
            imageFile: image,
          );
        }
      }

      _showSnack('Report submitted successfully.');
      Navigator.pop(context, report);
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
    _barangayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFF0C1727),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0C1727),
        foregroundColor: Colors.white,
        title: const Text('Submit Report'),
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
        child: FutureBuilder<List<dynamic>>(
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
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          final categories = snapshot.data ?? const [];
          final selectedCategory = _selectedCategory(categories);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report a city issue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fill in the real incident details below. This will be saved directly to the system database.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                      ),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      _buildSelectedCategoryCard(selectedCategory),
                    ],
                    const SizedBox(height: 18),
                    _buildLabel('Category'),
                    const SizedBox(height: 8),
                    _buildCategoryGrid(categories),
                    const SizedBox(height: 16),
                    _buildLabel('Issue title'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: _inputDecoration('Example: Broken street light'),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Location'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: _inputDecoration('Street, landmark, or area'),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Barangay'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _barangayController,
                      decoration: _inputDecoration('Optional barangay name'),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Priority'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      dropdownColor: const Color(0xFF253248),
                      style: const TextStyle(color: Colors.white),
                      iconEnabledColor: Colors.white,
                      decoration: _inputDecoration('Priority'),
                      items: _priorities
                          .map(
                            (priority) => DropdownMenuItem<String>(
                              value: priority,
                              child: Text(
                                priority,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPriority = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Photos'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _selectedImages.length >= 3 ? null : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _selectedImages.isEmpty
                            ? 'Add up to 3 photos'
                            : 'Add more photos',
                      ),
                    ),
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          _selectedImages.length,
                          (index) => _SelectedImageChip(
                            image: _selectedImages[index],
                            onRemove: () => _removeImageAt(index),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildLabel('Description'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      minLines: 5,
                      maxLines: 7,
                      decoration: _inputDecoration(
                        'Describe the issue, what happened, and any important details.',
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
    );
  }

  Map<String, dynamic>? _selectedCategory(List<dynamic> categories) {
    if (_selectedCategoryId == null) {
      return null;
    }

    for (final item in categories) {
      final category = item as Map<String, dynamic>;
      final rawId = category['id'];
      final id = rawId is int ? rawId : int.tryParse('$rawId');
      if (id == _selectedCategoryId) {
        return category;
      }
    }

    return null;
  }

  int? _categoryIdOf(Map<String, dynamic> category) {
    final rawId = category['id'];
    return rawId is int ? rawId : int.tryParse('$rawId');
  }

  Widget _buildSelectedCategoryCard(Map<String, dynamic> category) {
    final categoryName = (category['name'] ?? 'Unnamed').toString();
    final icon = _categoryIcon(categoryName);
    final color = _categoryColor(categoryName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected category',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  categoryName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('road')) return Icons.construction;
    if (normalized.contains('water')) return Icons.water_drop_outlined;
    if (normalized.contains('electric')) return Icons.bolt_outlined;
    if (normalized.contains('garbage') || normalized.contains('waste')) {
      return Icons.delete_outline;
    }
    if (normalized.contains('drain')) return Icons.water_damage_outlined;
    if (normalized.contains('light')) return Icons.lightbulb_outline;
    return Icons.report_problem_outlined;
  }

  Color _categoryColor(String categoryName) {
    final normalized = categoryName.toLowerCase();
    if (normalized.contains('road')) return const Color(0xFFFF8A65);
    if (normalized.contains('water')) return const Color(0xFF4FC3F7);
    if (normalized.contains('electric')) return const Color(0xFFFFD54F);
    if (normalized.contains('garbage') || normalized.contains('waste')) {
      return const Color(0xFFA5D6A7);
    }
    if (normalized.contains('drain')) return const Color(0xFF80CBC4);
    if (normalized.contains('light')) return const Color(0xFFFFCC80);
    return const Color(0xFFD8B15A);
  }

  Widget _buildCategoryGrid(List<dynamic> categories) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No categories available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please seed the categories table in the backend, then refresh this page.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.68),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reloadCategories,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh categories'),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categories.map((item) {
        final category = item as Map<String, dynamic>;
        final rawId = category['id'];
        final categoryId = rawId is int ? rawId : int.tryParse('$rawId');
        final categoryName = (category['name'] ?? 'Unnamed').toString();
        final icon = _categoryIcon(categoryName);
        final color = _categoryColor(categoryName);
        final isSelected = categoryId != null && categoryId == _selectedCategoryId;

        return SizedBox(
          width: 140,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: categoryId == null
                  ? null
                  : () {
                      setState(() => _selectedCategoryId = categoryId);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.22)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? color : Colors.white.withOpacity(0.14),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      categoryName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSelected ? 'Selected' : 'Tap to choose',
                      style: TextStyle(
                        color: isSelected
                            ? color
                            : Colors.white.withOpacity(0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SelectedImageChip extends StatelessWidget {
  const _SelectedImageChip({
    required this.image,
    required this.onRemove,
  });

  final XFile image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FutureBuilder<Uint8List>(
          future: image.readAsBytes(),
          builder: (context, snapshot) {
            return Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF3F4F6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                image: snapshot.hasData
                    ? DecorationImage(
                        image: MemoryImage(snapshot.data!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: snapshot.hasData
                  ? null
                  : const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            );
          },
        ),
        Positioned(
          top: -6,
          right: -6,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
