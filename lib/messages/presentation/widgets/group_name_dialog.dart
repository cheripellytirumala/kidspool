import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../core/constants/messages_api_constants.dart';

/// Asks for a ride group's name (1–60 characters). Returns the trimmed name,
/// or null when dismissed. Used to start a group and to rename one.
Future<String?> showGroupNameDialog(
  BuildContext context, {
  required String title,
  required String confirm,
  String initial = '',
  String? message,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _GroupNameDialog(
      title: title,
      confirm: confirm,
      initial: initial,
      message: message,
    ),
  );
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    required this.title,
    required this.confirm,
    required this.initial,
    this.message,
  });

  final String title;
  final String confirm;
  final String initial;
  final String? message;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  bool get _valid =>
      _name.isNotEmpty &&
      _name.length <= MessagesApiConstants.maxGroupNameLength;

  void _submit() {
    if (_valid) Navigator.pop(context, _name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.screen,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTextStyles.headingH3),
            if (widget.message != null) ...[
              const SizedBox(height: 8),
              Text(widget.message!, style: AppTextStyles.body),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    MessagesApiConstants.maxGroupNameLength,
                  ),
                ],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                style: AppTextStyles.bodyL,
                cursorColor: AppColors.ink,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  hintText: 'Group name',
                  hintStyle: AppTextStyles.bodyL.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_name.length}/${MessagesApiConstants.maxGroupNameLength}',
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: 14),
            AppButton(
              label: widget.confirm,
              variant: AppButtonVariant.dark,
              onPressed: _valid ? _submit : null,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.light,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
