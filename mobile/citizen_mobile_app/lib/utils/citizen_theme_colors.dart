import 'package:flutter/material.dart';

class CitizenAppPalette {
  static const Color sand = Color(0xFFD1C6AD);
  static const Color taupe = Color(0xFFBBADA0);
  static const Color mauve = Color(0xFFA1869E);
  static const Color slate = Color(0xFF797596);
  static const Color navy = Color(0xFF0B1D51);

  static const Color error = Color(0xFFB65353);
  static const Color success = Color(0xFF4E6A61);
}

bool citizenIsDark(BuildContext context) {
  return Theme.of(context).colorScheme.brightness == Brightness.dark;
}

Color citizenScaffoldColor(BuildContext context) {
  return citizenIsDark(context)
      ? _blend(CitizenAppPalette.navy, Colors.black, 0.14)
      : const Color(0xFFF8F4EE);
}

Color citizenCardColor(BuildContext context) {
  return citizenIsDark(context)
      ? _blend(CitizenAppPalette.navy, CitizenAppPalette.slate, 0.22)
      : Colors.white;
}

Color citizenInputColor(BuildContext context) {
  return citizenIsDark(context)
      ? _blend(CitizenAppPalette.navy, CitizenAppPalette.slate, 0.30)
      : _blend(CitizenAppPalette.sand, Colors.white, 0.62);
}

Color citizenTitleColor(BuildContext context) {
  return citizenIsDark(context)
      ? const Color(0xFFF8F2E8)
      : CitizenAppPalette.navy;
}

Color citizenBodyColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.sand.withValues(alpha: 0.76)
      : _blend(CitizenAppPalette.navy, CitizenAppPalette.slate, 0.62);
}

Color citizenMutedColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.taupe.withValues(alpha: 0.66)
      : CitizenAppPalette.slate;
}

Color citizenBorderColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.taupe.withValues(alpha: 0.16)
      : _blend(CitizenAppPalette.taupe, Colors.white, 0.38);
}

Color citizenDropdownColor(BuildContext context) {
  return citizenIsDark(context)
      ? _blend(CitizenAppPalette.navy, CitizenAppPalette.slate, 0.26)
      : Colors.white;
}

Color citizenPrimaryActionColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.sand
      : CitizenAppPalette.navy;
}

Color citizenOnPrimaryActionColor(BuildContext context) {
  return citizenIsDark(context) ? CitizenAppPalette.navy : Colors.white;
}

Color citizenSecondaryActionColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.taupe
      : CitizenAppPalette.slate;
}

Color citizenOnSecondaryActionColor(BuildContext context) {
  return citizenIsDark(context) ? CitizenAppPalette.navy : Colors.white;
}

Color citizenHighlightColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.sand
      : CitizenAppPalette.taupe;
}

Color citizenAccentColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.taupe
      : CitizenAppPalette.mauve;
}

Color citizenInfoSurfaceColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.taupe.withValues(alpha: 0.12)
      : CitizenAppPalette.sand.withValues(alpha: 0.40);
}

Color citizenInfoBorderColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.taupe.withValues(alpha: 0.26)
      : CitizenAppPalette.taupe.withValues(alpha: 0.58);
}

Color citizenInfoTextColor(BuildContext context) {
  return citizenIsDark(context)
      ? const Color(0xFFF8F2E8)
      : _blend(CitizenAppPalette.navy, Colors.black, 0.08);
}

Color citizenGlassSurfaceColor(BuildContext context) {
  return citizenIsDark(context)
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.88);
}

Color citizenGlassBorderColor(BuildContext context) {
  return citizenIsDark(context)
      ? Colors.white.withValues(alpha: 0.20)
      : CitizenAppPalette.taupe.withValues(alpha: 0.32);
}

Color citizenAuthOverlayColor(BuildContext context) {
  return citizenIsDark(context)
      ? CitizenAppPalette.navy.withValues(alpha: 0.78)
      : CitizenAppPalette.navy.withValues(alpha: 0.60);
}

