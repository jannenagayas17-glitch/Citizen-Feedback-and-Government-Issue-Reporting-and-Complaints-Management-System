import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/report_service.dart';
import '../../utils/admin_theme.dart';
import '../../utils/tacloban_barangays.dart';
import '../../utils/validators.dart';

Future<Map<String, dynamic>?> showWalkInComplaintDialog({
  required BuildContext context,
  String? initialOfficeName,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WalkInComplaintScreen(
      initialOfficeName: initialOfficeName,
      showAsDialog: true,
    ),
  );
}

class WalkInComplaintScreen extends StatefulWidget {
  const WalkInComplaintScreen({
    super.key,
    this.initialOfficeName,
    this.showAsDialog = false,
  });

  final String? initialOfficeName;
  final bool showAsDialog;

  @override
  State<WalkInComplaintScreen> createState() => _WalkInComplaintScreenState();
}

class _WalkInComplaintScreenState extends State<WalkInComplaintScreen> {
  static const int _maxDescriptionLength = 100;

  final ReportService _reportService = ReportService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _complainantNameController =
      TextEditingController();
  final TextEditingController _complainantMobileController =
      TextEditingController();
  final TextEditingController _complainantEmailController =
      TextEditingController();
  final TextEditingController _complainantAddressController =
      TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late Future<void> _bootstrapFuture;
  List<Map<String, dynamic>> _offices = const [];
  List<Map<String, dynamic>> _categories = const [];
  int? _selectedOfficeId;
  int? _selectedCategoryId;
  String _priority = 'Normal';
  bool _submitAnonymously = false;
  bool _saving = false;
  bool _normalizingPhone = false;
  String? _formError;
  DateTime _expectedReturnAt = _defaultReturnDate();
  final List<XFile> _attachments = [];

  bool get _isDialog => widget.showAsDialog;

