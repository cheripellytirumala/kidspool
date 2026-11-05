import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../../domain/entities/ride_time.dart';
import 'ask_ride_common.dart';
import 'ask_ride_text_styles.dart';

enum RideTimeFieldStyle {
  /// "Field · Time": surface row, clock in a white disc ("Pick up at").
  field,

  /// "Field · Return time": white row, bare clock, pencil on the right.
  inline,
}

/// Time the parent types in ("8:30 AM", "830", "3pm"…). Reports `null`
/// while the text is not a valid time.
class RideTimeField extends StatefulWidget {
  const RideTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.style = RideTimeFieldStyle.field,
  });

  final String label;
  final RideTime? value;
  final ValueChanged<RideTime?> onChanged;
  final RideTimeFieldStyle style;

  @override
  State<RideTimeField> createState() => _RideTimeFieldState();
}

class _RideTimeFieldState extends State<RideTimeField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.format() ?? '',
  );
  final FocusNode _focusNode = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(RideTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when the value changes from outside (not while typing).
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = widget.value?.format() ?? '';
      _invalid = false;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Normalise "830" → "8:30 AM" once the parent leaves the field.
    final time = RideTime.tryParse(_controller.text);
    if (!_focusNode.hasFocus && time != null) {
      _controller.text = time.format();
    }
    setState(() {});
  }

  void _onChanged(String text) {
    final time = RideTime.tryParse(text);
    setState(() => _invalid = text.trim().isNotEmpty && time == null);
    widget.onChanged(time);
  }

  @override
  Widget build(BuildContext context) {
    final inline = widget.style == RideTimeFieldStyle.inline;
    final focused = _focusNode.hasFocus;
    final caption = _invalid
        ? 'Type a time like ${inline ? '3:30 PM' : '8:30 AM'}'
        : widget.label;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: inline ? AppColors.screen : AppColors.surface,
          borderRadius: BorderRadius.circular(inline ? 18 : kFieldRowRadius),
          border: Border.all(
            color: focused ? AppColors.ink : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (inline)
              SvgPicture.asset(AskRideAssets.clockSmall, width: 18, height: 18)
            else
              IconDisc(
                child: SvgPicture.asset(
                  AskRideAssets.clock,
                  width: 16,
                  height: 16,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caption,
                    style: AskRideTextStyles.fieldCaption.copyWith(
                      color: _invalid ? AppColors.textPrimary : null,
                    ),
                  ),
                  if (!inline) const SizedBox(height: 1),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.done,
                    style: AskRideTextStyles.labelL,
                    cursorColor: AppColors.ink,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: inline ? '3:30 PM' : '8:30 AM',
                      hintStyle: AskRideTextStyles.labelL.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (inline) ...[
              const SizedBox(width: 10),
              SvgPicture.asset(AskRideAssets.pencil, width: 16, height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
