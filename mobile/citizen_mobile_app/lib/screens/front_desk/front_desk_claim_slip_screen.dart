import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/report_model.dart';
import '../../utils/citizen_theme_colors.dart';
import '../../widgets/custom_button.dart';

class FrontDeskClaimSlipScreen extends StatelessWidget {
  const FrontDeskClaimSlipScreen({
    super.key,
    required this.report,
    required this.frontDeskUser,
  });

  final Map<String, dynamic> report;
  final Map<String, dynamic> frontDeskUser;

  String _slipText() {
    final title = CitizenReportModel.titleOf(report);
    final category = CitizenReportModel.categoryNameOf(report);
    final office = CitizenReportModel.officeNameOf(report);
    final complainant = CitizenReportModel.complainantNameOf(report);
    final address = CitizenReportModel.complainantAddressOf(report);
    final contact = CitizenReportModel.complainantContactNumberOf(report);
    final reference = CitizenReportModel.referenceNumberOf(report);
    final submittedAt =
        CitizenReportModel.createdAtOf(report) ?? DateTime.now();
    final expectedReturnAt = CitizenReportModel.expectedReturnAtOf(report);
    final status = CitizenReportModel.displayStatusOf(report);
    final citizenType = _citizenTypeLabel();
    final frontDeskName = (frontDeskUser['name'] ?? 'Administrative Staff')
        .toString()
        .trim();

    return [
      'Tacloban City Citizen Feedback System',
      'Administrative Staff Walk-in Complaint Slip',
      '',
      'Reference Number: $reference',
      'Complainant: $complainant',
      'Citizen Type: $citizenType',
      'Contact Number: $contact',
      'Complaint Title: $title',
      'Category: $category',
      'Assigned Department: $office',
      'Barangay / Address: $address',
      'Date Submitted: ${CitizenReportModel.formatDateTime(submittedAt)}',
      'Expected Return: ${expectedReturnAt == null ? 'To be confirmed' : CitizenReportModel.formatDateTime(expectedReturnAt)}',
      'Current Status: $status',
      'Assisted By: $frontDeskName',
      '',
      'Reminder:',
      'Please keep this slip and bring it when you return for updates. Authorized city personnel may review the submitted details and attachments to verify and resolve the complaint.',
    ].join('\n');
  }

  Future<void> _shareSlip(BuildContext context) async {
    final reference = CitizenReportModel.referenceNumberOf(report);

    try {
      await Share.share(
        _slipText(),
        subject: 'Walk-in Complaint Slip $reference',
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the share sheet on this device.'),
        ),
      );
    }
  }

  Future<void> _copyReference(BuildContext context) async {
    final reference = CitizenReportModel.referenceNumberOf(report);
    await Clipboard.setData(ClipboardData(text: reference));

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Reference $reference copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final reference = CitizenReportModel.referenceNumberOf(report);
    final title = CitizenReportModel.titleOf(report);
    final category = CitizenReportModel.categoryNameOf(report);
    final office = CitizenReportModel.officeNameOf(report);
    final complainant = CitizenReportModel.complainantNameOf(report);
    final address = CitizenReportModel.complainantAddressOf(report);
    final contact = CitizenReportModel.complainantContactNumberOf(report);
    final submittedAt =
        CitizenReportModel.createdAtOf(report) ?? DateTime.now();
    final expectedReturnAt = CitizenReportModel.expectedReturnAtOf(report);
    final status = CitizenReportModel.displayStatusOf(report);
    final citizenType = _citizenTypeLabel();
    final frontDeskName = (frontDeskUser['name'] ?? 'Administrative Staff')
        .toString()
        .trim();

    return Scaffold(
      backgroundColor: citizenScaffoldColor(context),
      appBar: AppBar(
        title: const Text('Claim Slip'),
        actions: [
          IconButton(
            tooltip: 'Copy reference',
            onPressed: () => _copyReference(context),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: 'Share slip',
            onPressed: () => _shareSlip(context),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: citizenPageGradient(context)),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: citizenCardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: citizenBorderColor(context)),
                  boxShadow: citizenCardShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: citizenInfoSurfaceColor(context),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: citizenInfoBorderColor(context),
                        ),
                      ),
                      child: Text(
                        'Administrative Staff Assistance',
                        style: TextStyle(
                          color: citizenInfoTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      reference,
                      style: TextStyle(
                        color: citizenTitleColor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Present this reference when the citizen returns for an update.',
                      style: TextStyle(
                        color: citizenBodyColor(context),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SlipLine(label: 'Complainant', value: complainant),
                    _SlipLine(label: 'Citizen Type', value: citizenType),
                    _SlipLine(label: 'Contact Number', value: contact),
                    _SlipLine(label: 'Complaint Title', value: title),
                    _SlipLine(label: 'Category', value: category),
                    _SlipLine(label: 'Assigned Department', value: office),
                    _SlipLine(label: 'Barangay / Address', value: address),
                    _SlipLine(
                      label: 'Date Submitted',
                      value: CitizenReportModel.formatDateTime(submittedAt),
                    ),
                    _SlipLine(
                      label: 'Expected Return',
                      value: expectedReturnAt == null
                          ? 'To be confirmed'
                          : CitizenReportModel.formatDateTime(expectedReturnAt),
                    ),
                    _SlipLine(label: 'Current Status', value: status),
                    _SlipLine(label: 'Assisted By', value: frontDeskName),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: citizenInfoSurfaceColor(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: citizenInfoBorderColor(context),
                        ),
                      ),
                      child: Text(
                        'Reminder: Authorized city personnel may review submitted details and attachments to verify and resolve the complaint. Please keep this slip and return on or after the expected follow-up date.',
                        style: TextStyle(
                          color: citizenInfoTextColor(context),
                          height: 1.55,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CitizenPrimaryButton(
                label: 'Share / Print Summary',
                icon: Icons.share_outlined,
                onPressed: () => _shareSlip(context),
              ),
              const SizedBox(height: 12),
              CitizenSecondaryButton(
                label: 'Copy Reference Number',
                icon: Icons.copy_outlined,
                onPressed: () => _copyReference(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _citizenTypeLabel() {
    final isSeniorCitizen = CitizenReportModel.complainantIsSeniorCitizenOf(
      report,
    );
    final isPwd = CitizenReportModel.complainantIsPwdOf(report);

    if (isSeniorCitizen && isPwd) {
      return 'Senior Citizen / PWD';
    }
    if (isSeniorCitizen) {
      return 'Senior Citizen';
    }
    if (isPwd) {
      return 'PWD';
    }

    return 'Regular Citizen';
  }
}

class _SlipLine extends StatelessWidget {
  const _SlipLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: citizenMutedColor(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: citizenTitleColor(context),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