List<BoxShadow> citizenCardShadow(BuildContext context) {
  if (citizenIsDark(context)) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.26),
        blurRadius: 24,
        offset: const Offset(0, 14),
      ),
    ];
  }

  return [
    BoxShadow(
      color: CitizenAppPalette.navy.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 14),
    ),
  ];
}

LinearGradient citizenPageGradient(BuildContext context) {
  return citizenIsDark(context)
      ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _blend(CitizenAppPalette.navy, Colors.black, 0.14),
            _blend(CitizenAppPalette.navy, CitizenAppPalette.slate, 0.22),
            _blend(CitizenAppPalette.navy, CitizenAppPalette.mauve, 0.12),
          ],
        )
      : LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFBF8F3),
            CitizenAppPalette.sand.withValues(alpha: 0.26),
            const Color(0xFFF5F0E8),
          ],
        );
}

LinearGradient citizenHeroGradient(BuildContext context) {
  return citizenIsDark(context)
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD1C6AD), Color(0xFFBBADA0), Color(0xFFA1869E)],
        )
      : const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1D51), Color(0xFF797596), Color(0xFFA1869E)],
        );
}

Color citizenReportStatusColor(BuildContext context, String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'resolved') {
    return citizenIsDark(context)
        ? CitizenAppPalette.sand
        : CitizenAppPalette.navy;
  }

  if (normalized == 'in progress') {
    return CitizenAppPalette.slate;
  }

  if (normalized == 'submitted' ||
      normalized == 'pending' ||
      normalized == 'new') {
    return CitizenAppPalette.mauve;
  }

  if (normalized == 'rejected') {
    return CitizenAppPalette.error;
  }

  return citizenHighlightColor(context);
}

Color citizenCategoryAccent(String category) {
  final normalized = category.toLowerCase();

  if (normalized.contains('road')) {
    return CitizenAppPalette.mauve;
  }

  if (normalized.contains('water')) {
    return CitizenAppPalette.slate;
  }

  if (normalized.contains('electric')) {
    return CitizenAppPalette.taupe;
  }

  return CitizenAppPalette.navy;
}

Color citizenPriorityFillColor(BuildContext context, String priority) {
  switch (priority) {
    case 'Low':
      return citizenIsDark(context)
          ? CitizenAppPalette.slate.withValues(alpha: 0.32)
          : CitizenAppPalette.slate.withValues(alpha: 0.16);
    case 'High':
      return citizenIsDark(context)
          ? CitizenAppPalette.taupe.withValues(alpha: 0.26)
          : CitizenAppPalette.taupe.withValues(alpha: 0.18);
    case 'Urgent':
      return citizenIsDark(context)
          ? CitizenAppPalette.error.withValues(alpha: 0.22)
          : CitizenAppPalette.error.withValues(alpha: 0.12);
    case 'Normal':
    default:
      return citizenIsDark(context)
          ? CitizenAppPalette.mauve.withValues(alpha: 0.26)
          : CitizenAppPalette.mauve.withValues(alpha: 0.14);
  }
}

Color citizenPriorityBorderColor(BuildContext context, String priority) {
  switch (priority) {
    case 'Low':
      return CitizenAppPalette.slate;
    case 'High':
      return CitizenAppPalette.taupe;
    case 'Urgent':
      return CitizenAppPalette.error;
    case 'Normal':
    default:
      return CitizenAppPalette.mauve;
  }
}

Color citizenPriorityTextColor(BuildContext context, String priority) {
  if (priority == 'Urgent') {
    return citizenIsDark(context)
        ? const Color(0xFFFFE5E5)
        : CitizenAppPalette.error;
  }

  return citizenIsDark(context)
      ? const Color(0xFFF8F2E8)
      : CitizenAppPalette.navy;
}

Color _blend(Color a, Color b, double t) {
  return Color.lerp(a, b, t) ?? a;
}
