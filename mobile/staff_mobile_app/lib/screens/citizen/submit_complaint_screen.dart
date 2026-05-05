import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/report_service.dart';
import '../../utils/department_issue_types.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  static const int _maxAttachments = 3;
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  final ReportService _reportService = ReportService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  late Future<List<dynamic>> _categoriesFuture;
  late Future<List<dynamic>> _officesFuture;
  int? _selectedCategoryId;
  int? _selectedOfficeId;
  String? _selectedCategoryName;
  String _selectedPriority = 'Normal';
  bool _isSubmitting = false;
  final List<_SelectedMediaItem> _selectedMedia = [];
  String? _categoryError;
  String? _officeError;
  String? _titleError;
  String? _locationError;
  String? _barangayError;
  String? _descriptionError;

  static const List<String> _priorities = ['Low', 'Normal', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _reportService.getCategories();
    _officesFuture = _reportService.getOffices();
  }

  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (files.isEmpty) return;

      await _addSelectedMedia(files, mediaType: 'image');
    } catch (e) {
      _showSnack(
        'Unable to select images: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _addSelectedMedia(
    List<XFile> files, {
    required String mediaType,
  }) async {
    final remainingSlots = _maxAttachments - _selectedMedia.length;
    if (remainingSlots <= 0) {
      _showSnack('You can upload up to 3 attachments only.');
      return;
    }

    final pendingSelection = files.take(remainingSlots).toList();
    final acceptedItems = <_SelectedMediaItem>[];
    var oversizedCount = 0;

    for (final file in pendingSelection) {
      final fileSize = await file.length();
      if (fileSize > ReportService.maxAttachmentBytes) {
        oversizedCount++;
        continue;
      }

      acceptedItems.add(_SelectedMediaItem(file: file, mediaType: mediaType));
    }

    if (!mounted) return;

    if (acceptedItems.isNotEmpty) {
      setState(() => _selectedMedia.addAll(acceptedItems));
    }

    if (files.length > remainingSlots) {
      _showSnack('You can upload up to 3 attachments only.');
    }

    if (oversizedCount > 0) {
      _showSnack('Attachments must be 50MB or smaller.');
    }
  }

  void _removeMediaAt(int index) {
    setState(() => _selectedMedia.removeAt(index));
  }

  void _reloadFormSources() {
    setState(() {
      _selectedCategoryId = null;
      _selectedCategoryName = null;
      _selectedOfficeId = null;
      _categoryError = null;
      _officeError = null;
      _categoriesFuture = _reportService.getCategories();
      _officesFuture = _reportService.getOffices();
    });
  }

  bool _containsEmoji(String value) {
    return _emojiRegex.hasMatch(value);
  }

  void _clearErrors() {
    _categoryError = null;
    _officeError = null;
    _titleError = null;
    _locationError = null;
    _barangayError = null;
    _descriptionError = null;
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final barangay = _barangayController.text.trim();

    setState(() {
      _clearErrors();

      if (_selectedOfficeId == null) {
        _officeError = 'Please select a government office.';
      }

      if (_selectedCategoryId == null) {
        _categoryError = 'Please select a category.';
      }

      if (title.isEmpty) {
        _titleError = 'Issue title is required.';
      } else if (_containsEmoji(title)) {
        _titleError = 'Emoji characters are not allowed.';
      }

      if (location.isEmpty) {
        _locationError = 'Location is required.';
      } else if (_containsEmoji(location)) {
        _locationError = 'Emoji characters are not allowed.';
      }

      if (barangay.isNotEmpty && _containsEmoji(barangay)) {
        _barangayError = 'Emoji characters are not allowed.';
      }

      if (description.isEmpty) {
        _descriptionError = 'Description is required.';
      } else if (_containsEmoji(description)) {
        _descriptionError = 'Emoji characters are not allowed.';
      }
    });

    if (_categoryError != null ||
        _officeError != null ||
        _titleError != null ||
        _locationError != null ||
        _barangayError != null ||
        _descriptionError != null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final categories = await _categoriesFuture.catchError((_) => <dynamic>[]);
      final selectedCategory = _selectedCategory(categories);
      final selectedCategoryId = selectedCategory == null
          ? _selectedCategoryId
          : _categoryIdOf(selectedCategory);
      final selectedCategoryName =
          _selectedCategoryName ??
          (selectedCategory == null
              ? null
              : (selectedCategory['name'] ?? '').toString());

      final response = await _reportService.createReport(
        categoryId: selectedCategoryId == null || selectedCategoryId < 1
            ? null
            : selectedCategoryId,
        categoryName: selectedCategoryName,
        officeId: _selectedOfficeId,
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

      if (reportId != null && _selectedMedia.isNotEmpty) {
        for (final media in _selectedMedia) {
          await _reportService.uploadMedia(
            reportId: reportId,
            mediaFile: media.file,
          );
        }
      }

      _showSnack('Report submitted successfully.');
      if (!mounted) return;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
            colors: [Color(0xFF0C1727), Color(0xFF1E293B), Color(0xFF463327)],
          ),
        ),
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait<dynamic>([_categoriesFuture, _officesFuture]),
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

            final data = snapshot.data ?? const <dynamic>[];
            final categories = data.isNotEmpty
                ? data[0] as List<dynamic>
                : const [];
            final offices = data.length > 1
                ? data[1] as List<dynamic>
                : const [];
            final categoryOptions = _categoryOptionsForSelectedOffice(
              categories,
              offices,
            );
            if (_selectedCategoryId != null &&
                !categoryOptions.any(
                  (item) => _categoryIdOf(item) == _selectedCategoryId,
                )) {
              _selectedCategoryId = null;
              _selectedCategoryName = null;
            }
            final selectedOffice = _selectedOffice(offices);
            final selectedCategory = _selectedCategory(categoryOptions);

            return ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
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
                        'Choose the office that should receive your complaint, then attach photo evidence if available.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13,
                        ),
                      ),
                      if (selectedOffice != null) ...[
                        const SizedBox(height: 16),
                        _buildSelectedOfficeCard(selectedOffice),
                      ],
                      if (selectedCategory != null) ...[
                        const SizedBox(height: 12),
                        _buildSelectedCategoryCard(selectedCategory),
                      ],
                      const SizedBox(height: 18),
                      _buildLabel('Government office'),
                      const SizedBox(height: 8),
                      _buildOfficeDropdown(offices, errorText: _officeError),
                      const SizedBox(height: 16),
                      _buildLabel('Category'),
                      const SizedBox(height: 8),
                      _buildCategoryDropdown(
                        categoryOptions,
                        errorText: _categoryError,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Issue title'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(_emojiRegex),
                        ],
                        onChanged: (_) {
                          if (_titleError != null) {
                            setState(() => _titleError = null);
                          }
                        },
                        decoration: _inputDecoration(
                          'Example: Broken street light',
                          errorText: _titleError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Location'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _locationController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(_emojiRegex),
                        ],
                        onChanged: (_) {
                          if (_locationError != null) {
                            setState(() => _locationError = null);
                          }
                        },
                        decoration: _inputDecoration(
                          'Street, landmark, or area',
                          errorText: _locationError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Barangay'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _barangayController,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(_emojiRegex),
                        ],
                        onChanged: (_) {
                          if (_barangayError != null) {
                            setState(() => _barangayError = null);
                          }
                        },
                        decoration: _inputDecoration(
                          'Optional barangay name',
                          errorText: _barangayError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Priority'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPriority,
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
                      _buildLabel('Attachments'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _selectedMedia.length >= _maxAttachments
                                ? null
                                : _pickImages,
                            style: _attachmentButtonStyle(),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Add photos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can upload up to 3 photos total.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontSize: 12,
                        ),
                      ),
                      if (_selectedMedia.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(
                            _selectedMedia.length,
                            (index) => _SelectedMediaChip(
                              item: _selectedMedia[index],
                              onRemove: () => _removeMediaAt(index),
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
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(_emojiRegex),
                        ],
                        onChanged: (_) {
                          if (_descriptionError != null) {
                            setState(() => _descriptionError = null);
                          }
                        },
                        decoration: _inputDecoration(
                          'Describe the issue, what happened, and any important details.',
                          errorText: _descriptionError,
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

  InputDecoration _inputDecoration(String hint, {String? errorText}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 12),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.3),
      ),
    );
  }

  ButtonStyle _attachmentButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Map<String, dynamic>? _selectedOffice(List<dynamic> offices) {
    if (_selectedOfficeId == null) {
      return null;
    }

    for (final item in offices) {
      final office = item as Map<String, dynamic>;
      final rawId = office['id'];
      final id = rawId is int ? rawId : int.tryParse('$rawId');
      if (id == _selectedOfficeId) {
        return office;
      }
    }

    return null;
  }

  int? _categoryIdOf(Map<String, dynamic> category) {
    final rawId = category['id'];
    return rawId is int ? rawId : int.tryParse('$rawId');
  }

  List<Map<String, dynamic>> _categoryOptionsForSelectedOffice(
    List<dynamic> categories,
    List<dynamic> offices,
  ) {
    final categoryRecords = categories
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    final selectedOffice = _selectedOffice(offices);
    final officeName = (selectedOffice?['name'] ?? '').toString().trim();
    final mappedIssueTypes = issueTypesForDepartment(officeName);

    if (mappedIssueTypes.isEmpty) return categoryRecords;

    final categoriesByName = <String, Map<String, dynamic>>{};
    for (final category in categoryRecords) {
      final name = (category['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      categoriesByName.putIfAbsent(normalizeIssueTypeKey(name), () => category);
    }

    return mappedIssueTypes.asMap().entries.map((entry) {
      final name = entry.value;
      final existing = categoriesByName[normalizeIssueTypeKey(name)];
      if (existing != null) return existing;
      return <String, dynamic>{
        'id': -(entry.key + 1),
        'name': name,
        'description': '$name reports for $officeName',
      };
    }).toList();
  }

  Widget _buildSelectedCategoryCard(Map<String, dynamic> category) {
    final categoryName = (category['name'] ?? 'Unnamed').toString();
    final icon = _categoryIcon(categoryName);
    final color = _categoryColor(categoryName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
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
                    color: Colors.white.withValues(alpha: 0.68),
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

  Widget _buildCategoryDropdown(List<dynamic> categories, {String? errorText}) {
    if (categories.isEmpty) {
      return _buildEmptyDropdownState(
        title: 'No categories available',
        message:
            'Please seed the categories table in the backend, then refresh this page.',
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      dropdownColor: const Color(0xFF253248),
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
      decoration: _inputDecoration('Select a category', errorText: errorText),
      items: categories
          .map((item) {
            final category = item as Map<String, dynamic>;
            final rawId = category['id'];
            final categoryId = rawId is int ? rawId : int.tryParse('$rawId');
            final categoryName = (category['name'] ?? 'Unnamed').toString();
            final icon = _categoryIcon(categoryName);
            final color = _categoryColor(categoryName);

            if (categoryId == null) {
              return null;
            }

            return DropdownMenuItem<int>(
              value: categoryId,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      categoryName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        final selected = categories
            .whereType<Map<String, dynamic>>()
            .firstWhere(
              (category) => _categoryIdOf(category) == value,
              orElse: () => const <String, dynamic>{},
            );
        setState(() {
          _selectedCategoryId = value;
          _selectedCategoryName = (selected['name'] ?? '').toString();
          _categoryError = null;
        });
      },
    );
  }

  Widget _buildSelectedOfficeCard(Map<String, dynamic> office) {
    final officeName = (office['name'] ?? 'Unnamed office').toString();
    final officeCode = (office['code'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF60A5FA).withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_outlined,
              color: Color(0xFF93C5FD),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned office',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  officeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (officeCode.isNotEmpty)
                  Text(
                    officeCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeDropdown(List<dynamic> offices, {String? errorText}) {
    if (offices.isEmpty) {
      return _buildEmptyDropdownState(
        title: 'No government offices available',
        message: 'Ask an administrator to add offices, then refresh this page.',
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedOfficeId,
      isExpanded: true,
      dropdownColor: const Color(0xFF253248),
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
      decoration: _inputDecoration(
        'Select the office that should receive this report',
        errorText: errorText,
      ),
      items: offices
          .map((item) {
            final office = item as Map<String, dynamic>;
            final rawId = office['id'];
            final officeId = rawId is int ? rawId : int.tryParse('$rawId');
            final officeName = (office['name'] ?? 'Unnamed office').toString();

            if (officeId == null) {
              return null;
            }

            return DropdownMenuItem<int>(
              value: officeId,
              child: Text(
                officeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedOfficeId = value;
          _selectedCategoryId = null;
          _selectedCategoryName = null;
          _officeError = null;
        });
      },
    );
  }

  Widget _buildEmptyDropdownState({
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reloadFormSources,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _SelectedMediaItem {
  const _SelectedMediaItem({required this.file, required this.mediaType});

  final XFile file;
  final String mediaType;

  bool get isVideo => mediaType == 'video';
}

class _SelectedMediaChip extends StatelessWidget {
  const _SelectedMediaChip({required this.item, required this.onRemove});

  final _SelectedMediaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (item.isVideo) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 140,
            height: 92,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_outlined, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  item.file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: _RemoveMediaButton(onTap: onRemove),
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FutureBuilder<Uint8List>(
          future: item.file.readAsBytes(),
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
          child: _RemoveMediaButton(onTap: onRemove),
        ),
      ],
    );
  }
}

class _RemoveMediaButton extends StatelessWidget {
  const _RemoveMediaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}
