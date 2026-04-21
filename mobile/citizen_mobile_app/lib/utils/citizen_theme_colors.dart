import 'package:flutter/material.dart';

bool citizenIsDark(BuildContext context) {
  return Theme.of(context).colorScheme.brightness == Brightness.dark;
}

Color citizenScaffoldColor(BuildContext context) {
  return citizenIsDark(context) ? const Color(0xFF101826) : const Color(0xFFF6F8FC);
}

Color citizenCardColor(BuildContext context) {
  return citizenIsDark(context) ? const Color(0xFF1A2233) : Colors.white;
}

Color citizenInputColor(BuildContext context) {
  return citizenIsDark(context) ? const Color(0xFF1D2536) : const Color(0xFFF8FAFC);
}

Color citizenTitleColor(BuildContext context) {
  return citizenIsDark(context) ? Colors.white : const Color(0xFF12213A);
}

Color citizenBodyColor(BuildContext context) {
  return citizenIsDark(context)
      ? Colors.white.withValues(alpha: 0.72)
      : const Color(0xFF64748B);
}

Color citizenMutedColor(BuildContext context) {
  return citizenIsDark(context)
      ? Colors.white.withValues(alpha: 0.52)
      : const Color(0xFF94A3B8);
}

Color citizenBorderColor(BuildContext context) {
  return citizenIsDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFD8E3F7);
}

Color citizenDropdownColor(BuildContext context) {
  return citizenIsDark(context) ? const Color(0xFF253248) : Colors.white;
}
