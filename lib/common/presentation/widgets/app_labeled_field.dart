import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Rounded field with a small caption label above the value
/// (Figma "Input · Name", "Input · Phone"). Shows a 2px ink border while
/// focused, as in the S03 phone field.
class AppLabeledField extends StatefulWidget {
  const AppLabeledField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.leading,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.autofocus = false,
    this.large = false,
    this.readOnly = false,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final Widget? leading;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool readOnly;

  /// Uses Heading/H3 (20px) for the value, as on the phone-number screen.
  final bool large;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AppLabeledField> createState() => _AppLabeledFieldState();
}

class _AppLabeledFieldState extends State<AppLabeledField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valueStyle = widget.large
        ? AppTextStyles.headingH3
        : AppTextStyles.title;
    final focused = _focusNode.hasFocus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: focused ? 12 : 14,
          vertical: focused ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusField),
          border: focused ? Border.all(color: AppColors.ink, width: 2) : null,
        ),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.label, style: AppTextStyles.caption),
                  TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    readOnly: widget.readOnly,
                    onChanged: widget.onChanged,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    inputFormatters: widget.inputFormatters,
                    style: valueStyle,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: valueStyle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 12),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
