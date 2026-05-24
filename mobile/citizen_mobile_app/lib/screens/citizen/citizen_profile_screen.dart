import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../services/citizen_avatar_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/app_theme_controller.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/citizen_avatar.dart';
import '../../widgets/citizen_bottom_nav.dart';
import '../../widgets/theme_mode_toggle.dart';
import 'citizen_home_screen.dart';
import 'citizen_notifications_screen.dart';
import 'my_complaints_screen.dart';
import 'send_feedback_screen.dart';
import 'submit_complaint_screen.dart';

class _CitizenProfileValidators {
  static final RegExp emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  static bool isValidFullName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return false;
    }

    final partRegex = RegExp(r"^[A-Za-z]+(?:[.'-][A-Za-z]+)*\.?$");
    return parts.every(partRegex.hasMatch);
  }

  static String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Full name is required.';
    if (emojiRegex.hasMatch(trimmed)) {
      return 'Emoji characters are not allowed.';
    }
    if (!isValidFullName(trimmed)) {
      return 'Enter your first and last name.';
    }
    return null;
  }

  static String? validateEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Email address is required.';
    if (emojiRegex.hasMatch(trimmed)) {
      return 'Emoji characters are not allowed.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validateMobile(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d{11}$').hasMatch(trimmed)) {
      return 'Mobile number must be exactly 11 digits.';
    }
    return null;
  }
}

class CitizenProfileScreen extends StatefulWidget {
  const CitizenProfileScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<CitizenProfileScreen> createState() => _CitizenProfileScreenState();
}

