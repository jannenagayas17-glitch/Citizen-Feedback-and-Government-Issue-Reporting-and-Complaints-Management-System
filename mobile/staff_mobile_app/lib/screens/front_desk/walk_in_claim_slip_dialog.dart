import 'dart:convert';

import 'package:flutter/material.dart';

import '../../utils/admin_theme.dart';
import '../../utils/file_download.dart';

String _formatClaimSlipDateTime(dynamic raw) {
  final parsed = DateTime.tryParse((raw ?? '').toString())?.toLocal();
  if (parsed == null) {
    return 'To be confirmed';
  }

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
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} - $hour:$minute $suffix';
}

Future<void> showWalkInClaimSlipDialog({
  required BuildContext context,
  required Map<String, dynamic> report,
  required Map<String, dynamic> frontDeskUser,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _WalkInClaimSlipDialog(
      report: report,
      frontDeskUser: frontDeskUser,
      onDownload: () => downloadWalkInClaimSlip(
        context: dialogContext,
        report: report,
        frontDeskUser: frontDeskUser,
      ),
    ),
  );
}

Future<void> downloadWalkInClaimSlip({
  required BuildContext context,
  required Map<String, dynamic> report,
  required Map<String, dynamic> frontDeskUser,
}) async {
  final html = _buildClaimSlipHtml(report, frontDeskUser);
  final referenceNumber =
      (report['printable_reference_number'] ?? 'walk-in-claim-slip')
          .toString()
          .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '-');

  try {
    await downloadFile(
      bytes: utf8.encode(html),
      fileName: '$referenceNumber.html',
      mimeType: 'text/html;charset=utf-8',
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printable claim slip downloaded.')),
    );
  } on UnsupportedError {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Printable HTML download is currently available on the web portal build.',
        ),
      ),
    );
  }
}

