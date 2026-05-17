import 'package:flutter/material.dart';

import '../utils/citizen_theme_colors.dart';

const String citizenOfficialLogoAsset = 'assets/images/logo.png';

class CitizenLogoBadge extends StatelessWidget {
  const CitizenLogoBadge({
    super.key,
    this.size = 104,
    this.outerPaddingFactor = 0.04,
    this.innerPaddingFactor = 0.07,
  });

  final double size;
  final double outerPaddingFactor;
  final double innerPaddingFactor;

  @override
  Widget build(BuildContext context) {
    final ringColor = CitizenAppPalette.sand.withValues(alpha: 0.96);
    final haloColor = citizenIsDark(context)
        ? CitizenAppPalette.taupe.withValues(alpha: 0.34)
        : CitizenAppPalette.navy.withValues(alpha: 0.16);
    final innerBorder = CitizenAppPalette.taupe.withValues(alpha: 0.70);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  haloColor,
                  haloColor.withValues(alpha: 0.14),
                  haloColor.withValues(alpha: 0),
                ],
                stops: const [0.16, 0.54, 1],
              ),
            ),
          ),
          Container(
            width: size * (1 - outerPaddingFactor),
            height: size * (1 - outerPaddingFactor),
            padding: EdgeInsets.all(size * innerPaddingFactor),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(
                    alpha: citizenIsDark(context) ? 0.22 : 0.94,
                  ),
                  Colors.white.withValues(
                    alpha: citizenIsDark(context) ? 0.14 : 0.82,
                  ),
                ],
              ),
              border: Border.all(color: ringColor, width: 2.4),
              boxShadow: [
                BoxShadow(
                  color: CitizenAppPalette.navy.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: innerBorder, width: 1.2),
                image: const DecorationImage(
                  image: AssetImage(citizenOfficialLogoAsset),
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CitizenBrandHeader extends StatelessWidget {
  const CitizenBrandHeader({
    super.key,
    this.title = 'Citizen Feedback',
    this.subtitle = 'Tacloban City reports, complaints, and service updates',
    this.caption,
    this.logoSize = 104,
    this.centered = true,
  });

  final String title;
  final String subtitle;
  final String? caption;
  final double logoSize;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final alignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final textAlign = centered ? TextAlign.center : TextAlign.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        CitizenLogoBadge(size: logoSize),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: textAlign,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: textAlign,
          style: TextStyle(
            color: CitizenAppPalette.sand.withValues(alpha: 0.92),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: CitizenAppPalette.taupe.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: CitizenAppPalette.taupe.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              caption!,
              textAlign: textAlign,
              style: TextStyle(
                color: CitizenAppPalette.sand.withValues(alpha: 0.96),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class CitizenSectionDivider extends StatelessWidget {
  const CitizenSectionDivider({
    super.key,
    required this.label,
    this.color = Colors.white,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.28))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.28))),
      ],
    );
  }
}
