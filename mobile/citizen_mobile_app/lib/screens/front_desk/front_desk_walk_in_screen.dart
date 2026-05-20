import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/tacloban_barangays.dart';
import '../../services/report_service.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class FrontDeskWalkInScreen extends StatefulWidget {
  const FrontDeskWalkInScreen({
    super.key,
    this.reportService,
    this.imagePicker,
    this.officesLoader,
    this.categoriesLoader,
  });

  final ReportService? reportService;
  final ImagePicker? imagePicker;
  final Future<List<dynamic>> Function()? officesLoader;
  final Future<List<dynamic>> Function()? categoriesLoader;

  @override
  State<FrontDeskWalkInScreen> createState() => _FrontDeskWalkInScreenState();
}

enum _WalkInCitizenType { regular, seniorCitizen, pwd }

class _FrontDeskWalkInScreenState extends State<FrontDeskWalkInScreen> {
  static const int _maxAttachments = 3;
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  static const List<String> _priorities = ['Low', 'Normal', 'High', 'Urgent'];

  late final ReportService _reportService;
  late final ImagePicker _imagePicker;

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
  _WalkInCitizenType _selectedCitizenType = _WalkInCitizenType.regular;
  bool _isSubmitting = false;
  DateTime? _expectedReturnAt;
  final List<_SelectedMediaItem> _selectedMedia = [];

  String? _nameError;
  String? _mobileError;
  String? _emailError;
  String? _addressError;
  String? _barangayError;
  String? _locationError;
  String? _titleError;
  String? _descriptionError;
  String? _officeError;
  String? _categoryError;
  String? _expectedReturnError;

  @override
  void initState() {
    super.initState();
    _reportService = widget.reportService ?? ReportService();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _expectedReturnAt = DateTime.now()
        .add(const Duration(days: 3))
        .copyWith(
          hour: 10,
          minute: 0,
          second: 0,
          millisecond: 0,
          microsecond: 0,
        );
    _bootstrapFuture = _loadOptions();
  }

