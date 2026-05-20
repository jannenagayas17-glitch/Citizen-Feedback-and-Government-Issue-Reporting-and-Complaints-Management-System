import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/tacloban_barangays.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/report_feedback_service.dart';
import '../../services/report_service.dart';
import '../../utils/citizen_theme_colors.dart';

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

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();

  late Future<List<dynamic>> _categoriesFuture;
  late Future<List<dynamic>> _officesFuture;
  late Future<List<dynamic>> _formOptionsFuture;

  int? _selectedCategoryId;
  int? _selectedOfficeId;
  String? _selectedOfficeNameValue;
  String? _selectedCustomIssueType;
  String _selectedPriority = 'Normal';
  bool _submitAnonymously = false;
  bool _isSubmitting = false;
  final List<_SelectedMediaItem> _selectedMedia = [];

  String? _categoryError;
  String? _officeError;
  String? _locationError;
  String? _barangayError;
  String? _descriptionError;

  static const List<String> _priorities = ['Low', 'Normal', 'High', 'Urgent'];
  static const Map<String, List<String>> _departmentIssueTypes = {
    "City Civil Registrar's Office": [
      'Document Errors',
      'Delayed Registration',
      'Staff Courtesy',
      'Certification Requests',
      'Others',
    ],
    "City Treasurer's Office": [
      'Tax Payments',
      'Payment Queues',
      'Online Payment Issues',
      'Official Receipts',
      'Others',
    ],
    "City Assessor's Office": [
      'Property Valuation',
      'Tax Mapping',
      'Transfer of Ownership',
      'Others',
    ],
    'City Health Office': [
      'Medical Supplies',
      'Health Center Service',
      'Sanitary Permits',
      'Vaccination Programs',
      'Others',
    ],
    'City Social Welfare and Development Office': [
      'Financial Assistance (AICS)',
      'Sectoral IDs',
      'Relief Distribution',
      'Others',
    ],
    'City Agriculturist Office': [
      'Farmer Support',
      'Livestock Health',
      'Technical Training',
      'Crop Damage Reporting',
      'Others',
    ],
    "City Engineer's Office": [
      'Road Repairs',
      'Drainage/Sewerage',
      'Public Facilities',
      'Streetlighting',
      'Others',
    ],
    'City Disaster Risk Reduction and Management Office': [
      'Emergency Response',
      'Hazard Reporting',
      'Training Requests',
      'Others',
    ],
    'Land Transportation Office': [
      "Driver's Licenses",
      'Vehicle Registration',
      'Plate Numbers',
      'Others',
    ],
    'TOMECO (Traffic Operation)': [
      'Illegal Parking',
      'Enforcer Conduct',
      'Traffic Flow',
      'Others',
    ],
    'Business Permit and Licensing Division': [
      'Business Registration',
      'Illegal Operations',
      'Permit Renewal',
      'Others',
    ],
    "City Mayor's Office": [
      'Executive Action',
      'Graft & Corruption',
      'General Commendation',
      'Others',
    ],
    'City Tourism Operations Office': [
      'Site Maintenance',
      'Event Logistics',
      'Hotel/Resort Standards',
      'Others',
    ],
  };
  @override
  void initState() {
    super.initState();
    _categoriesFuture = CitizenDataCache.getCategories();
    _officesFuture = CitizenDataCache.getOffices();
    _formOptionsFuture = Future.wait<dynamic>([
      _categoriesFuture,
      _officesFuture,
    ]);
  }

  bool _containsEmoji(String value) => _emojiRegex.hasMatch(value);

  void _clearErrors() {
    _categoryError = null;
    _officeError = null;
    _locationError = null;
    _barangayError = null;
    _descriptionError = null;
  }

  Future<void> _pickImages() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (files.isEmpty) return;

    await _addSelectedMedia(files, mediaType: 'image');
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    await _addSelectedMedia([file], mediaType: 'video');
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

      Uint8List? previewBytes;
      if (mediaType == 'image') {
        try {
          previewBytes = await file.readAsBytes();
        } catch (_) {
          previewBytes = null;
        }
      }

      acceptedItems.add(
        _SelectedMediaItem(
          file: file,
          mediaType: mediaType,
          previewBytes: previewBytes,
        ),
      );
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

  Future<void> _showMediaPickerOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: citizenCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upload Evidence',
                  style: TextStyle(
                    color: citizenTitleColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose photo or video evidence for this report.',
                  style: TextStyle(
                    color: citizenBodyColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                _buildMediaOptionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Add photos',
                  subtitle: 'Upload JPG or PNG images',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
                const SizedBox(height: 12),
                _buildMediaOptionTile(
                  icon: Icons.videocam_outlined,
                  title: 'Add video',
                  subtitle: 'Upload MP4 or MOV video evidence',
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBarangayPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: citizenCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final searchController = TextEditingController();
        var filtered = List<String>.from(taclobanBarangays);

        return StatefulBuilder(
          builder: (context, setModalState) {
            void filter(String value) {
              final query = value.trim().toLowerCase();
              setModalState(() {
                filtered = taclobanBarangays
                    .where((barangay) => barangay.toLowerCase().contains(query))
                    .toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: filter,
                      style: TextStyle(color: citizenTitleColor(context)),
                      decoration: _inputDecoration(
                        'Search Tacloban barangay',
                        prefixIcon: Icon(
                          Icons.search,
                          color: citizenMutedColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No Tacloban barangay matched your search.',
                                  style: TextStyle(
                                    color: citizenBodyColor(context),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: citizenBorderColor(context),
                              ),
                              itemBuilder: (context, index) {
                                final barangay = filtered[index];
                                return ListTile(
                                  title: Text(
                                    barangay,
                                    style: TextStyle(
                                      color: citizenTitleColor(context),
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(context, barangay),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      _locationController.text = selected;
      _locationError = null;
      _barangayError = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final description = _descriptionController.text.trim();
    final selectedBarangay = _locationController.text.trim();
    final landmark = _barangayController.text.trim();
    final location = landmark.isEmpty
        ? '$selectedBarangay, Tacloban City'
        : '$landmark, $selectedBarangay, Tacloban City';
    final barangay = selectedBarangay;

    setState(() {
      _clearErrors();

      if (_selectedOfficeId == null) {
        _officeError = 'Please select a government office.';
      }
      if (_hasDepartmentSpecificIssueTypes) {
        if ((_selectedCustomIssueType ?? '').trim().isEmpty) {
          _categoryError = 'Please select an issue type.';
        }
      } else if (_selectedCategoryId == null) {
        _categoryError = 'Please select an issue type.';
      }
      if (selectedBarangay.isEmpty) {
        _locationError = 'Please select a Tacloban City barangay.';
      } else if (!taclobanBarangays.contains(selectedBarangay)) {
        _locationError = 'Choose a valid Tacloban City barangay from the list.';
      }
      if (landmark.isNotEmpty && _containsEmoji(landmark)) {
        _barangayError = 'Emoji characters are not allowed.';
      }
      if (description.isEmpty) {
        _descriptionError = 'Description is required.';
      } else if (_containsEmoji(description)) {
        _descriptionError = 'Emoji characters are not allowed.';
      }
    });

    if ([
      _categoryError,
      _officeError,
      _locationError,
      _barangayError,
      _descriptionError,
    ].any((item) => item != null)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final categories = await _categoriesFuture.catchError((_) => <dynamic>[]);
      final offices = await _officesFuture.catchError((_) => <dynamic>[]);
      final selectedCategory = _selectedCategory(categories);
      final selectedOffice = _selectedOffice(offices);
      final selectedIssueTypeName = _selectedIssueTypeName(selectedCategory);
      final generatedTitle = _buildGeneratedTitle(
        selectedOfficeName: selectedOffice?['name']?.toString(),
        selectedCategoryName: selectedIssueTypeName,
        barangay: barangay,
      );

      final response = await _reportService.createReport(
        categoryId: _hasDepartmentSpecificIssueTypes
            ? null
            : (selectedCategory == null
                  ? _selectedCategoryId
                  : _categoryIdOf(selectedCategory)),
        categoryName: selectedIssueTypeName,
        officeId: _selectedOfficeId,
        title: generatedTitle,
        description: description,
        location: location,
        barangay: barangay,
        priority: _selectedPriority,
        isAnonymous: _submitAnonymously,
        mediaFiles: _selectedMedia.map((media) => media.file).toList(),
      );

      final report = response['report'] as Map<String, dynamic>?;

      await _showSubmissionResult(report);
      if (!mounted) return;
      Navigator.pop(context, report);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showSubmissionResult(Map<String, dynamic>? report) async {
    final rawId = report?['id'];
    final reportId = rawId is int ? rawId : int.tryParse('$rawId');
    final trackingId = reportId == null
        ? 'Tracking ID pending'
        : ReportFeedbackService.buildTrackingId(reportId);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: citizenCardColor(context),
        title: Text(
          'Submission received',
          style: TextStyle(color: citizenTitleColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _submitAnonymously
                  ? 'Your complaint has been sent successfully. Admins will see it as an anonymous report.'
                  : 'Your complaint has been sent successfully.',
              style: TextStyle(color: citizenBodyColor(context)),
            ),
            const SizedBox(height: 12),
            Text(
              trackingId,
              style: TextStyle(
                color: citizenPrimaryActionColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _barangayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        titleSpacing: 0,
        title: const Text('Submit Complaints'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _formOptionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  decoration: BoxDecoration(
                    color: citizenCardColor(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: citizenBorderColor(context)),
                  ),
                  child: Column(
                    children: List.generate(
                      6,
                      (index) => Padding(
                        padding: EdgeInsets.only(bottom: index == 5 ? 0 : 14),
                        child: _loadingFieldPlaceholder(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: citizenTitleColor(context)),
                ),
              ),
            );
          }

          final values = snapshot.data ?? const <dynamic>[];
          final categories = values.isNotEmpty
              ? values[0] as List<dynamic>
              : const [];
          final offices = values.length > 1
              ? values[1] as List<dynamic>
              : const [];

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: BoxDecoration(
                  color: citizenCardColor(context),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: citizenBorderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Department'),
                    const SizedBox(height: 8),
                    _buildOfficeDropdown(offices),
                    const SizedBox(height: 14),
                    _buildLabel('Issue Type'),
                    const SizedBox(height: 8),
                    _buildCategoryDropdown(categories),
                    const SizedBox(height: 14),
                    _buildLabel('Description'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 5,
                      style: TextStyle(color: citizenTitleColor(context)),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      decoration: _inputDecoration(
                        'Describe the issue in detail...',
                        errorText: _descriptionError,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('Location / Barangay'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      readOnly: true,
                      onTap: _showBarangayPicker,
                      style: TextStyle(color: citizenTitleColor(context)),
                      decoration: _inputDecoration(
                        'Select a Tacloban City barangay',
                        errorText: _locationError,
                        prefixIcon: Icon(
                          Icons.location_on_rounded,
                          color: citizenAccentColor(context),
                          size: 16,
                        ),
                        suffixIcon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: citizenMutedColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _barangayController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(color: citizenTitleColor(context)),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      decoration: _inputDecoration(
                        'Specific street, purok, or landmark (optional)',
                        errorText: _barangayError,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildLabel('Priority'),
                    const SizedBox(height: 8),
                    _buildPrioritySelector(),
                    const SizedBox(height: 14),
                    _buildLabel('Privacy'),
                    const SizedBox(height: 8),
                    _buildPrivacySelector(),
                    const SizedBox(height: 14),
                    _buildLabel('Upload Evidence'),
                    const SizedBox(height: 8),
                    _buildEvidenceCard(),
                    if (_selectedMedia.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          _selectedMedia.length,
                          (index) => _SelectedMediaChip(
                            item: _selectedMedia[index],
                            onRemove: () =>
                                setState(() => _selectedMedia.removeAt(index)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: citizenPrimaryActionColor(context),
                          foregroundColor: citizenOnPrimaryActionColor(context),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: citizenOnPrimaryActionColor(context),
                                ),
                              )
                            : const Text(
                                'Submit Report',
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
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: citizenBodyColor(context),
      ),
    );
  }

  Widget _loadingFieldPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 104,
          height: 12,
          decoration: BoxDecoration(
            color: citizenBorderColor(context),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: citizenInputColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: citizenBorderColor(context)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: citizenInputColor(context),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: citizenBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: citizenBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: citizenPrimaryActionColor(context),
          width: 1.2,
        ),
      ),
      hintStyle: TextStyle(color: citizenMutedColor(context)),
      errorText: errorText,
      errorMaxLines: 2,
    );
  }

  Map<String, dynamic>? _selectedCategory(List<dynamic> categories) {
    for (final item in categories) {
      final category = item as Map<String, dynamic>;
      final id = category['id'] is int
          ? category['id'] as int
          : int.tryParse('${category['id']}');
      if (id == _selectedCategoryId) return category;
    }
    return null;
  }

  int? _categoryIdOf(Map<String, dynamic> category) {
    final rawId = category['id'];
    return rawId is int ? rawId : int.tryParse('$rawId');
  }

  bool get _hasDepartmentSpecificIssueTypes =>
      _departmentSpecificIssueTypes.isNotEmpty;

  List<String> get _departmentSpecificIssueTypes {
    final officeName = (_selectedOfficeNameValue ?? '').trim();
    return _departmentIssueTypes[officeName] ?? const <String>[];
  }

  Map<String, dynamic>? _selectedOffice(List<dynamic> offices) {
    for (final item in offices) {
      final office = item as Map<String, dynamic>;
      final id = office['id'] is int
          ? office['id'] as int
          : int.tryParse('${office['id']}');
      if (id == _selectedOfficeId) return office;
    }
    return null;
  }

  String? _selectedIssueTypeName(Map<String, dynamic>? selectedCategory) {
    if (_hasDepartmentSpecificIssueTypes) {
      final custom = (_selectedCustomIssueType ?? '').trim();
      return custom.isEmpty ? null : custom;
    }

    final categoryName = (selectedCategory?['name'] ?? '').toString().trim();
    if (categoryName.isNotEmpty) return categoryName;
    return null;
  }

  String _buildGeneratedTitle({
    String? selectedOfficeName,
    String? selectedCategoryName,
    required String barangay,
  }) {
    final officeName = (selectedOfficeName ?? '').trim();
    final categoryName = (selectedCategoryName ?? '').trim();
    final barangayName = barangay.trim();

    final parts = <String>[
      if (officeName.isNotEmpty) officeName,
      if (categoryName.isNotEmpty) categoryName,
      if (barangayName.isNotEmpty) barangayName,
    ];

    return parts.isEmpty ? 'Citizen Complaint' : parts.join(' - ');
  }

  Widget _buildCategoryDropdown(List<dynamic> categories) {
    if (_hasDepartmentSpecificIssueTypes) {
      return DropdownButtonFormField<String>(
        initialValue: _selectedCustomIssueType,
        isExpanded: true,
        menuMaxHeight: 320,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: citizenDropdownColor(context),
        style: TextStyle(color: citizenTitleColor(context)),
        iconEnabledColor: citizenBodyColor(context),
        decoration: _inputDecoration(
          'Select issue type',
          errorText: _categoryError,
        ),
        items: _departmentSpecificIssueTypes
            .map(
              (issueType) => DropdownMenuItem<String>(
                value: issueType,
                child: Text(issueType),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedCustomIssueType = value),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: citizenDropdownColor(context),
      style: TextStyle(color: citizenTitleColor(context)),
      iconEnabledColor: citizenBodyColor(context),
      decoration: _inputDecoration(
        'Select issue type',
        errorText: _categoryError,
      ),
      items: categories
          .map((item) {
            final category = item as Map<String, dynamic>;
            final categoryId = category['id'] is int
                ? category['id'] as int
                : int.tryParse('${category['id']}');
            if (categoryId == null) return null;
            return DropdownMenuItem<int>(
              value: categoryId,
              child: Text((category['name'] ?? 'Unnamed').toString()),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: (value) => setState(() => _selectedCategoryId = value),
    );
  }

  Widget _buildOfficeDropdown(List<dynamic> offices) {
    final orderedOffices = _orderedDepartmentOffices(offices);

    return DropdownButtonFormField<int>(
      initialValue: _selectedOfficeId,
      isExpanded: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: citizenDropdownColor(context),
      style: TextStyle(color: citizenTitleColor(context)),
      iconEnabledColor: citizenBodyColor(context),
      decoration: _inputDecoration(
        'Select Department',
        errorText: _officeError,
      ),
      items: orderedOffices
          .map((item) {
            final office = item as Map<String, dynamic>;
            final officeId = office['id'] is int
                ? office['id'] as int
                : int.tryParse('${office['id']}');
            if (officeId == null) return null;
            return DropdownMenuItem<int>(
              value: officeId,
              child: Text((office['name'] ?? 'Unnamed office').toString()),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: (value) {
        Map<String, dynamic>? selectedOffice;
        for (final item in orderedOffices.whereType<Map<String, dynamic>>()) {
          final rawId = item['id'];
          final officeId = rawId is int ? rawId : int.tryParse('$rawId');
          if (officeId == value) {
            selectedOffice = item;
            break;
          }
        }

        setState(() {
          _selectedOfficeId = value;
          _selectedOfficeNameValue = selectedOffice?['name']?.toString().trim();
          _categoryError = null;
          _selectedCategoryId = null;
          _selectedCustomIssueType = null;
        });
      },
    );
  }

  List<dynamic> _orderedDepartmentOffices(List<dynamic> offices) {
    final filtered = offices
        .whereType<Map<String, dynamic>>()
        .where((office) => (office['name'] ?? '').toString().trim().isNotEmpty)
        .toList();

    filtered.sort((a, b) {
      final aName = (a['name'] ?? '').toString().toLowerCase();
      final bName = (b['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return filtered;
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: _priorities.map((priority) {
        final isSelected = _selectedPriority == priority;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: priority == _priorities.last ? 0 : 8,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedPriority = priority),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? citizenPriorityFillColor(context, priority)
                      : citizenInputColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? citizenPriorityBorderColor(context, priority)
                        : citizenBorderColor(context),
                  ),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    color: isSelected
                        ? citizenPriorityTextColor(context, priority)
                        : citizenBodyColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrivacySelector() {
    final infoColor = citizenPrimaryActionColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PrivacyOptionCard(
          title: 'Submit with my identity',
          subtitle:
              'Admins can see your name and contact details while handling this complaint.',
          selected: !_submitAnonymously,
          onTap: () => setState(() => _submitAnonymously = false),
        ),
        const SizedBox(height: 10),
        _PrivacyOptionCard(
          title: 'Submit anonymously',
          subtitle:
              'Admins will only see "Anonymous Citizen" while the system keeps secure internal records if needed.',
          selected: _submitAnonymously,
          onTap: () => setState(() => _submitAnonymously = true),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: infoColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: infoColor.withValues(alpha: 0.14)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: infoColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Anonymous reports hide your name, email, and phone from admin and super admin report views. Internal records may still be kept securely for account protection, misuse prevention, and legal compliance.',
                  style: TextStyle(
                    color: citizenBodyColor(context),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEvidenceCard() {
    final isDark = citizenIsDark(context);
    final attachmentText = _selectedMedia.isEmpty
        ? 'Tap to upload photos or videos'
        : '${_selectedMedia.length} attachment${_selectedMedia.length == 1 ? '' : 's'} selected';

    return InkWell(
      onTap: _selectedMedia.length >= _maxAttachments
          ? null
          : _showMediaPickerOptions,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        decoration: BoxDecoration(
          color: citizenInputColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: citizenBorderColor(context)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : citizenHighlightColor(context).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                color: isDark
                    ? citizenHighlightColor(context)
                    : citizenPrimaryActionColor(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              attachmentText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: citizenTitleColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Up to 3 attachments . Max 50MB . Photos or videos',
              textAlign: TextAlign.center,
              style: TextStyle(color: citizenMutedColor(context), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = citizenIsDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: citizenInputColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: citizenBorderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : citizenHighlightColor(context).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark
                    ? citizenHighlightColor(context)
                    : citizenPrimaryActionColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: citizenTitleColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: citizenBodyColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: citizenMutedColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyOptionCard extends StatelessWidget {
  const _PrivacyOptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = citizenPrimaryActionColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.08)
              : citizenInputColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.22)
                : citizenBorderColor(context),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? accent : citizenMutedColor(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: citizenTitleColor(context),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: citizenBodyColor(context),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedMediaItem {
  const _SelectedMediaItem({
    required this.file,
    required this.mediaType,
    this.previewBytes,
  });

  final XFile file;
  final String mediaType;
  final Uint8List? previewBytes;

  bool get isVideo => mediaType == 'video';
}

class _SelectedMediaChip extends StatelessWidget {
  const _SelectedMediaChip({required this.item, required this.onRemove});

  final _SelectedMediaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = citizenIsDark(context);

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
              color: citizenInputColor(context),
              border: Border.all(color: citizenBorderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_outlined,
                  color: isDark
                      ? citizenHighlightColor(context)
                      : citizenPrimaryActionColor(context),
                ),
                const SizedBox(height: 8),
                Text(
                  item.file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: citizenTitleColor(context),
                    fontSize: 12,
                  ),
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
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: citizenInputColor(context),
            image: item.previewBytes != null
                ? DecorationImage(
                    image: MemoryImage(item.previewBytes!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: item.previewBytes == null
              ? Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: citizenMutedColor(context),
                  ),
                )
              : null,
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
        decoration: BoxDecoration(
          color: citizenTitleColor(context),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 14, color: Colors.white),
      ),
    );
  }
}
