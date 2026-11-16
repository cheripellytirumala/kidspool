import 'package:flutter/material.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../data/safety_repository.dart';
import '../../domain/safety_entities.dart';
import '../blocked_users.dart';

/// The person being reported or blocked, and where from.
class SafetyTarget {
  const SafetyTarget({
    required this.userId,
    required this.name,
    this.initials = '',
    this.context,
    this.contextId,
    this.messageId,
    this.messageText,
  });

  final String userId;
  final String name;
  final String initials;
  final ReportContext? context;

  /// Group id, ride request id …
  final String? contextId;

  /// The message long-pressed, if any.
  final String? messageId;
  final String? messageText;

  BlockedUser get asBlocked =>
      BlockedUser(id: userId, name: name, initials: initials);
}

/// Long-press menu: "Report Jen" and "Block Jen" (or "Unblock Jen").
Future<void> showSafetyActions(
  BuildContext context,
  SafetyTarget target,
) async {
  final blocked = sl<BlockedUsers>().isBlocked(target.userId);
  final picked = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (target.messageText case final text? when text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  '“$text”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.ink),
              title: Text(
                target.messageId == null
                    ? 'Report ${target.name}'
                    : 'Report this message',
                style: AppTextStyles.title,
              ),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              leading: Icon(
                blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                color: AppColors.danger,
              ),
              title: Text(
                blocked ? 'Unblock ${target.name}' : 'Block ${target.name}',
                style: AppTextStyles.title.copyWith(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(context, 1),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  if (picked == 0) return reportUser(context, target);
  if (blocked) return unblockUser(context, target);
  await blockUser(context, target);
}

/// Asks to confirm, then blocks. Returns true when blocked.
Future<bool> blockUser(BuildContext context, SafetyTarget target) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.screen,
      title: Text('Block ${target.name}?', style: AppTextStyles.headingH3),
      content: Text(
        'You won’t see their messages or their family card any more. '
        'They aren’t told. You can unblock them from Profile.',
        style: AppTextStyles.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final error = await sl<BlockedUsers>().block(target.asBlocked);
  if (!context.mounted) return error == null;
  showAppSnack(context, error ?? '${target.name} is blocked.');
  return error == null;
}

Future<void> unblockUser(BuildContext context, SafetyTarget target) async {
  final error = await sl<BlockedUsers>().unblock(target.userId);
  if (!context.mounted) return;
  showAppSnack(context, error ?? '${target.name} is unblocked.');
}

/// The report form: reason, optional details, "Also block".
Future<void> reportUser(BuildContext context, SafetyTarget target) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Stays below the status bar when it grows (keyboard open).
    useSafeArea: true,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ReportSheet(target: target),
  );
  if (sent == true && context.mounted) {
    showAppSnack(
      context,
      'Thanks for telling us. Our safety team reviews reports within '
      '24 hours.',
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target});

  final SafetyTarget target;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _block = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final t = widget.target;
    final result = await sl<SafetyRepository>().report(
      userId: t.userId,
      reason: reason,
      details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      context: t.context,
      contextId: t.contextId,
      messageId: t.messageId,
      alsoBlock: _block,
    );
    if (!mounted) return;
    final error = result.match((f) => f.message, (_) => null);
    if (error != null) {
      setState(() {
        _sending = false;
        _error = error;
      });
      return;
    }
    if (_block) await sl<BlockedUsers>().markBlocked(t.asBlocked);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.target.name;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.target.messageId == null
                    ? 'Report $name'
                    : 'Report a message from $name',
                style: AppTextStyles.headingH3,
              ),
              const SizedBox(height: 4),
              Text(
                'Only the KidPool safety team sees this. $name isn’t told.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) {
                  if (!_sending) setState(() => _reason = v);
                },
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: r,
                        title: Text(r.label, style: AppTextStyles.body),
                        activeColor: AppColors.ink,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              if (_reason == ReportReason.childSafety)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'If a child is in danger right now, call your local '
                    'emergency number (911 / 112) first.',
                    style: AppTextStyles.body.copyWith(color: AppColors.danger),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_sending,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What happened? (optional)',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              CheckboxListTile(
                value: _block,
                onChanged: _sending
                    ? null
                    : (v) => setState(() => _block = v ?? false),
                title: Text('Also block $name', style: AppTextStyles.body),
                activeColor: AppColors.ink,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: AppTextStyles.body.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 12),
              AppButton(
                label: 'Send report',
                isLoading: _sending,
                onPressed: _reason == null || _sending ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