  Future<void> _loadOptions() async {
    final values = await Future.wait<dynamic>([
      (widget.officesLoader ?? _reportService.getOffices).call(),
      (widget.categoriesLoader ?? _reportService.getCategories).call(),
    ]);

    _offices = (values[0] as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _categories = (values[1] as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  bool _containsEmoji(String value) => _emojiRegex.hasMatch(value);

  void _clearErrors() {
    _nameError = null;
    _mobileError = null;
    _emailError = null;
    _addressError = null;
    _barangayError = null;
    _locationError = null;
    _titleError = null;
    _descriptionError = null;
    _officeError = null;
    _categoryError = null;
    _expectedReturnError = null;
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
                  'Attach walk-in evidence',
                  style: TextStyle(
                    color: citizenTitleColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add photo or video files provided during the assisted complaint intake.',
                  style: TextStyle(
                    color: citizenBodyColor(context),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                _MediaOptionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Add photos',
                  subtitle: 'Choose one or more image attachments',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImages();
                  },
                ),
                _MediaOptionTile(
                  icon: Icons.videocam_outlined,
                  title: 'Add video',
                  subtitle: 'Choose one video attachment',
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (files.isEmpty) {
      return;
    }
    await _addSelectedMedia(files, mediaType: 'image');
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      return;
    }
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

    final pendingFiles = files.take(remainingSlots).toList();
    final acceptedItems = <_SelectedMediaItem>[];
    var oversizedCount = 0;

    for (final file in pendingFiles) {
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

    if (!mounted) {
      return;
    }

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

  Future<void> _pickExpectedReturnAt() async {
    final initial =
        _expectedReturnAt ?? DateTime.now().add(const Duration(days: 3));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) {
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
      _expectedReturnError = null;
    });
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Tacloban City barangay',
                      style: TextStyle(
                        color: citizenTitleColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: filter,
                      style: TextStyle(color: citizenTitleColor(context)),
                      decoration: InputDecoration(
                        hintText: 'Search barangay',
                        prefixIcon: Icon(
                          Icons.search_rounded,
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

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _barangayController.text = selected;
      _barangayError = null;
    });
  }

  bool _validateForm() {
    final name = _complainantNameController.text.trim();
    final mobile = _complainantMobileController.text.trim();
    final email = _complainantEmailController.text.trim();
    final address = _complainantAddressController.text.trim();
    final barangay = _barangayController.text.trim();
    final location = _locationController.text.trim();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() {
      _clearErrors();

      if (name.isEmpty) {
        _nameError = 'Complainant name is required.';
      } else if (_containsEmoji(name)) {
        _nameError = 'Emoji characters are not allowed.';
      }

      if (mobile.isEmpty) {
        _mobileError = 'Mobile number is required.';
      } else if (!_isValidMobileNumber(mobile)) {
        _mobileError =
            'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.';
      }

      if (email.isNotEmpty) {
        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (_containsEmoji(email)) {
          _emailError = 'Emoji characters are not allowed.';
        } else if (!emailRegex.hasMatch(email)) {
          _emailError = 'Enter a valid email address.';
        }
      }

      if (address.isEmpty) {
        _addressError = 'Address or barangay details are required.';
      } else if (_containsEmoji(address)) {
        _addressError = 'Emoji characters are not allowed.';
      }

      if (barangay.isEmpty) {
        _barangayError = 'Please select a Tacloban City barangay.';
      } else if (!taclobanBarangays.contains(barangay)) {
        _barangayError = 'Choose a valid Tacloban City barangay from the list.';
      }

      if (location.isEmpty) {
        _locationError = 'Location / landmark is required.';
      } else if (_containsEmoji(location)) {
        _locationError = 'Emoji characters are not allowed.';
      }

      if (title.isEmpty) {
        _titleError = 'Complaint title is required.';
      } else if (_containsEmoji(title)) {
        _titleError = 'Emoji characters are not allowed.';
      }

      if (description.isEmpty) {
        _descriptionError = 'Complaint description is required.';
      } else if (_containsEmoji(description)) {
        _descriptionError = 'Emoji characters are not allowed.';
      }

      if (_selectedOfficeId == null) {
        _officeError =
            'Please select the department that should handle this complaint.';
      }

      if (_selectedCategoryId == null) {
        _categoryError = 'Please select a complaint category.';
      }

      if (_expectedReturnAt == null) {
        _expectedReturnError =
            'Please choose the expected return date and time.';
      }
    });

    return [
      _nameError,
      _mobileError,
      _emailError,
      _addressError,
      _barangayError,
      _locationError,
      _titleError,
      _descriptionError,
      _officeError,
      _categoryError,
      _expectedReturnError,
    ].every((error) => error == null);
  }

  bool _isValidMobileNumber(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'\D+'), '');
    return RegExp(r'^(09\d{9}|9\d{9}|639\d{9})$').hasMatch(digitsOnly);
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_validateForm()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _reportService.createWalkInReport(
        categoryId: _selectedCategoryId,
        officeId: _selectedOfficeId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        barangay: _barangayController.text.trim(),
        walkInFullName: _complainantNameController.text.trim(),
        walkInContactNumber: _complainantMobileController.text.trim(),
        walkInAddress: _complainantAddressController.text.trim(),
        walkInEmail: _complainantEmailController.text.trim(),
        priority: _priority,
        isSeniorCitizen:
            _selectedCitizenType == _WalkInCitizenType.seniorCitizen,
        isPwd: _selectedCitizenType == _WalkInCitizenType.pwd,
        expectedReturnAt: _expectedReturnAt,
        mediaFiles: _selectedMedia.map((item) => item.file).toList(),
      );

      if (!mounted) {
        return;
      }

      final report = Map<String, dynamic>.from(
        (response['report'] as Map?)?.cast<String, dynamic>() ??
            response.cast<String, dynamic>(),
      );

      Navigator.pop(context, report);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
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

  String _formatExpectedReturn() {
    final value = _expectedReturnAt;
    if (value == null) {
      return 'Choose return date and time';
    }
    return '${value.month}/${value.day}/${value.year} ${TimeOfDay.fromDateTime(value).format(context)}';
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
    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(title: const Text('New Assisted Complaint')),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: citizenPageGradient(context)),
        child: FutureBuilder<void>(
          future: _bootstrapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !_hasLoadedOptions) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError && !_hasLoadedOptions) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: citizenBodyColor(context)),
                      ),
                      const SizedBox(height: 16),
                      CitizenPrimaryButton(
                        label: 'Retry',
                        onPressed: () {
                          setState(() => _bootstrapFuture = _loadOptions());
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildIntroCard(context),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Walk-in Complainant Details',
                  subtitle:
                      'Record the citizen information clearly for follow-up and verification.',
                  children: [
                    CitizenTextField(
                      controller: _complainantNameController,
                      label: 'Full Name',
                      hintText: 'Juan Dela Cruz',
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      errorText: _nameError,
                      onChanged: (_) {
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _complainantMobileController,
                      label: 'Mobile Number',
                      hintText: '09123456789',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      errorText: _mobileError,
                      onChanged: (_) {
                        if (_mobileError != null) {
                          setState(() => _mobileError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _complainantEmailController,
                      label: 'Email Address (Optional)',
                      hintText: 'optional@email.com',
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      errorText: _emailError,
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _complainantAddressController,
                      label: 'Home Address',
                      hintText: 'House number, street, purok, or sitio',
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      errorText: _addressError,
                      onChanged: (_) {
                        if (_addressError != null) {
                          setState(() => _addressError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildCitizenTypeSelector(context),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Complaint Details',
                  subtitle:
                      'Select the receiving department, describe the issue clearly, and set the expected follow-up date.',
                  children: [
                    _buildDropdownField<int>(
                      context,
                      label: 'Assigned Department',
                      value: _selectedOfficeId,
                      hint: 'Choose department',
                      items: _offices
                          .map(
                            (office) => DropdownMenuItem<int>(
                              value: office['id'] as int?,
                              child: Text(
                                (office['name'] ?? 'Unknown office').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      errorText: _officeError,
                      onChanged: (value) {
                        setState(() {
                          _selectedOfficeId = value;
                          _officeError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField<int>(
                      context,
                      label: 'Complaint Category',
                      value: _selectedCategoryId,
                      hint: 'Choose category',
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem<int>(
                              value: category['id'] as int?,
                              child: Text(
                                (category['name'] ?? 'Unknown category')
                                    .toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      errorText: _categoryError,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _categoryError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField<String>(
                      context,
                      label: 'Priority',
                      value: _priority,
                      hint: 'Choose priority',
                      items: _priorities
                          .map(
                            (priority) => DropdownMenuItem<String>(
                              value: priority,
                              child: Text(priority),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _priority = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _barangayController,
                      label: 'Barangay',
                      hintText:
                          'Select the barangay where the complaint happened',
                      readOnly: true,
                      onTap: _showBarangayPicker,
                      suffixIcon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: citizenMutedColor(context),
                      ),
                      errorText: _barangayError,
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _locationController,
                      label: 'Location / Landmark',
                      hintText:
                          'Street corner, landmark, purok, or nearby office',
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      errorText: _locationError,
                      onChanged: (_) {
                        if (_locationError != null) {
                          setState(() => _locationError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _titleController,
                      label: 'Complaint Title',
                      hintText: 'Short complaint summary',
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      errorText: _titleError,
                      onChanged: (_) {
                        if (_titleError != null) {
                          setState(() => _titleError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CitizenTextField(
                      controller: _descriptionController,
                      label: 'Complaint Description',
                      hintText:
                          'Describe what happened, when it started, and any important context.',
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 5,
                      maxLines: 7,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      errorText: _descriptionError,
                      onChanged: (_) {
                        if (_descriptionError != null) {
                          setState(() => _descriptionError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildExpectedReturnField(context),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Attachments',
                  subtitle:
                      'Optional photo or video evidence for verification. Up to 3 attachments, 50MB each.',
                  children: [
                    CitizenSecondaryButton(
                      label: 'Add Attachments',
                      icon: Icons.attach_file_outlined,
                      onPressed: _showMediaPickerOptions,
                    ),
                    if (_selectedMedia.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _selectedMedia
                            .asMap()
                            .entries
                            .map(
                              (entry) => _MediaChip(
                                item: entry.value,
                                onRemove: () {
                                  setState(
                                    () => _selectedMedia.removeAt(entry.key),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                CitizenPrimaryButton(
                  label: 'Submit Assisted Complaint',
                  icon: Icons.assignment_turned_in_outlined,
                  loading: _isSubmitting,
                  onPressed: _submit,
                  height: 56,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool get _hasLoadedOptions => _offices.isNotEmpty || _categories.isNotEmpty;

  Widget _buildCitizenTypeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Citizen Type',
          style: TextStyle(
            color: citizenBodyColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        _CitizenTypeOptionCard(
          title: 'Regular Citizen',
          subtitle: 'Default walk-in complaint assistance',
          selected: _selectedCitizenType == _WalkInCitizenType.regular,
          onTap: () {
            setState(() {
              _selectedCitizenType = _WalkInCitizenType.regular;
            });
          },
        ),
        const SizedBox(height: 10),
        _CitizenTypeOptionCard(
          title: 'Senior Citizen',
          subtitle: 'Mark this complaint for senior-citizen follow-up',
          selected: _selectedCitizenType == _WalkInCitizenType.seniorCitizen,
          onTap: () {
            setState(() {
              _selectedCitizenType = _WalkInCitizenType.seniorCitizen;
            });
          },
        ),
        const SizedBox(height: 10),
        _CitizenTypeOptionCard(
          title: 'PWD',
          subtitle: 'Mark this complaint for persons-with-disability support',
          selected: _selectedCitizenType == _WalkInCitizenType.pwd,
          onTap: () {
            setState(() {
              _selectedCitizenType = _WalkInCitizenType.pwd;
            });
          },
        ),
      ],
    );
  }

  Widget _buildIntroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: citizenHeroGradient(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: citizenCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrative Staff Walk-in Assistance',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.98),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use this form when a citizen cannot submit the complaint personally. Select the correct department, set a barangay from the official Tacloban list, and capture enough detail for the receiving office to act immediately.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: citizenBorderColor(context)),
        boxShadow: citizenCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: citizenBodyColor(context),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>(
    BuildContext context, {
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: citizenBodyColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          dropdownColor: citizenDropdownColor(context),
          decoration: InputDecoration(errorText: errorText, hintText: hint),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildExpectedReturnField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Expected Return / Follow-up Date',
          style: TextStyle(
            color: citizenBodyColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickExpectedReturnAt,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: citizenInputColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _expectedReturnError == null
                    ? citizenBorderColor(context)
                    : CitizenAppPalette.error,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: citizenTitleColor(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatExpectedReturn(),
                    style: TextStyle(
                      color: citizenTitleColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expectedReturnError != null) ...[
          const SizedBox(height: 6),
          Text(
            _expectedReturnError!,
            style: const TextStyle(
              color: CitizenAppPalette.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _CitizenTypeOptionCard extends StatelessWidget {
  const _CitizenTypeOptionCard({
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : citizenInputColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.28)
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

class _MediaOptionTile extends StatelessWidget {
  const _MediaOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: citizenInfoSurfaceColor(context),
        child: Icon(icon, color: citizenTitleColor(context)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: citizenTitleColor(context),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: citizenBodyColor(context), fontSize: 12.5),
      ),
      onTap: onTap,
    );
  }
}

class _MediaChip extends StatelessWidget {
  const _MediaChip({required this.item, required this.onRemove});

  final _SelectedMediaItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: citizenInputColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 78,
              width: double.infinity,
              color: citizenCardColor(context),
              child: item.previewBytes == null
                  ? Icon(
                      item.mediaType == 'video'
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      color: citizenMutedColor(context),
                      size: 28,
                    )
                  : Image.memory(item.previewBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.file.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
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
}