  static DateTime _defaultReturnDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 3, 10);
  }

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadFormData();
  }

  Future<void> _loadFormData() async {
    final results = await Future.wait<dynamic>([
      _reportService.getOffices(),
      _reportService.getCategories(),
    ]);

    _offices = (results[0] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList()
      ..sort(
        (a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()),
      );
    _categories = (results[1] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList()
      ..sort(
        (a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()),
      );

    if (_offices.isNotEmpty) {
      final preferredOffice = widget.initialOfficeName?.trim().toLowerCase();
      if (preferredOffice != null && preferredOffice.isNotEmpty) {
        final matchingOffice = _offices.cast<Map<String, dynamic>?>().firstWhere(
          (office) =>
              office != null &&
              (office['name'] ?? '').toString().trim().toLowerCase() ==
                  preferredOffice,
          orElse: () => null,
        );
        _selectedOfficeId = matchingOffice == null
            ? null
            : (matchingOffice['id'] as num?)?.toInt();
      }
      _selectedOfficeId ??= (_offices.first['id'] as num?)?.toInt();
    }
    if (_categories.isNotEmpty) {
      _selectedCategoryId ??= (_categories.first['id'] as num?)?.toInt();
    }
  }

  void _handlePhoneChanged(String value) {
    final sanitized = PortalValidators.sanitizeMobileInput(value);

    if (!_normalizingPhone && sanitized != value) {
      _normalizingPhone = true;
      _complainantMobileController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
      _normalizingPhone = false;
    }
  }

  String? _validate() {
    final complainantName = PortalValidators.normalizeWhitespace(
      _complainantNameController.text,
    );
    final address = PortalValidators.normalizeWhitespace(
      _complainantAddressController.text,
    );
    final barangay = PortalValidators.normalizeWhitespace(
      _barangayController.text,
    );
    final location = PortalValidators.normalizeWhitespace(
      _locationController.text,
    );
    final title = PortalValidators.normalizeWhitespace(_titleController.text);
    final description = PortalValidators.normalizeWhitespace(
      _descriptionController.text,
    );
    final email = _complainantEmailController.text.trim();

    final complainantError = PortalValidators.validateFullName(complainantName);
    if (complainantError != null) {
      return complainantError;
    }

    final mobileError = PortalValidators.validatePhilippineMobile(
      _complainantMobileController.text,
      required: true,
    );
    if (mobileError != null) {
      return mobileError;
    }

    if (email.isNotEmpty) {
      final emailError = PortalValidators.validateEmail(email);
      if (emailError != null) {
        return emailError;
      }
    }

    if (_selectedOfficeId == null) {
      return 'Please select the department that should receive this complaint.';
    }

    if (_selectedCategoryId == null) {
      return 'Please select a complaint category.';
    }

    if (address.isEmpty) {
      return 'Address is required.';
    }
    if (barangay.isEmpty) {
      return 'Please select a Tacloban City barangay.';
    }
    if (!taclobanBarangays.contains(barangay)) {
      return 'Choose a valid Tacloban City barangay from the list.';
    }
    if (title.isEmpty) {
      return 'Complaint title is required.';
    }
    if (description.isEmpty) {
      return 'Complaint description is required.';
    }

    if (description.length > _maxDescriptionLength) {
      return 'Complaint description must be $_maxDescriptionLength characters or fewer.';
    }

    for (final value in [address, barangay, location, title, description]) {
      if (PortalValidators.containsEmoji(value)) {
        return 'Emoji characters are not allowed.';
      }
    }

    if (_attachments.length > 3) {
      return 'You can attach up to 3 files only.';
    }

    return null;
  }

  Future<void> _pickImage() async {
    if (_attachments.length >= 3) {
      _showSnack('You can attach up to 3 files only.');
      return;
    }

    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      _attachments.add(image);
      _formError = null;
    });
  }

  Future<void> _pickVideo() async {
    if (_attachments.length >= 3) {
      _showSnack('You can attach up to 3 files only.');
      return;
    }

    final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (video == null) {
      return;
    }

    setState(() {
      _attachments.add(video);
      _formError = null;
    });
  }

  Future<void> _showBarangayPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminThemeColors.of(context).panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final searchController = TextEditingController();
        var filtered = List<String>.from(taclobanBarangays);
        final colors = AdminThemeColors.of(context);

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
                      style: TextStyle(color: colors.text),
                      decoration: InputDecoration(
                        hintText: 'Search Tacloban barangay',
                        hintStyle: TextStyle(color: colors.mutedText),
                        prefixIcon: Icon(
                          Icons.search,
                          color: colors.mutedText,
                        ),
                        filled: true,
                        fillColor: colors.input,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: colors.primary),
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
                                  style: TextStyle(color: colors.mutedText),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: colors.border,
                              ),
                              itemBuilder: (context, index) {
                                final barangay = filtered[index];
                                return ListTile(
                                  title: Text(
                                    barangay,
                                    style: TextStyle(color: colors.text),
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

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _barangayController.text = selected;
      _formError = null;
    });
  }

  Future<void> _pickExpectedReturnAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturnAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturnAt),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _expectedReturnAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }

    final validationError = _validate();
    if (validationError != null) {
      setState(() => _formError = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
    });

    try {
      final normalizedSubscriberDigits = PortalValidators.normalizeMobileInput(
        _complainantMobileController.text,
      );
      final normalizedBarangay = PortalValidators.normalizeWhitespace(
        _barangayController.text,
      );
      final normalizedLandmark = PortalValidators.normalizeWhitespace(
        _locationController.text,
      );

      final response = await _reportService.createWalkInReport(
        officeId: _selectedOfficeId!,
        categoryId: _selectedCategoryId,
        title: PortalValidators.normalizeWhitespace(_titleController.text),
        description: PortalValidators.normalizeWhitespace(
          _descriptionController.text,
        ),
        location: normalizedLandmark.isEmpty
            ? '$normalizedBarangay, Tacloban City'
            : '$normalizedLandmark, $normalizedBarangay, Tacloban City',
        barangay: normalizedBarangay,
        complainantName: PortalValidators.normalizeWhitespace(
          _complainantNameController.text,
        ),
        complainantContactNumber: normalizedSubscriberDigits.isEmpty
            ? ''
            : '0$normalizedSubscriberDigits',
        complainantEmail: _complainantEmailController.text.trim().isEmpty
            ? null
            : _complainantEmailController.text.trim(),
        complainantAddress: PortalValidators.normalizeWhitespace(
          _complainantAddressController.text,
        ),
        isAnonymous: _submitAnonymously,
        expectedReturnAt: _expectedReturnAt,
        priority: _priority,
        attachments: _attachments,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        Map<String, dynamic>.from(response['report'] as Map<String, dynamic>),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _complainantNameController.dispose();
    _complainantMobileController.dispose();
    _complainantEmailController.dispose();
    _complainantAddressController.dispose();
    _barangayController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return _isDialog
        ? _buildDialogPresentation(colors)
        : _buildPagePresentation(colors);
  }

  Widget _buildPagePresentation(AdminThemeColors colors) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        elevation: 0,
        title: const Text('New Walk-in Complaint'),
      ),
      body: FutureBuilder<void>(
        future: _bootstrapFuture,
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
                  style: TextStyle(color: colors.text),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: _buildFormContent(colors: colors, compact: false),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDialogPresentation(AdminThemeColors colors) {
    final mediaQuery = MediaQuery.of(context);
    final rawMaxWidth = mediaQuery.size.width >= 1040
        ? 860.0
        : mediaQuery.size.width >= 840
            ? 780.0
            : mediaQuery.size.width - 24;
    final dialogMaxWidth = rawMaxWidth < 320 ? 320.0 : rawMaxWidth;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        12,
        20,
        12,
        20 + mediaQuery.viewInsets.bottom,
      ),
      child: PopScope(
        canPop: !_saving,
        child: Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: mediaQuery.size.height * 0.90,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colors.panel,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: FutureBuilder<void>(
                future: _bootstrapFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildDialogFrame(
                      colors: colors,
                      body: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildDialogFrame(
                      colors: colors,
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 38,
                                color: colors.mutedText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                snapshot.error
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.text,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return _buildDialogFrame(
                    colors: colors,
                    body: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                        child: _buildFormContent(colors: colors, compact: true),
                      ),
                    ),
                    footer: _buildDialogFooter(colors),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogFrame({
    required AdminThemeColors colors,
    required Widget body,
    Widget? footer,
  }) {
    return Column(
      children: [
        _buildDialogHeader(colors),
        Divider(height: 1, color: colors.border),
        Expanded(child: body),
        if (footer != null) ...[
          Divider(height: 1, color: colors.border),
          footer,
        ],
      ],
    );
  }

  Widget _buildDialogHeader(AdminThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit Walk-in Complaint',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capture a citizen walk-in complaint using the same report flow used across the system.',
                  style: TextStyle(
                    color: colors.mutedText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Close',
            onPressed: _saving ? null : () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: colors.input,
              foregroundColor: colors.text,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(AdminThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 12,
        overflowSpacing: 12,
        children: [
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: Colors.white,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.assignment_turned_in_outlined),
            label: Text(
              _saving ? 'Submitting...' : 'Submit Complaint',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent({
    required AdminThemeColors colors,
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          _InfoBanner(
            title: 'Assisted intake for walk-in citizens',
            message:
                'Enter the complainant details carefully. Walk-in reports stay in the same system as mobile complaints, but the claim slip will show when the citizen should return for updates.',
            colors: colors,
          ),
          const SizedBox(height: 16),
        ],
        if (_formError != null) ...[
          _ErrorBanner(message: _formError!, colors: colors),
          const SizedBox(height: 16),
        ],
        _buildComplainantSection(colors),
        const SizedBox(height: 16),
        _buildComplaintSection(colors),
        const SizedBox(height: 16),
        _buildAttachmentSection(colors),
        if (!compact) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_turned_in_outlined),
              label: Text(
                _saving
                    ? 'Submitting walk-in complaint...'
                    : 'Submit Walk-in Complaint',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComplainantSection(AdminThemeColors colors) {
    return _SectionCard(
      colors: colors,
      title: 'Complainant Details',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= 680;

          if (!twoColumn) {
            return Column(
              children: [
                _textField(
                  controller: _complainantNameController,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                _textField(
                  controller: _complainantMobileController,
                  label: 'Mobile Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  onChanged: _handlePhoneChanged,
                ),
                _textField(
                  controller: _complainantEmailController,
                  label: 'Email Address (optional)',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                _textField(
                  controller: _complainantAddressController,
                  label: 'Address',
                  icon: Icons.home_work_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
              ],
            );
          }

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _textField(
                      controller: _complainantNameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _complainantMobileController,
                      label: 'Mobile Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      onChanged: _handlePhoneChanged,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _textField(
                      controller: _complainantEmailController,
                      label: 'Email Address (optional)',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _complainantAddressController,
                      label: 'Address',
                      icon: Icons.home_work_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComplaintSection(AdminThemeColors colors) {
    return _SectionCard(
      colors: colors,
      title: 'Complaint Details',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= 680;

          if (!twoColumn) {
            return Column(
              children: [
                _buildOfficeField(),
                _buildCategoryField(),
                _buildPriorityField(),
                _buildBarangayField(colors),
                _textField(
                  controller: _locationController,
                  label: 'Location / Landmark (optional)',
                  icon: Icons.place_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                _textField(
                  controller: _titleController,
                  label: 'Complaint Title',
                  icon: Icons.report_problem_outlined,
                  textCapitalization: TextCapitalization.sentences,
                ),
                _buildDescriptionField(),
              ],
            );
          }

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildOfficeField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCategoryField()),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPriorityField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildBarangayField(colors)),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _textField(
                      controller: _locationController,
                      label: 'Location / Landmark (optional)',
                      icon: Icons.place_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _titleController,
                      label: 'Complaint Title',
                      icon: Icons.report_problem_outlined,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ],
              ),
              _buildDescriptionField(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttachmentSection(AdminThemeColors colors) {
    return _SectionCard(
      colors: colors,
      title: 'Return Schedule and Attachments',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= 680;

          final scheduleCard = InkWell(
            onTap: _pickExpectedReturnAt,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.input,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Return Date',
                          style: TextStyle(
                            color: colors.mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(_expectedReturnAt),
                          style: TextStyle(
                            color: colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined),
                ],
              ),
            ),
          );

          final attachmentActions = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add Photo'),
              ),
              OutlinedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_call_outlined),
                label: const Text('Add Video'),
              ),
            ],
          );

          final identityToggle = SwitchListTile.adaptive(
            value: _submitAnonymously,
            onChanged: (value) => setState(() => _submitAnonymously = value),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Submit anonymously',
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Hide the complainant identity from standard report views while keeping the complaint in the real report system.',
              style: TextStyle(color: colors.mutedText),
            ),
          );

          final attachments = _attachments.isEmpty
              ? Text(
                  'No attachments yet. You can add up to 3 photos or videos.',
                  style: TextStyle(color: colors.mutedText),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(_attachments.length, (index) {
                    final attachment = _attachments[index];
                    return Chip(
                      label: SizedBox(
                        width: 180,
                        child: Text(
                          attachment.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onDeleted: () => setState(
                        () => _attachments.removeAt(index),
                      ),
                    );
                  }),
                );

          if (!twoColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                scheduleCard,
                const SizedBox(height: 14),
                attachmentActions,
                const SizedBox(height: 12),
                identityToggle,
                const SizedBox(height: 12),
                attachments,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: scheduleCard),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        attachmentActions,
                        const SizedBox(height: 10),
                        Text(
                          'Add up to 3 photos or videos to support the complaint.',
                          style: TextStyle(color: colors.mutedText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              identityToggle,
              const SizedBox(height: 12),
              attachments,
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfficeField() {
    return _dropdownField<int>(
      value: _selectedOfficeId,
      label: 'Assigned Department',
      items: _offices
          .map(
            (office) => DropdownMenuItem<int>(
              value: (office['id'] as num).toInt(),
              child: Text((office['name'] ?? 'Office').toString()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedOfficeId = value),
    );
  }

  Widget _buildCategoryField() {
    return _dropdownField<int>(
      value: _selectedCategoryId,
      label: 'Complaint Category',
      items: _categories
          .map(
            (category) => DropdownMenuItem<int>(
              value: (category['id'] as num).toInt(),
              child: Text((category['name'] ?? 'Category').toString()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _selectedCategoryId = value),
    );
  }

  Widget _buildPriorityField() {
    return _dropdownField<String>(
      value: _priority,
      label: 'Priority',
      items: const [
        DropdownMenuItem(value: 'Low', child: Text('Low')),
        DropdownMenuItem(value: 'Normal', child: Text('Normal')),
        DropdownMenuItem(value: 'High', child: Text('High')),
        DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
      ],
      onChanged: (value) => setState(() => _priority = value ?? 'Normal'),
    );
  }

  Widget _buildBarangayField(AdminThemeColors colors) {
    return _textField(
      controller: _barangayController,
      label: 'Barangay',
      icon: Icons.map_outlined,
      readOnly: true,
      onTap: _showBarangayPicker,
      suffixIcon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: colors.mutedText,
      ),
    );
  }

  Widget _buildDescriptionField() {
    return _textField(
      controller: _descriptionController,
      label: 'Complaint Description',
      icon: Icons.description_outlined,
      minLines: 4,
      maxLines: 6,
      maxLength: _maxDescriptionLength,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(_maxDescriptionLength),
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final month = _monthLabel(value.month);
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$month ${value.day}, ${value.year} - $hour:$minute $suffix';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onTap: onTap,
        style: TextStyle(color: colors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colors.mutedText),
          prefixIcon: Icon(icon, color: colors.mutedText),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: colors.input,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required T? value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        dropdownColor: colors.panel,
        style: TextStyle(color: colors.text),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: colors.mutedText),
          filled: true,
          fillColor: colors.input,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.colors,
    required this.title,
    required this.child,
  });

  final AdminThemeColors colors;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.title,
    required this.message,
    required this.colors,
  });

  final String title;
  final String message;
  final AdminThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors.topBarGradient),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xDDEAF4FF),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.colors});

  final String message;
  final AdminThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFEF4444),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
