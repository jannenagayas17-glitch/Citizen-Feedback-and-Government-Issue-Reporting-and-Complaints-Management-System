import 'package:flutter/material.dart';

import '../utils/citizen_theme_colors.dart';

class CitizenLoadingIndicator extends StatelessWidget {
  const CitizenLoadingIndicator({
    super.key,
    this.label,
    this.size = 22,
    this.centered = true,
  });

  final String? label;
  final double size;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: citizenPrimaryActionColor(context),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 12),
          Text(
            label!,
            style: TextStyle(color: citizenBodyColor(context), fontSize: 13),
          ),
        ],
      ],
    );

    if (centered) {
      return Center(child: child);
    }

    return child;
  }
}
