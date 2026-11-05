import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/auth_styles.dart';

/// Six 46×56 digit boxes backed by one hidden text field, so the OS keyboard,
/// paste and SMS one-time-code autofill all work.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.code,
    required this.onChanged,
    this.length = 6,
    this.onCompleted,
  });

  final String code;
  final int length;
  final ValueChanged<String> onChanged;
  final VoidCallback? onCompleted;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.code,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant OtpCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.code,
        selection: TextSelection.collapsed(offset: widget.code.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged(value);
    if (value.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _focusNode.hasFocus ? widget.code.length : -1;

    return Semantics(
      label: 'Verification code',
      value: widget.code,
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _focusNode.requestFocus,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.length * 54 - 8),
          child: Stack(
            children: [
              // Hidden field that owns the keyboard and autofill.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onChanged,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < widget.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _DigitBox(
                          digit: i < widget.code.length ? widget.code[i] : '',
                          active: i == activeIndex,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.digit, required this.active});

  final String digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.limeTint : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: filled || active ? AppColors.ink : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Text(digit, style: AuthTextStyles.headingH2),
    );
  }
}
