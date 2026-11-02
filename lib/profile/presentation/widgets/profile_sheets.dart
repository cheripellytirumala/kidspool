import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_select_card.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/constants/profile_styles.dart';
import '../../domain/entities/ride_mode.dart';
import '../../domain/entities/saved_address.dart';

Future<T?> _sheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          20,
          18,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: builder(context),
      ),
    ),
  );
}

/// "How you use KidPool" picker. Returns the chosen mode.
Future<RideMode?> showRideModeSheet(BuildContext context, RideMode current) {
  return _sheet<RideMode>(
    context,
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How you use KidPool', style: AppTextStyles.headingH3),
        const SizedBox(height: 16),
        AppSelectCard(
          title: RideMode.both.title,
          subtitle: RideMode.both.description,
          icon: const AppIcon(ProfileAssets.swap22, size: 22),
          selected: current == RideMode.both,
          onTap: () => Navigator.pop(context, RideMode.both),
        ),
        const SizedBox(height: 10),
        AppSelectCard(
          title: RideMode.seeker.title,
          subtitle: RideMode.seeker.description,
          icon: const AppIcon(AppAssets.iconKid, size: 22),
          selected: current == RideMode.seeker,
          onTap: () => Navigator.pop(context, RideMode.seeker),
        ),
      ],
    ),
  );
}

enum AddressAction { makeDefault, delete }

/// Actions for a saved address row.
Future<AddressAction?> showAddressActionsSheet(
  BuildContext context,
  SavedAddress address,
) {
  return _sheet<AddressAction>(
    context,
    (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(address.title, style: AppTextStyles.headingH3),
        if (address.region.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(address.region, style: AppTextStyles.body),
        ],
        const SizedBox(height: 20),
        if (!address.isDefault) ...[
          AppButton(
            label: 'Make default',
            variant: AppButtonVariant.dark,
            onPressed: () => Navigator.pop(context, AddressAction.makeDefault),
          ),
          const SizedBox(height: 10),
        ],
        AppButton(
          label: 'Delete address',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.pop(context, AddressAction.delete),
        ),
      ],
    ),
  );
}

/// Asks for a short name for a new address. Returns `null` when cancelled.
Future<String?> showAddressLabelDialog(
  BuildContext context, {
  required String initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _LabelDialog(initial: initial),
  );
}

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.initial});

  final String initial;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screen,
      title: Text('Name this address', style: AppTextStyles.headingH3),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: AppTextStyles.bodyL,
        decoration: const InputDecoration(hintText: 'e.g. Dad’s home'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: ProfileStyles.placeTitle),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Save', style: ProfileStyles.placeTitle),
        ),
      ],
    );
  }
}

/// Confirms a destructive action. Returns `true` when confirmed.
Future<bool> showProfileConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.screen,
      title: Text(title, style: AppTextStyles.headingH3),
      content: Text(message, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: ProfileStyles.placeTitle),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: ProfileStyles.placeTitle.copyWith(color: ProfileStyles.sos),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
