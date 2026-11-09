import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_pill_input.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';
import '../providers/families_near_you_provider.dart';
import 'circle_icon_button.dart';

/// F14 "Send Message" bottom sheet: pick the template or write your own,
/// then send to every selected parent.
class SendMessageSheet extends StatefulWidget {
  const SendMessageSheet({super.key, required this.onSend});

  final VoidCallback onSend;

  /// Shows the sheet over a 55% scrim, sharing [provider] with the screen.
  static Future<void> show(
    BuildContext context, {
    required FamiliesNearYouProvider provider,
    required VoidCallback onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.screen,
      barrierColor: const Color(0x8C0A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: SendMessageSheet(onSend: onSend),
      ),
    );
  }

  @override
  State<SendMessageSheet> createState() => _SendMessageSheetState();
}

class _SendMessageSheetState extends State<SendMessageSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<FamiliesNearYouProvider>().customMessage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamiliesNearYouProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Send Message',
                      style: HomeTextStyles.headingH2,
                    ),
                  ),
                  CircleIconButton(
                    asset: HomeAssets.iconClose,
                    tooltip: 'Close',
                    size: 36,
                    iconSize: 16,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'PICK A MESSAGE OR WRITE YOUR OWN',
                style: HomeTextStyles.captionM,
              ),
              const SizedBox(height: 10),
              _TemplateCard(
                text: provider.messageTemplate,
                selected: provider.useTemplate,
                onTap: () {
                  _controller.clear();
                  provider.chooseTemplate();
                  FocusScope.of(context).unfocus();
                },
              ),
              const SizedBox(height: 10),
              AppPillInput(
                controller: _controller,
                hint: 'Or write your own…',
                leading: const AppIcon(HomeAssets.iconChat),
                textInputAction: TextInputAction.done,
                onChanged: provider.setCustomMessage,
              ),
              const SizedBox(height: 10),
              const _PrivacyNote(),
              const SizedBox(height: 10),
              AppButton(
                label: 'Send',
                isLoading: provider.isSending,
                onPressed: provider.canSend ? widget.onSend : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.limeTint : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.surface,
            width: 2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Text(
                text,
                style: HomeTextStyles.captionM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const AppIcon(HomeAssets.iconShieldCheck, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All parents sees your first name, kids’ grades and shared '
              'places — not your address. They can accept or decline.',
              style: HomeTextStyles.captionM.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
