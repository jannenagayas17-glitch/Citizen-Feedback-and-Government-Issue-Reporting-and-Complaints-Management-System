import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/citizen_feedback_service.dart';
import '../../services/citizen_data_cache.dart';
import '../../utils/citizen_theme_colors.dart';

class SendFeedbackScreen extends StatefulWidget {
  const SendFeedbackScreen({super.key});

  @override
  State<SendFeedbackScreen> createState() => _SendFeedbackScreenState();
}

class _SendFeedbackScreenState extends State<SendFeedbackScreen> {
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  final CitizenFeedbackService _feedbackService = CitizenFeedbackService();
  final TextEditingController _messageController = TextEditingController();

  late Future<List<dynamic>> _officesFuture;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  String _feedbackType = 'Suggestion';
  int? _selectedOfficeId;
  int _rating = 4;
  bool _isSubmitting = false;

  String? _officeError;
  String? _messageError;

  @override
  void initState() {
    super.initState();
    _officesFuture = CitizenDataCache.getOffices();
    _historyFuture = _feedbackService.getFeedbackEntries();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final message = _messageController.text.trim();

    setState(() {
      _officeError = _selectedOfficeId == null
          ? 'Please select a department.'
          : null;
      _messageError = null;

      if (message.isEmpty) {
        _messageError = 'Please write your feedback.';
      } else if (_emojiRegex.hasMatch(message)) {
        _messageError = 'Emoji characters are not allowed.';
      }
    });

    if (_officeError != null || _messageError != null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _feedbackService.saveFeedbackEntry(
        officeId: _selectedOfficeId!,
        type: _feedbackType,
        message: message,
        rating: _rating,
      );
      final feedbackMessage =
          (response['message'] ?? 'Feedback sent successfully.')
              .toString()
              .trim();

      if (!mounted) return;

      setState(() {
        _messageController.clear();
        _selectedOfficeId = null;
        _rating = 4;
        _historyFuture = _feedbackService.getFeedbackEntries();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(feedbackMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        backgroundColor: citizenScaffoldColor(context),
        foregroundColor: citizenTitleColor(context),
        elevation: 0,
        titleSpacing: 0,
        title: const Text('Send Feedback'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _officesFuture,
        builder: (context, officeSnapshot) {
          if (officeSnapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          if (officeSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  officeSnapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: citizenTitleColor(context)),
                ),
              ),
            );
          }

          final offices = officeSnapshot.data ?? const <dynamic>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              _buildInfoBanner(),
              const SizedBox(height: 16),
              _buildFormCard(offices),
              const SizedBox(height: 18),
              _buildSectionLabel('Rate the Service'),
              const SizedBox(height: 10),
              _buildRatingRow(),
              const SizedBox(height: 18),
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
                          'Send Feedback',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: citizenBorderColor(context)),
              const SizedBox(height: 14),
              _buildSectionLabel('Previous Feedback'),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  final entries =
                      snapshot.data ?? const <Map<String, dynamic>>[];
                  if (entries.isEmpty) {
                    return _buildEmptyHistoryCard();
                  }

                  return Column(
                    children: entries
                        .take(5)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildHistoryCard(entry),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenInfoSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: citizenInfoBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your voice matters!',
            style: TextStyle(
              color: citizenInfoTextColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Help us improve city services by sharing suggestions, complaints, or praise.',
            style: TextStyle(
              color: citizenBodyColor(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(List<dynamic> offices) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Feedback Type'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTypeChip(
                  label: 'Suggestion',
                  icon: Icons.lightbulb_rounded,
                  accent: citizenPrimaryActionColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTypeChip(
                  label: 'Complaint',
                  icon: Icons.warning_amber_rounded,
                  accent: citizenHighlightColor(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTypeChip(
                  label: 'Praise',
                  icon: Icons.celebration_rounded,
                  accent: citizenAccentColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Regarding'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedOfficeId,
            isExpanded: true,
            dropdownColor: citizenDropdownColor(context),
            style: TextStyle(color: citizenTitleColor(context)),
            iconEnabledColor: citizenBodyColor(context),
            decoration: _buildInputDecoration(
              'Select department',
              errorText: _officeError,
            ),
            items: offices
                .map((item) {
                  final office = item as Map<String, dynamic>;
                  final rawId = office['id'];
                  final officeId = rawId is int
                      ? rawId
                      : int.tryParse('$rawId');
                  if (officeId == null) return null;
                  return DropdownMenuItem<int>(
                    value: officeId,
                    child: Text(
                      (office['name'] ?? 'Unnamed office').toString(),
                    ),
                  );
                })
                .whereType<DropdownMenuItem<int>>()
                .toList(),
            onChanged: (value) => setState(() => _selectedOfficeId = value),
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Your Message'),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            minLines: 5,
            maxLines: 6,
            style: TextStyle(color: citizenTitleColor(context)),
            inputFormatters: [FilteringTextInputFormatter.deny(_emojiRegex)],
            decoration: _buildInputDecoration(
              'Write your feedback here...',
              errorText: _messageError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required IconData icon,
    required Color accent,
  }) {
    final isSelected = _feedbackType == label;

    return InkWell(
      onTap: () => setState(() => _feedbackType = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.18)
              : citizenInputColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : citizenBorderColor(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? accent : citizenMutedColor(context),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? citizenTitleColor(context)
                      : citizenBodyColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow() {
    return Row(
      children: List.generate(5, (index) {
        final star = index + 1;
        final isSelected = star <= _rating;

        return InkWell(
          onTap: () => setState(() => _rating = star),
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              Icons.star_rounded,
              size: 40,
              color: isSelected
                  ? citizenHighlightColor(context)
                  : citizenBorderColor(context),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final type = (entry['type'] ?? 'Feedback').toString();
    final office = entry['office'];
    final report = entry['report'];
    final officeName = office is Map<String, dynamic>
        ? (office['name'] ?? 'Department').toString()
        : 'Department';
    final reportTitle = report is Map<String, dynamic>
        ? (report['title'] ?? '').toString().trim()
        : '';
    final message = (entry['message'] ?? '').toString();
    final submittedAt = DateTime.tryParse(
      (entry['created_at'] ?? '').toString(),
    );
    final isDark = citizenIsDark(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: citizenInputColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _feedbackIcon(type),
              color: isDark
                  ? citizenHighlightColor(context)
                  : citizenPrimaryActionColor(context),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: citizenTitleColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reportTitle.isNotEmpty ? '$reportTitle | ' : ''}$type | $officeName | ${_formatDate(submittedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: citizenBodyColor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: citizenCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: citizenBorderColor(context)),
      ),
      child: Text(
        'No feedback sent yet.',
        style: TextStyle(color: citizenBodyColor(context)),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
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

  InputDecoration _buildInputDecoration(String hint, {String? errorText}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: citizenInputColor(context),
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

  IconData _feedbackIcon(String type) {
    switch (type) {
      case 'Suggestion':
        return Icons.lightbulb_rounded;
      case 'Complaint':
        return Icons.warning_amber_rounded;
      case 'Praise':
        return Icons.celebration_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Unknown date';
    }

    const months = <String>[
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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
