import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// Square 22px checkbox (ink fill + lime check) with a label. Tapping
/// anywhere on the row toggles it, except on a [links] word.
class AppCheckboxRow extends StatefulWidget {
  const AppCheckboxRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.underline = false,
    this.links = const {},
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  /// Underlines the whole label.
  final bool underline;

  /// Parts of [label] ("Terms") shown underlined that run their action
  /// instead of toggling the box.
  final Map<String, VoidCallback> links;

  @override
  State<AppCheckboxRow> createState() => _AppCheckboxRowState();
}

class _AppCheckboxRowState extends State<AppCheckboxRow> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  static const _underlined = TextStyle(
    decoration: TextDecoration.underline,
    decorationColor: AppColors.textPrimary,
  );

  Widget _label() {
    final style = AppTextStyles.label;
    if (widget.links.isEmpty) {
      return Text(
        widget.label,
        style: widget.underline ? style.merge(_underlined) : style,
      );
    }
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    final text = widget.label;
    var i = 0;
    while (i < text.length) {
      // Earliest link starting at or after i.
      MapEntry<String, VoidCallback>? next;
      var at = -1;
      for (final e in widget.links.entries) {
        final j = text.indexOf(e.key, i);
        if (j >= 0 && (at < 0 || j < at)) {
          at = j;
          next = e;
        }
      }
      if (next == null) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (at > i) spans.add(TextSpan(text: text.substring(i, at)));
      final recognizer = TapGestureRecognizer()..onTap = next.value;
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: next.key,
          style: _underlined.copyWith(fontWeight: FontWeight.w600),
          recognizer: recognizer,
        ),
      );
      i = at + next.key.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      style: widget.underline ? style.merge(_underlined) : style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value ? AppColors.ink : AppColors.screen,
        borderRadius: BorderRadius.circular(7),
        border: value
            ? null
            : Border.all(color: AppColors.borderField, width: 2),
      ),
      child: value ? const AppIcon(AppAssets.iconCheckBox, size: 12) : null,
    );
    return MergeSemantics(
      child: Semantics(
        checked: value,
        child: InkWell(
          onTap: () => widget.onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                ExcludeSemantics(child: box),
                const SizedBox(width: 10),
                Expanded(child: _label()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
