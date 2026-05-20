import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/citizen_theme_colors.dart';

class CitizenTextField extends StatelessWidget {
  const CitizenTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.inputFormatters,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.prefixText,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController controller;
  final String hintText;
  final String? label;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? prefixText;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      readOnly: readOnly,
      onTap: onTap,
      style: TextStyle(color: citizenTitleColor(context)),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: citizenTitleColor(context),
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: suffixIcon,
        errorText: errorText,
      ),
    );

    if (label == null) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label!,
          style: TextStyle(
            color: citizenBodyColor(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
