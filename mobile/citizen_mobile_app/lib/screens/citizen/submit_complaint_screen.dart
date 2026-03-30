import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/tacloban_barangays.dart';
import '../../services/report_feedback_service.dart';
import '../../services/report_service.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  final ReportService _reportService = ReportService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  late Future<List<dynamic>> _categoriesFuture;
  late Future<List<dynamic>> _officesFuture;

  int? _selectedCategoryId;
  int? _selectedOfficeId;
  String? _selectedOfficeNameValue;
  String? _selectedCustomIssueType;
  String _selectedPriority = 'Normal';
  bool _showGpsFields = false;
  bool _isSubmitting = false;
  final List<_SelectedMediaItem> _selectedMedia = [];

  String? _categoryError;
  String? _officeError;
  String? _locationError;
  String? _barangayError;
  String? _latitudeError;
  String? _longitudeError;
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
    _categoriesFuture = _reportService.getCategories();
    _officesFuture = _reportService.getOffices();
  }

  bool _containsEmoji(String value) => _emojiRegex.hasMatch(value);

  void _clearErrors() {
    _categoryError = null;
    _officeError = null;
    _locationError = null;
    _barangayError = null;
    _latitudeError = null;
    _longitudeError = null;
    _descriptionError = null;
  }

  Future<void> _pickImages() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (files.isEmpty) return;

    setState(() {
      final remaining = 3 - _selectedMedia.length;
      _selectedMedia.addAll(
        files.take(remaining).map(
              (file) => _SelectedMediaItem(file: file, mediaType: 'image'),
            ),
      );
    });
  }

  Future<void> _pickVideo() async {
    if (_selectedMedia.length >= 3) {
      _showSnack('You can upload up to 3 attachments only.');
      return;
    }

    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;

    setState(() {
      _selectedMedia.add(_SelectedMediaItem(file: file, mediaType: 'video'));
    });
  }

  Future<void> _showMediaPickerOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141C2B),
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
                const Text(
                  'Upload Evidence',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose image or video evidence for this report.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
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
                  subtitle: 'Upload one MP4 video',
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
      backgroundColor: const Color(0xFF141C2B),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Search Tacloban barangay',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
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
                                  style: TextStyle(color: Colors.white.withOpacity(0.72)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: Colors.white.withOpacity(0.08),
                              ),
                              itemBuilder: (context, index) {
                                final barangay = filtered[index];
                                return ListTile(
                                  title: Text(
                                    barangay,
                                    style: const TextStyle(color: Colors.white),
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
    final description = _descriptionController.text.trim();
    final selectedBarangay = _locationController.text.trim();
    final landmark = _barangayController.text.trim();
    final location = landmark.isEmpty
        ? '$selectedBarangay, Tacloban City'
        : '$landmark, $selectedBarangay, Tacloban City';
    final barangay = selectedBarangay;
    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();
    final latitude = latitudeText.isEmpty ? null : double.tryParse(latitudeText);
    final longitude = longitudeText.isEmpty ? null : double.tryParse(longitudeText);

    setState(() {
      _clearErrors();

      if (_selectedOfficeId == null) _officeError = 'Please select a government office.';
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
      if (latitudeText.isNotEmpty && latitude == null) {
        _latitudeError = 'Enter a valid latitude value.';
      }
      if (longitudeText.isNotEmpty && longitude == null) {
        _longitudeError = 'Enter a valid longitude value.';
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
      _latitudeError,
      _longitudeError,
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

      final verification = await _reportService.requestSubmissionVerification(
        categoryId: _hasDepartmentSpecificIssueTypes
            ? null
            : (selectedCategory == null ? _selectedCategoryId : _categoryIdOf(selectedCategory)),
        categoryName: selectedIssueTypeName,
        officeId: _selectedOfficeId,
        title: generatedTitle,
        description: description,
        location: location,
        barangay: barangay,
        priority: _selectedPriority,
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      final response = await _showOtpVerificationDialog(
        verification['email']?.toString() ?? '',
      );
      if (!mounted || response == null) return;

      final report = response['report'] as Map<String, dynamic>?;
      final rawReportId = report?['id'];
      final reportId = rawReportId is int ? rawReportId : int.tryParse('$rawReportId');

      if (reportId != null && _selectedMedia.isNotEmpty) {
        for (final media in _selectedMedia) {
          await _reportService.uploadMedia(reportId: reportId, mediaFile: media.file);
        }
      }

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

  Future<Map<String, dynamic>?> _showOtpVerificationDialog(String email) async {
    final controller = TextEditingController();
    String? errorText;
    bool isVerifying = false;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> verify() async {
              final otp = controller.text.trim();
              if (otp.length != 6) {
                setDialogState(() => errorText = 'Enter the 6-digit code sent to your email.');
                return;
              }

              setDialogState(() {
                errorText = null;
                isVerifying = true;
              });

              try {
                final response = await _reportService.verifySubmissionAndCreateReport(otp: otp);
                if (!mounted) return;
                Navigator.pop(context, response);
              } catch (e) {
                setDialogState(() {
                  errorText = e.toString().replaceFirst('Exception: ', '');
                  isVerifying = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF172235),
              title: const Text('Email verification', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.isEmpty
                        ? 'Enter the 6-digit code sent to your account email.'
                        : 'Enter the 6-digit code sent to $email.',
                    style: TextStyle(color: Colors.white.withOpacity(0.78)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('6-digit OTP', errorText: errorText)
                        .copyWith(counterText: ''),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isVerifying ? null : verify,
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & submit'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
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
        backgroundColor: const Color(0xFF172235),
        title: const Text('Submission received', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your complaint has been sent successfully.',
              style: TextStyle(color: Colors.white.withOpacity(0.82)),
            ),
            const SizedBox(height: 12),
            Text(
              trackingId,
              style: const TextStyle(
                color: Color(0xFFBFDBFE),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _barangayController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4B82F7);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF101826),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF101826),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Text('Submit Complaints'),
      ),
      body: FutureBuilder<List<dynamic>>(
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

          final values = snapshot.data ?? const <dynamic>[];
          final categories = values.isNotEmpty ? values[0] as List<dynamic> : const [];
          final offices = values.length > 1 ? values[1] as List<dynamic> : const [];

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(8, 8, 8, bottomInset + 18),
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                padding: const EdgeInsets.only(top: 16),
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
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
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
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Select a Tacloban City barangay',
                        errorText: _locationError,
                        prefixIcon: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFFF5A7A),
                          size: 16,
                        ),
                        suffixIcon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _barangayController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: Colors.white),
                      inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
                      decoration: _inputDecoration(
                        'Specific street, purok, or landmark (optional)',
                        errorText: _barangayError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => setState(() => _showGpsFields = !_showGpsFields),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8DA2C0),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(
                        _showGpsFields ? Icons.expand_less : Icons.add_location_alt_outlined,
                        size: 18,
                      ),
                      label: Text(_showGpsFields ? 'Hide GPS coordinates' : 'Add GPS coordinates'),
                    ),
                    if (_showGpsFields) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                'Latitude',
                                errorText: _latitudeError,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _longitudeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                'Longitude',
                                errorText: _longitudeError,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    _buildLabel('Priority'),
                    const SizedBox(height: 8),
                    _buildPrioritySelector(),
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
                            onRemove: () => setState(() => _selectedMedia.removeAt(index)),
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
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
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
        color: Colors.white.withOpacity(0.72),
      ),
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
      fillColor: const Color(0xFF1D2536),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4B82F7), width: 1.2),
      ),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.38)),
      errorText: errorText,
      errorMaxLines: 2,
    );
  }

  Map<String, dynamic>? _selectedCategory(List<dynamic> categories) {
    for (final item in categories) {
      final category = item as Map<String, dynamic>;
      final id = category['id'] is int ? category['id'] as int : int.tryParse('${category['id']}');
      if (id == _selectedCategoryId) return category;
    }
    return null;
  }

  int? _categoryIdOf(Map<String, dynamic> category) {
    final rawId = category['id'];
    return rawId is int ? rawId : int.tryParse('$rawId');
  }

  bool get _hasDepartmentSpecificIssueTypes => _departmentSpecificIssueTypes.isNotEmpty;

  List<String> get _departmentSpecificIssueTypes {
    final officeName = (_selectedOfficeNameValue ?? '').trim();
    return _departmentIssueTypes[officeName] ?? const <String>[];
  }

  Map<String, dynamic>? _selectedOffice(List<dynamic> offices) {
    for (final item in offices) {
      final office = item as Map<String, dynamic>;
      final id = office['id'] is int ? office['id'] as int : int.tryParse('${office['id']}');
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
        value: _selectedCustomIssueType,
        isExpanded: true,
        menuMaxHeight: 320,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: const Color(0xFF1D2536),
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: Colors.white,
        decoration: _inputDecoration('Select issue type', errorText: _categoryError),
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
      value: _selectedCategoryId,
      isExpanded: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: const Color(0xFF1D2536),
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
      decoration: _inputDecoration('Select issue type', errorText: _categoryError),
      items: categories.map((item) {
        final category = item as Map<String, dynamic>;
        final categoryId = category['id'] is int ? category['id'] as int : int.tryParse('${category['id']}');
        if (categoryId == null) return null;
        return DropdownMenuItem<int>(
          value: categoryId,
          child: Text((category['name'] ?? 'Unnamed').toString()),
        );
      }).whereType<DropdownMenuItem<int>>().toList(),
      onChanged: (value) => setState(() => _selectedCategoryId = value),
    );
  }

  Widget _buildOfficeDropdown(List<dynamic> offices) {
    final orderedOffices = _orderedDepartmentOffices(offices);

    return DropdownButtonFormField<int>(
      value: _selectedOfficeId,
      isExpanded: true,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(16),
      dropdownColor: const Color(0xFF1D2536),
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
      decoration: _inputDecoration(
        'Select Department',
        errorText: _officeError,
      ),
      items: orderedOffices.map((item) {
        final office = item as Map<String, dynamic>;
        final officeId = office['id'] is int ? office['id'] as int : int.tryParse('${office['id']}');
        if (officeId == null) return null;
        return DropdownMenuItem<int>(
          value: officeId,
          child: Text((office['name'] ?? 'Unnamed office').toString()),
        );
      }).whereType<DropdownMenuItem<int>>().toList(),
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
    final allowedNames = <String>{
      "City Civil Registrar's Office",
      "City Treasurer's Office",
      'Land Transportation Office',
      'Business Permit and Licensing Division',
      'City Health Office',
      'City Social Welfare and Development Office',
      "City Engineer's Office",
      'TOMECO (Traffic Operation)',
      'City Tourism Operations Office',
      "City Mayor's Office",
      'City Disaster Risk Reduction and Management Office',
      "City Assessor's Office",
      'City Agriculturist Office',
    };

    final filtered = offices
        .whereType<Map<String, dynamic>>()
        .where(
          (office) => allowedNames.contains((office['name'] ?? '').toString().trim()),
        )
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
        final palette = _priorityPalette(priority);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: priority == _priorities.last ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedPriority = priority),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? palette.fill : const Color(0xFF1D2536),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? palette.border
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    color: isSelected
                        ? palette.text
                        : Colors.white.withOpacity(0.72),
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

  _PriorityPalette _priorityPalette(String priority) {
    switch (priority) {
      case 'Low':
        return const _PriorityPalette(
          fill: Color(0xFF243E73),
          border: Color(0xFF4B82F7),
          text: Colors.white,
        );
      case 'Normal':
        return const _PriorityPalette(
          fill: Color(0xFF1F4D3A),
          border: Color(0xFF22C55E),
          text: Colors.white,
        );
      case 'High':
        return const _PriorityPalette(
          fill: Color(0xFF6B421A),
          border: Color(0xFFF59E0B),
          text: Colors.white,
        );
      case 'Urgent':
        return const _PriorityPalette(
          fill: Color(0xFF6A2430),
          border: Color(0xFFEF4444),
          text: Color(0xFFFFD5D8),
        );
      default:
        return const _PriorityPalette(
          fill: Color(0xFF293248),
          border: Color(0xFF4B82F7),
          text: Colors.white,
        );
    }
  }

  Widget _buildEvidenceCard() {
    final attachmentText = _selectedMedia.isEmpty
        ? 'Tap to upload image or video'
        : '${_selectedMedia.length} attachment${_selectedMedia.length == 1 ? '' : 's'} selected';

    return InkWell(
      onTap: _selectedMedia.length >= 3 ? null : _showMediaPickerOptions,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2536),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_camera_outlined, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              attachmentText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Max 50MB . JPG, PNG, MP4',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
              ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2536),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
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
  });

  final XFile file;
  final String mediaType;

  bool get isVideo => mediaType == 'video';
}

class _PriorityPalette {
  const _PriorityPalette({
    required this.fill,
    required this.border,
    required this.text,
  });

  final Color fill;
  final Color border;
  final Color text;
}

class _SelectedMediaChip extends StatelessWidget {
  const _SelectedMediaChip({
    required this.item,
    required this.onRemove,
  });

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
              color: Colors.white.withOpacity(0.10),
              border: Border.all(color: Colors.white.withOpacity(0.16)),
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
          Positioned(top: -6, right: -6, child: _RemoveMediaButton(onTap: onRemove)),
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
                image: snapshot.hasData
                    ? DecorationImage(image: MemoryImage(snapshot.data!), fit: BoxFit.cover)
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
        Positioned(top: -6, right: -6, child: _RemoveMediaButton(onTap: onRemove)),
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
