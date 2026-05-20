import 'package:flutter/material.dart';

import '../utils/citizen_theme_colors.dart';

enum CitizenPolicyDocument { terms, privacy, dataUsage }

class CitizenPolicySheet extends StatefulWidget {
  const CitizenPolicySheet({super.key, required this.initialDocument});

  final CitizenPolicyDocument initialDocument;

  static Future<void> show(
    BuildContext context, {
    CitizenPolicyDocument initialDocument = CitizenPolicyDocument.terms,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CitizenPolicySheet(initialDocument: initialDocument),
    );
  }

  @override
  State<CitizenPolicySheet> createState() => _CitizenPolicySheetState();
}

class _CitizenPolicySheetState extends State<CitizenPolicySheet> {
  late CitizenPolicyDocument _selectedDocument;

  @override
  void initState() {
    super.initState();
    _selectedDocument = widget.initialDocument;
  }

  @override
  Widget build(BuildContext context) {
    final data = _documentData(_selectedDocument);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: citizenCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: citizenBorderColor(context)),
          boxShadow: citizenCardShadow(context),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, bottomSafeArea + 14),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: citizenBorderColor(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Policies',
                            style: TextStyle(
                              color: citizenTitleColor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please review these terms before completing registration.',
                            style: TextStyle(
                              color: citizenBodyColor(context),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: citizenMutedColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CitizenPolicyDocument.values.map((document) {
                    final selected = document == _selectedDocument;

                    return ChoiceChip(
                      label: Text(_documentLabel(document)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedDocument = document);
                      },
                      labelStyle: TextStyle(
                        color: selected
                            ? citizenOnPrimaryActionColor(context)
                            : citizenTitleColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                      selectedColor: citizenPrimaryActionColor(context),
                      backgroundColor: citizenInputColor(context),
                      side: BorderSide(
                        color: selected
                            ? citizenPrimaryActionColor(context)
                            : citizenBorderColor(context),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: citizenInfoSurfaceColor(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: citizenInfoBorderColor(context),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title,
                              style: TextStyle(
                                color: citizenInfoTextColor(context),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data.summary,
                              style: TextStyle(
                                color: citizenBodyColor(context),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...data.sections.map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: citizenInputColor(context),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: citizenBorderColor(context),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.heading,
                                  style: TextStyle(
                                    color: citizenTitleColor(context),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...section.points.map(
                                  (point) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: citizenAccentColor(
                                                context,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            point,
                                            style: TextStyle(
                                              color: citizenBodyColor(context),
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _documentLabel(CitizenPolicyDocument document) {
    switch (document) {
      case CitizenPolicyDocument.terms:
        return 'Terms & Conditions';
      case CitizenPolicyDocument.privacy:
        return 'Privacy Policy';
      case CitizenPolicyDocument.dataUsage:
        return 'Data Usage Notice';
    }
  }

  _CitizenPolicyData _documentData(CitizenPolicyDocument document) {
    switch (document) {
      case CitizenPolicyDocument.terms:
        return _CitizenPolicyData(
          title: 'Terms & Conditions',
          summary:
              'These Terms govern your use of the CityTrack citizen mobile app for account access, report submission, feedback, and complaint follow-up within Tacloban City.',
          sections: const [
            _CitizenPolicySection(
              heading: 'Account Responsibilities',
              points: [
                'You must provide truthful, current, and complete personal information when creating a citizen account and keep your login credentials confidential.',
                'You are responsible for all activities performed using your account, including submitted reports, uploaded files, and ratings.',
                'If you suspect unauthorized access, you should update your password immediately and notify the CityTrack support team or the appropriate city office.',
              ],
            ),
            _CitizenPolicySection(
              heading: 'Reports, Evidence, and Review',
              points: [
                'Submitted complaints, feedback entries, attached photos, videos, and related information may be viewed by admins and authorized city personnel for complaint review, verification, routing, investigation, and resolution.',
                'Uploaded photos and videos may be used to verify the existence, severity, and location of a reported concern and to document progress or closure.',
                'Reports may be reassigned to the most appropriate office when needed to ensure proper handling and follow-up.',
              ],
            ),
            _CitizenPolicySection(
              heading: 'Acceptable Use and Moderation',
              points: [
                'You must not use the app to submit false reports, misleading information, offensive content, threats, spam, or media that violates the rights or safety of others.',
                'The CityTrack team may restrict, reject, archive, or remove reports that appear abusive, duplicative, malicious, unlawful, or unrelated to legitimate citizen concerns.',
                'Repeated misuse may result in account deactivation or further review by authorized personnel.',
              ],
            ),
          ],
        );
      case CitizenPolicyDocument.privacy:
        return _CitizenPolicyData(
          title: 'Privacy Policy',
          summary:
              'This Privacy Policy explains how your personal information is collected, used, stored, and protected when you use the CityTrack citizen mobile app.',
          sections: const [
            _CitizenPolicySection(
              heading: 'Information We Collect',
              points: [
                'We collect personal information that you submit, such as your name, email address, mobile number, complaint details, attached media, and the barangay or location related to your report.',
                'We also store account activity needed to secure access, manage sessions, and support complaint tracking, such as timestamps, ratings, and related system events.',
                'If you sign in with Google, the app may receive the verified Google account email and related identity details needed for authentication.',
              ],
            ),
            _CitizenPolicySection(
              heading: 'How Your Information Is Used',
              points: [
                'Your information is used to create and protect your account, route reports to the correct office, communicate status updates, and support citizen feedback and analytics inside the app.',
                'Location and barangay details are used to identify the affected area, help offices validate field issues, and prioritize resolution based on local jurisdiction.',
                'Admins and authorized personnel may access your submissions and attached evidence only as needed for legitimate complaint handling, verification, moderation, and service improvement.',
              ],
            ),
            _CitizenPolicySection(
              heading: 'Security and Retention',
              points: [
                'We use reasonable administrative and technical safeguards to protect your information and to help prevent unauthorized access, disclosure, or misuse.',
                'Your data is retained only as long as necessary for complaint management, audit requirements, service analytics, legal compliance, and system security.',
                'Although we work to protect your information, no online platform can guarantee absolute security, so you should also protect your own password and device access.',
              ],
            ),
          ],
        );
      case CitizenPolicyDocument.dataUsage:
        return _CitizenPolicyData(
          title: 'Data Usage Notice',
          summary:
              'Before registering, please understand how complaint and profile data move through the CityTrack workflow.',
          sections: const [
            _CitizenPolicySection(
              heading: 'Complaint Processing',
              points: [
                'Your submitted concern may be reviewed by admins, department staff, and other authorized city personnel responsible for validation, escalation, and resolution.',
                'Attached photos or videos may be used as supporting evidence for verification, field coordination, documentation of response actions, and final resolution updates.',
                'Complaint details may appear in dashboards, queues, analytics summaries, and case histories used to manage public service performance.',
              ],
            ),
            _CitizenPolicySection(
              heading: 'Location and Contact Details',
              points: [
                'Barangay and location details help identify where the issue happened and whether the selected office has authority to respond.',
                'Your contact details may be used for account recovery, security notices, clarification requests, or status updates related to your submission.',
                'Only relevant personnel should access your report data, and it should be handled securely within the CityTrack service workflow.',
              ],
            ),
            _CitizenPolicySection(
              heading: 'Your Acknowledgement',
              points: [
                'By continuing with registration, you acknowledge that report information, media uploads, and account data may be processed for legitimate public service operations.',
                'You also acknowledge that misuse, fraud, harassment, or intentionally false reporting may trigger moderation, restriction, or account action.',
                'If you do not agree with these practices, you should not complete citizen account registration.',
              ],
            ),
          ],
        );
    }
  }
}

class _CitizenPolicyData {
  const _CitizenPolicyData({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<_CitizenPolicySection> sections;
}

class _CitizenPolicySection {
  const _CitizenPolicySection({required this.heading, required this.points});

  final String heading;
  final List<String> points;
}
