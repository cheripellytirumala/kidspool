import 'package:flutter/material.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../data/safety_repository.dart';
import '../blocked_users.dart';

/// Profile › Blocked people: the list, with Unblock.
Future<void> showBlockedPeopleSheet(BuildContext context) {
  final blocked = sl<BlockedUsers>()..load();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Stays below the status bar when it grows (keyboard open).
    useSafeArea: true,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: ListenableBuilder(
        listenable: blocked,
        builder: (context, _) {
          final users = blocked.users;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                Text('Blocked people', style: AppTextStyles.headingH3),
                const SizedBox(height: 4),
                Text(
                  'You don’t see their messages or family card.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'You haven’t blocked anyone.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                  ),
                for (final u in users)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.ink,
                      child: Text(u.initials.isEmpty ? '?' : u.initials),
                    ),
                    title: Text(u.name, style: AppTextStyles.title),
                    trailing: TextButton(
                      onPressed: () async {
                        final error = await blocked.unblock(u.id);
                        if (context.mounted) {
                          showAppSnack(
                            context,
                            error ?? '${u.name} is unblocked.',
                          );
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Profile › Delete account: explains, asks to type DELETE, then deletes
/// on the server. Returns true once the account is gone (the caller signs
/// out and leaves); false when cancelled or it failed (already shown).
Future<bool> confirmAndDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (confirmed != true || !context.mounted) return false;

  // Blocking progress while the server deletes files and the account.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
    ),
  );
  final result = await sl<SafetyRepository>().deleteAccount();
  if (!context.mounted) return false;
  Navigator.of(context, rootNavigator: true).pop();
  return result.match((f) {
    showAppSnack(context, f.message);
    return false;
  }, (_) => true);
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _ready => _typed.text.trim().toUpperCase() == 'DELETE';

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
            Text('Delete your account?', style: AppTextStyles.headingH3),
            const SizedBox(height: 8),
            Text(
              'This permanently deletes your profile, your kids, addresses, '
              'ride requests, chats and ride groups you’re in, and your ID '
              'and license photos. It can’t be undone.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 8),
            Text(
              'Messages you sent in group chats stay, without your name.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text('Type DELETE to confirm', style: AppTextStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: _typed,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'DELETE',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Delete account',
              variant: AppButtonVariant.dark,
              onPressed: _ready ? () => Navigator.pop(context, true) : null,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.light,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
