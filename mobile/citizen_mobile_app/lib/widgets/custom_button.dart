import 'package:flutter/material.dart';

import '../utils/citizen_theme_colors.dart';

class CitizenPrimaryButton extends StatelessWidget {
  const CitizenPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = citizenOnPrimaryActionColor(context);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foregroundColor,
                ),
              )
            : icon == null
            ? Text(label)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}

class CitizenSecondaryButton extends StatelessWidget {
  const CitizenSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: citizenTitleColor(context),
          side: BorderSide(color: citizenBorderColor(context)),
        ),
        child: icon == null
            ? Text(label)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              ),
      ),
    );
  }
}