String _buildClaimSlipHtml(
  Map<String, dynamic> report,
  Map<String, dynamic> user,
) {
  final escape = const HtmlEscape();
  String safe(Object? value) => escape.convert((value ?? '').toString());

  final category = _claimSlipCategoryLabel(report);
  final office = _claimSlipOfficeLabel(report);
  final complainant = _claimSlipComplainantName(report);
  final address = _claimSlipComplainantAddress(report);
  final submittedAt = _formatClaimSlipDateTime(report['created_at']);
  final expectedReturnAt = _formatClaimSlipDateTime(report['expected_return_at']);
  final status = (report['status'] ?? 'New').toString();
  final referenceNumber =
      (report['printable_reference_number'] ?? 'Pending reference').toString();
  final frontDeskName = (user['name'] ?? 'Front Desk Staff').toString();
  final title = (report['title'] ?? 'Walk-in complaint').toString();

  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${safe(referenceNumber)} Claim Slip</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f5f7fb; color: #0b1d51; margin: 0; padding: 32px; }
    .sheet { max-width: 760px; margin: 0 auto; background: #ffffff; border: 2px solid #0b1d51; border-radius: 18px; padding: 28px; }
    .header { border-bottom: 2px solid #d1c6ad; padding-bottom: 18px; margin-bottom: 20px; }
    .title { font-size: 28px; font-weight: 800; margin: 0 0 6px; }
    .subtitle { color: #797596; margin: 0; }
    .badge { display: inline-block; padding: 8px 14px; border-radius: 999px; background: #0b1d51; color: white; font-weight: 700; margin-top: 14px; }
    .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; margin: 18px 0; }
    .card { background: #f8f3ea; border: 1px solid #d1c6ad; border-radius: 14px; padding: 14px; }
    .label { color: #797596; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 6px; }
    .value { color: #0b1d51; font-size: 15px; font-weight: 700; line-height: 1.4; }
    .message { margin-top: 22px; padding: 16px; border-radius: 14px; background: #edf2fb; border: 1px solid #bbada0; color: #0b1d51; line-height: 1.6; }
    .footer { margin-top: 24px; color: #797596; font-size: 12px; }
    @media print { body { background: white; padding: 0; } .sheet { border-radius: 0; margin: 0; box-shadow: none; } }
  </style>
</head>
<body>
  <div class="sheet">
    <div class="header">
      <div class="title">Citizen Walk-in Claim Slip</div>
      <p class="subtitle">Tacloban City Citizen Feedback and Complaint Assistance</p>
      <div class="badge">${safe(referenceNumber)}</div>
    </div>
    <div class="grid">
      <div class="card"><div class="label">Complainant</div><div class="value">${safe(complainant)}</div></div>
      <div class="card"><div class="label">Category / Title</div><div class="value">${safe(category)}<br>${safe(title)}</div></div>
      <div class="card"><div class="label">Assigned Department</div><div class="value">${safe(office)}</div></div>
      <div class="card"><div class="label">Status</div><div class="value">${safe(status)}</div></div>
      <div class="card"><div class="label">Address / Barangay</div><div class="value">${safe(address)}</div></div>
      <div class="card"><div class="label">Submitted</div><div class="value">${safe(submittedAt)}</div></div>
      <div class="card"><div class="label">Expected Return</div><div class="value">${safe(expectedReturnAt)}</div></div>
      <div class="card"><div class="label">Assisted By</div><div class="value">${safe(frontDeskName)}</div></div>
    </div>
    <div class="message">
      Please keep this slip and return on the scheduled date for a status update. The assigned department may contact you sooner if clarification or additional evidence is needed.
    </div>
    <div class="footer">
      This receipt confirms that your complaint was received through the city front desk assistance process.
    </div>
  </div>
</body>
</html>
''';
}

String _claimSlipCategoryLabel(Map<String, dynamic> report) {
  return (report['category']?['name'] ?? report['category_name'] ?? 'General')
      .toString();
}

String _claimSlipOfficeLabel(Map<String, dynamic> report) {
  return (report['office']?['name'] ?? 'Assigned Department').toString();
}

String _claimSlipComplainantName(Map<String, dynamic> report) {
  return (report['complainant_name'] ??
          report['reporter_name'] ??
          report['user']?['name'] ??
          'Walk-in complainant')
      .toString();
}

String _claimSlipComplainantAddress(Map<String, dynamic> report) {
  final address = (report['complainant_address'] ?? '').toString().trim();
  if (address.isNotEmpty) {
    return address;
  }

  final barangay = (report['barangay'] ?? '').toString().trim();
  return barangay.isEmpty ? 'Tacloban City' : '$barangay, Tacloban City';
}

class _WalkInClaimSlipDialog extends StatelessWidget {
  const _WalkInClaimSlipDialog({
    required this.report,
    required this.frontDeskUser,
    required this.onDownload,
  });

  final Map<String, dynamic> report;
  final Map<String, dynamic> frontDeskUser;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final complainantName = _claimSlipComplainantName(report);
    final office = _claimSlipOfficeLabel(report);
    final status = (report['status'] ?? 'New').toString();
    final category = _claimSlipCategoryLabel(report);
    final expectedReturn = _formatClaimSlipDateTime(report['expected_return_at']);
    final referenceNumber =
        (report['printable_reference_number'] ?? 'Pending reference')
            .toString();
    final frontDeskName =
        (frontDeskUser['name'] ?? 'Front Desk Staff').toString();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Walk-in Claim Slip',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reference $referenceNumber',
                style: TextStyle(color: colors.mutedText),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ClaimSlipField(
                    label: 'Complainant',
                    value: complainantName,
                    colors: colors,
                  ),
                  _ClaimSlipField(
                    label: 'Department',
                    value: office,
                    colors: colors,
                  ),
                  _ClaimSlipField(
                    label: 'Category',
                    value: category,
                    colors: colors,
                  ),
                  _ClaimSlipField(
                    label: 'Status',
                    value: status,
                    colors: colors,
                  ),
                  _ClaimSlipField(
                    label: 'Expected Return',
                    value: expectedReturn,
                    colors: colors,
                  ),
                  _ClaimSlipField(
                    label: 'Assisted By',
                    value: frontDeskName,
                    colors: colors,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.input,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'Please keep this slip and return on the scheduled date for a status update.',
                  style: TextStyle(color: colors.text, height: 1.5),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download Slip'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimSlipField extends StatelessWidget {
  const _ClaimSlipField({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AdminThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.input,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
