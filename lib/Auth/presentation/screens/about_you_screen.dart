import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_checkbox_row.dart';
import '../../../common/presentation/widgets/app_chip_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_labeled_field.dart';
import '../../../common/presentation/widgets/app_pill_input.dart';
import '../../../common/presentation/widgets/app_screen.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_section_label.dart';
import '../../../common/presentation/widgets/app_select_card.dart';
import '../../core/constants/auth_assets.dart';
import '../../domain/entities/ride_role.dart';
import '../providers/auth_flow_provider.dart';
import '../widgets/home_map_preview.dart';
import '../widgets/profile_photo_button.dart';
import '../widgets/switch_tile.dart';
import '../widgets/verified_phone_tile.dart';

/// S04 · About you — Figma nodes 1018:7939 ("I can offer and request rides"
/// selected) and 1018:8075 ("I need rides" selected). Both frames are the
/// two states of the role picker on this one screen.
class AboutYouScreen extends StatelessWidget {
  const AboutYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthFlowProvider>.value(
      value: sl<AuthFlowProvider>(),
      child: const _AboutYouBody(),
    );
  }
}

class _AboutYouBody extends StatefulWidget {
  const _AboutYouBody();

  @override
  State<_AboutYouBody> createState() => _AboutYouBodyState();
}

class _AboutYouBodyState extends State<_AboutYouBody> {
  late final AuthFlowProvider _flow = context.read<AuthFlowProvider>();

  late final TextEditingController _firstName = TextEditingController(
    text: _flow.firstName,
  );
  late final TextEditingController _lastName = TextEditingController(
    text: _flow.lastName,
  );
  late final TextEditingController _street = TextEditingController(
    text: _flow.street,
  );
  late final TextEditingController _apt = TextEditingController(
    text: _flow.apt,
  );
  late final TextEditingController _zip = TextEditingController(
    text: _flow.zip,
  );
  late final TextEditingController _city = TextEditingController(
    text: _flow.city,
  );
  late final TextEditingController _stateCode = TextEditingController(
    text: _flow.stateCode,
  );

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _street,
      _apt,
      _zip,
      _city,
      _stateCode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    FocusScope.of(context).unfocus();
    final error = await _flow.useCurrentLocation();
    if (!mounted) return;
    if (error != null) return showAppSnack(context, error);
    _street.text = _flow.street;
    _zip.text = _flow.zip;
    _city.text = _flow.city;
    _stateCode.text = _flow.stateCode;
  }

  /// The profile photo doubles as the selfie checked against the ID.
  Future<void> _addPhoto() async {
    final fromCamera = await showPhotoSourceSheet(context);
    if (fromCamera == null || !mounted) return;
    final error = await _flow.pickSelfie(fromCamera: fromCamera);
    if (error != null && mounted) showAppSnack(context, error);
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    final error = await _flow.submitProfile();
    if (!mounted) return;
    if (error != null) return showAppSnack(context, error);
    Navigator.pushNamed(context, AppRoutes.scanPhotoId);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AuthFlowProvider>();

    // Transparent Material so the overlay message gets app text styles.
    return Material(
      type: MaterialType.transparency,
      child: AppLoadingOverlay(
        isLoading: flow.isSaving || flow.isLocating,
        message: flow.isSaving ? 'Saving…' : 'Finding your location…',
        child: _buildForm(flow),
      ),
    );
  }

  Widget _buildForm(AuthFlowProvider flow) {
    return AppScreen(
      title: 'About you',
      children: [
        Row(
          children: [
            ProfilePhotoButton(imagePath: flow.selfiePath, onTap: _addPhoto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  AppLabeledField(
                    label: 'First Name',
                    controller: _firstName,
                    textInputAction: TextInputAction.next,
                    onChanged: flow.setFirstName,
                  ),
                  const SizedBox(height: 4),
                  AppLabeledField(
                    label: 'Last Name',
                    controller: _lastName,
                    textInputAction: TextInputAction.next,
                    onChanged: flow.setLastName,
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppChipButton(
            label: flow.isLocating
                ? 'Finding your location…'
                : 'Use my current location',
            icon: const AppIcon(AppAssets.iconLocate, size: 16),
            onTap: flow.isLocating ? () {} : _useCurrentLocation,
          ),
        ),
        HomeMapPreview(label: flow.addressLabel),
        AppPillInput(
          controller: _street,
          hint: 'Street address',
          textInputAction: TextInputAction.next,
          onChanged: flow.setStreet,
          leading: SizedBox.square(
            dimension: 24,
            child: Center(
              child: SvgPicture.asset(
                AuthAssets.iconHomeGlyph,
                width: 19,
                height: 18.2,
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AppPillInput(
                controller: _apt,
                hint: 'Apt / Unit (optional)',
                textInputAction: TextInputAction.next,
                onChanged: flow.setApt,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: AppPillInput(
                controller: _zip,
                hint: 'ZIP',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: flow.setZip,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: AppPillInput(
                controller: _city,
                hint: 'City',
                textInputAction: TextInputAction.next,
                onChanged: flow.setCity,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 100,
              child: AppPillInput(
                controller: _stateCode,
                hint: 'State',
                textInputAction: TextInputAction.done,
                onChanged: flow.setStateCode,
              ),
            ),
          ],
        ),
        SwitchTile(
          title: 'Set as default address',
          subtitle: 'Matching will use this address',
          value: flow.isDefaultAddress,
          onChanged: flow.setDefaultAddress,
        ),
        VerifiedPhoneTile(phone: flow.internationalPhone),
        const AppSectionLabel('I want to'),
        AppSelectCard(
          title: 'I need rides',
          subtitle: 'Ask families at your kids’ schools and clubs',
          icon: const AppIcon(AppAssets.iconKid, size: 22),
          selected: flow.role == RideRole.seeker,
          onTap: () => flow.selectRole(RideRole.seeker),
        ),
        AppSelectCard(
          title: 'I can offer and request rides',
          subtitle: 'Ask for rides and help others',
          // Figma shows the car when selected (1018:7939) and the heart when
          // not (1018:8075).
          icon: flow.role == RideRole.both
              ? SvgPicture.asset(
                  AuthAssets.iconCar,
                  width: 17.42,
                  height: 13.43,
                )
              : const AppIcon(AppAssets.iconHeart, size: 22),
          selected: flow.role == RideRole.both,
          onTap: () => flow.selectRole(RideRole.both),
        ),
        AppCheckboxRow(
          value: flow.isGuardian,
          label: 'I’m a parent or legal guardian, 18 or older',
          onChanged: flow.setGuardian,
        ),
        AppCheckboxRow(
          value: flow.agreedToTerms,
          label: 'I agree to the Terms and Privacy Policy',
          onChanged: flow.setAgreedToTerms,
        ),
        const SizedBox(height: 10),
        if (flow.selfiePath == null)
          Text(
            'Add a photo of yourself — we compare it with your ID.',
            style: AppTextStyles.caption,
          ),
        AppButton(
          label: 'Continue',
          isLoading: flow.isSaving,
          onPressed: flow.isProfileComplete ? _continue : null,
        ),
      ],
    );
  }
}