class _CitizenProfileScreenState extends State<CitizenProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoggingOut = false;
  bool _isSavingProfile = false;
  bool _isSavingAvatar = false;
  late Map<String, dynamic> _user;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    CitizenAvatarService.syncFromUser(_user);
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await _authService.logout();
    } catch (_) {
      // Local logout still completes below even if the API call fails.
    }

    CitizenDataCache.clear();
    await CitizenAvatarService.clearAvatar();

    if (!mounted) {
      return;
    }

    setState(() => _isLoggingOut = false);
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _openEditProfile() async {
    final updatedUser = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCitizenProfileSheet(
        initialName: (_user['name'] ?? '').toString(),
        initialEmail: (_user['email'] ?? '').toString(),
        initialMobile: (_user['mobile_number'] ?? '').toString(),
      ),
    );

    if (updatedUser == null || !mounted) {
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final response = await _authService.updateProfile(
        name: updatedUser['name'].toString(),
        email: updatedUser['email'].toString(),
        mobileNumber: updatedUser['mobile_number'].toString(),
      );

      if (!mounted) return;

      setState(() {
        _user = Map<String, dynamic>.from(
          response['user'] as Map<String, dynamic>,
        );
      });
      CitizenDataCache.updateUser(_user);
      CitizenAvatarService.syncFromUser(_user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final croppedBytes = await _openAvatarCropper(bytes);
      if (croppedBytes == null) return;

      setState(() => _isSavingAvatar = true);

      final response = await _authService.uploadProfileImage(
        imageBytes: croppedBytes,
      );
      final updatedUser = response['user'] as Map<String, dynamic>?;
      if (updatedUser != null) {
        _user = Map<String, dynamic>.from(updatedUser);
        CitizenDataCache.updateUser(_user);
        CitizenAvatarService.syncFromUser(_user);
      }

      if (!mounted) return;
      setState(() => _isSavingAvatar = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<Uint8List?> _openAvatarCropper(Uint8List imageBytes) {
    final boundaryKey = GlobalKey();
    final transformController = TransformationController();
    var saving = false;

    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) {
        final isDark = citizenIsDark(dialogContext);
        final titleColor = citizenTitleColor(dialogContext);
        final bodyColor = citizenBodyColor(dialogContext);
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final cropSize = (screenWidth - 96).clamp(196.0, 232.0).toDouble();

        Future<void> saveCrop(StateSetter setDialogState) async {
          setDialogState(() => saving = true);

          try {
            final boundary =
                boundaryKey.currentContext?.findRenderObject()
                    as RenderRepaintBoundary?;
            if (boundary == null) {
              throw Exception('Unable to prepare cropped image.');
            }

            final pixelRatio = View.of(
              dialogContext,
            ).devicePixelRatio.clamp(1.0, 1.6).toDouble();
            final image = await boundary.toImage(pixelRatio: pixelRatio);
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final bytes = byteData?.buffer.asUint8List();

            if (bytes == null || bytes.isEmpty) {
              throw Exception('Unable to crop selected image.');
            }

            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop(bytes);
            }
          } catch (e) {
            if (!dialogContext.mounted) return;
            setDialogState(() => saving = false);
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceFirst('Exception: ', '')),
              ),
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: citizenCardColor(dialogContext),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : citizenBorderColor(dialogContext),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Crop profile photo',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded, color: bodyColor),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drag to reposition. Pinch or double tap to zoom before saving.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: cropSize,
                      height: cropSize,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: citizenHeroGradient(dialogContext),
                        boxShadow: [
                          BoxShadow(
                            color: citizenPrimaryActionColor(
                              dialogContext,
                            ).withValues(alpha: 0.25),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: RepaintBoundary(
                          key: boundaryKey,
                          child: ColoredBox(
                            color: citizenInputColor(dialogContext),
                            child: GestureDetector(
                              onDoubleTap: () {
                                final currentScale = transformController.value
                                    .getMaxScaleOnAxis();
                                transformController.value = currentScale > 1.2
                                    ? Matrix4.identity()
                                    : Matrix4.diagonal3Values(1.8, 1.8, 1);
                              },
                              child: InteractiveViewer(
                                transformationController: transformController,
                                minScale: 1,
                                maxScale: 4,
                                boundaryMargin: const EdgeInsets.all(90),
                                child: Image.memory(
                                  imageBytes,
                                  width: cropSize,
                                  height: cropSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () {
                                    transformController.value =
                                        Matrix4.identity();
                                  },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () => saveCrop(setDialogState),
                            icon: saving
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 18),
                            label: Text(saving ? 'Saving...' : 'Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(transformController.dispose);
  }

  Future<void> _openHome() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CitizenHomeScreen()),
    );
  }

  Future<void> _openReports() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MyComplaintsScreen()),
    );
  }

  Future<void> _openUpdates() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CitizenNotificationsScreen()),
    );
  }

  Future<void> _openSubmit() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
    );

    if (!mounted) return;
    if (created != null) {
      if (created is Map<String, dynamic>) {
        CitizenDataCache.prependReport(created);
      } else {
        CitizenDataCache.invalidateReports();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user['name'] ?? 'Citizen').toString();
    final email = (_user['email'] ?? 'No email').toString();
    final mobile = (_user['mobile_number'] ?? 'No mobile number').toString();
    final role = (_user['role'] ?? 'citizen').toString();
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final bottomContentPadding = bottomSafeArea + 116;
    final themeController = AppThemeScope.of(context);
    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ThemeModeToggle(compact: true),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: citizenPageGradient(context)),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 18, 16, bottomContentPadding),
          children: [
            _buildHeroCard(name, email, role),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 420;

                if (stacked) {
                  return Column(
                    children: [
                      _ProfileStatCard(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: _prettyRole(role),
                      ),
                      const SizedBox(height: 12),
                      _ProfileStatCard(
                        icon: Icons.call_outlined,
                        label: 'Mobile',
                        value: mobile == 'No mobile number'
                            ? 'Not set'
                            : mobile,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _ProfileStatCard(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: _prettyRole(role),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileStatCard(
                        icon: Icons.call_outlined,
                        label: 'Mobile',
                        value: mobile == 'No mobile number'
                            ? 'Not set'
                            : mobile,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _buildActionCard(
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit profile',
                    subtitle: 'Update your name, email, and mobile number',
                    trailing: _isSavingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isSavingProfile ? null : _openEditProfile,
                  ),
                  Divider(height: 1, color: citizenBorderColor(context)),
                  AnimatedBuilder(
                    animation: themeController,
                    builder: (context, _) {
                      final isDarkMode = themeController.isDarkMode;
                      return _ActionTile(
                        icon: isDarkMode
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        title: 'Appearance',
                        subtitle: isDarkMode
                            ? 'Dark mode is active'
                            : 'Light mode is active',
                        trailing: Switch.adaptive(
                          value: isDarkMode,
                          activeThumbColor: citizenHighlightColor(context),
                          activeTrackColor: citizenPrimaryActionColor(
                            context,
                          ).withValues(alpha: 0.45),
                          inactiveThumbColor: citizenAccentColor(context),
                          inactiveTrackColor: citizenInputColor(
                            context,
                          ).withValues(alpha: 0.72),
                          onChanged: themeController.setDarkMode,
                        ),
                        onTap: () => themeController.setDarkMode(!isDarkMode),
                      );
                    },
                  ),
                  Divider(height: 1, color: citizenBorderColor(context)),
                  _ActionTile(
                    icon: Icons.description_outlined,
                    title: 'My reports',
                    subtitle: 'View all your submitted complaints',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyComplaintsScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: citizenBorderColor(context)),
                  _ActionTile(
                    icon: Icons.rate_review_outlined,
                    title: 'Send feedback',
                    subtitle: 'Share suggestions, complaints, or praise',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SendFeedbackScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: citizenBorderColor(context)),
                  _ActionTile(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of this citizen account',
                    iconColor: CitizenAppPalette.error,
                    titleColor: CitizenAppPalette.error,
                    trailing: _isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isLoggingOut ? null : _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CitizenBottomNav(
        currentIndex: 4,
        onHomeTap: _openHome,
        onReportsTap: _openReports,
        onUpdatesTap: _openUpdates,
        onProfileTap: () {},
      ),
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: citizenPrimaryActionColor(context),
          onPressed: _openSubmit,
          child: Icon(
            Icons.add,
            color: citizenOnPrimaryActionColor(context),
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  String _prettyRole(String role) {
    if (role.trim().isEmpty) return 'Citizen';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Widget _buildHeroCard(String name, String email, String role) {
    final titleColor = citizenTitleColor(context);
    final bodyColor = citizenBodyColor(context);
    final roleBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: citizenPrimaryActionColor(context).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: citizenPrimaryActionColor(context).withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        _prettyRole(role),
        style: TextStyle(
          color: citizenPrimaryActionColor(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget avatarStack() {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          CitizenAvatar(
            name: name,
            size: 76,
            backgroundColor: citizenHighlightColor(
              context,
            ).withValues(alpha: citizenIsDark(context) ? 0.18 : 0.14),
            textColor: citizenTitleColor(context),
            fontSize: 26,
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: InkWell(
              onTap: _isSavingAvatar ? null : _pickProfileImage,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: citizenPrimaryActionColor(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: citizenScaffoldColor(context),
                    width: 2,
                  ),
                ),
                child: _isSavingAvatar
                    ? Padding(
                        padding: const EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: citizenOnPrimaryActionColor(context),
                        ),
                      )
                    : Icon(
                        Icons.camera_alt_rounded,
                        color: citizenOnPrimaryActionColor(context),
                        size: 16,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    Widget actionButtons({required bool wide}) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: wide ? WrapAlignment.start : WrapAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: _isSavingProfile ? null : _openEditProfile,
            icon: _isSavingProfile
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: citizenPrimaryActionColor(context),
                    ),
                  )
                : const Icon(Icons.edit_outlined, size: 18),
            label: Text(_isSavingProfile ? 'Saving...' : 'Edit profile'),
            style: FilledButton.styleFrom(
              backgroundColor: citizenPrimaryActionColor(
                context,
              ).withValues(alpha: 0.14),
              foregroundColor: citizenPrimaryActionColor(context),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isSavingAvatar ? null : _pickProfileImage,
            icon: _isSavingAvatar
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: citizenPrimaryActionColor(context),
                    ),
                  )
                : const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_isSavingAvatar ? 'Uploading...' : 'Change photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: citizenTitleColor(context),
              side: BorderSide(color: citizenBorderColor(context)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      );
    }

    Widget infoColumn({required bool wide}) {
      return Column(
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(color: bodyColor, height: 1.35),
          ),
          const SizedBox(height: 12),
          wide ? roleBadge : Center(child: roleBadge),
          const SizedBox(height: 14),
          actionButtons(wide: wide),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: citizenBorderColor(context)),
        boxShadow: citizenCardShadow(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 430;

          if (!isWide) {
            return Column(
              children: [
                avatarStack(),
                const SizedBox(height: 14),
                infoColumn(wide: false),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatarStack(),
              const SizedBox(width: 18),
              Expanded(child: infoColumn(wide: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: child,
    );
  }
}

class _EditCitizenProfileSheet extends StatefulWidget {
  const _EditCitizenProfileSheet({
    required this.initialName,
    required this.initialEmail,
    required this.initialMobile,
  });

  final String initialName;
  final String initialEmail;
  final String initialMobile;

  @override
  State<_EditCitizenProfileSheet> createState() =>
      _EditCitizenProfileSheetState();
}

class _EditCitizenProfileSheetState extends State<_EditCitizenProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;

  String? _nameError;
  String? _emailError;
  String? _mobileError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
    _mobileController = TextEditingController(text: widget.initialMobile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() {
      _nameError = _CitizenProfileValidators.validateName(_nameController.text);
      _emailError = _CitizenProfileValidators.validateEmail(
        _emailController.text,
      );
      _mobileError = _CitizenProfileValidators.validateMobile(
        _mobileController.text,
      );
    });

    if (_nameError != null || _emailError != null || _mobileError != null) {
      return;
    }

    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'mobile_number': _mobileController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        bottomInset + bottomSafeArea + 16,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: citizenCardColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: citizenBorderColor(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: TextStyle(
                color: citizenTitleColor(context),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildInputLabel('Full name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: citizenTitleColor(context)),
              cursorColor: citizenPrimaryActionColor(context),
              inputFormatters: [
                FilteringTextInputFormatter.deny(
                  _CitizenProfileValidators.emojiRegex,
                ),
              ],
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
              decoration: _profileInputDecoration(
                hint: 'Enter your full name',
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 14),
            _buildInputLabel('Email address'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: citizenTitleColor(context)),
              cursorColor: citizenPrimaryActionColor(context),
              inputFormatters: [
                FilteringTextInputFormatter.deny(
                  _CitizenProfileValidators.emojiRegex,
                ),
              ],
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
              decoration: _profileInputDecoration(
                hint: 'Enter your email',
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 14),
            _buildInputLabel('Mobile number'),
            const SizedBox(height: 8),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: citizenTitleColor(context)),
              cursorColor: citizenPrimaryActionColor(context),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) {
                if (_mobileError != null) {
                  setState(() => _mobileError = null);
                }
              },
              decoration: _profileInputDecoration(
                hint: '09123456789',
                errorText: _mobileError,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: citizenPrimaryActionColor(context),
                  foregroundColor: citizenOnPrimaryActionColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: citizenBodyColor(context),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _profileInputDecoration({
    required String hint,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: citizenMutedColor(context)),
      filled: true,
      fillColor: citizenInputColor(context),
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
          width: 1.4,
        ),
      ),
      errorText: errorText,
      errorMaxLines: 2,
      errorStyle: TextStyle(
        color: CitizenAppPalette.error.withValues(alpha: 0.92),
        fontSize: 12,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: CitizenAppPalette.error,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: CitizenAppPalette.error,
          width: 1.3,
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: citizenPrimaryActionColor(context)),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(color: citizenBodyColor(context), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final defaultTitleColor = citizenTitleColor(context);
    final mutedColor = citizenBodyColor(context);
    final chevronColor = citizenMutedColor(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor ?? defaultTitleColor),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? defaultTitleColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: mutedColor)),
      trailing: trailing ?? Icon(Icons.chevron_right, color: chevronColor),
      onTap: onTap,
    );
  }
}
