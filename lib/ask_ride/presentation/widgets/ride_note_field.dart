import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import 'ask_ride_common.dart';
import 'ask_ride_text_styles.dart';

/// "Field · Note": free text for the Ride Partner.
class RideNoteField extends StatefulWidget {
  const RideNoteField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<RideNoteField> createState() => _RideNoteFieldState();
}

class _RideNoteFieldState extends State<RideNoteField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(kFieldRowRadius),
          border: Border.all(
            color: _focusNode.hasFocus ? AppColors.ink : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            IconDisc(
              child: SvgPicture.asset(
                AskRideAssets.chat,
                width: 16,
                height: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Note for the Ride Partner',
                    style: AskRideTextStyles.fieldCaption,
                  ),
                  const SizedBox(height: 1),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: widget.onChanged,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    style: AskRideTextStyles.labelL,
                    cursorColor: AppColors.ink,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Anything they should know?',
                      hintStyle: AskRideTextStyles.labelL.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
