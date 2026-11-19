import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:provider/provider.dart';

import '../../../common/core/constants/app_constants.dart';
import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/domain/entities/picked_address.dart';
import '../../../common/presentation/screens/map_address_picker_screen.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_checkbox_row.dart';
import '../../../common/presentation/widgets/app_chip_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_labeled_field.dart';
import '../../../common/presentation/widgets/app_screen.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_section_label.dart';
import '../../../common/presentation/widgets/app_select_card.dart';
import '../../core/constants/auth_assets.dart';
import '../../domain/entities/ride_role.dart';
import '../../../profile/domain/entities/ride_mode.dart';
import '../providers/auth_flow_provider.dart';
import '../widgets/home_map_preview.dart';
import '../widgets/profile_photo_button.dart';
import '../widgets/verified_phone_tile.dart';

/// Route arguments for [AboutYouScreen].
class AboutYouArgs {
  const AboutYouArgs({this.fromProfile = false});

  /// Opened from Profile → "Edit my details": shows a back button and,
  /// once saved, returns to Profile instead of continuing sign-up.
  final bool fromProfile;
}

/// S04 · About you — Figma nodes 1018:7939 ("I can offer and request rides"
/// selected) and 1018:8075 ("I need rides" selected). Both frames are the
/// two states of the role picker on this one screen.
class AboutYouScreen extends StatelessWidget {
  const AboutYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final fromProfile = args is AboutYouArgs && args.fromProfile;
    return ChangeNotifierProvider<AuthFlowProvider>.value(
      value: sl<AuthFlowProvider>(),
      child: _AboutYouBody(fromProfile: fromProfile),
    );
  }
}

class _AboutYouBody extends StatefulWidget {
  const _AboutYouBody({required this.fromProfile});

  final bool fromProfile;

  @override
  State<_AboutYouBody> createState() => _AboutYouBodyState();
}

class _AboutYouBodyState extends State<_AboutYouBody> {
  /// Two name fields (56 each) and the 8 between them.
  static const double _nameFieldsHeight = 120;

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
  void initState() {
    super.initState();
    // Show the verified number (and saved name) even when About you is
    // opened later, e.g. after an app restart.
    _flow.restoreFromProfile().then((_) {
      if (!mounted) return;
      if (_firstName.text.isEmpty) _firstName.text = _flow.firstName;
      if (_lastName.text.isEmpty) _lastName.text = _flow.lastName;
    });
  }

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

  void _openWebPage(String title, String url) {
    FocusScope.of(context).unfocus();
    Navigator.pushNamed(
      context,
      AppRoutes.webPage,
      arguments: WebPageArgs(title: title, url: url),
    );
  }

  /// The profile photo doubles as the selfie checked against the ID.
  Future<void> _addPhoto() async {
    final fromCamera = await showPhotoSourceSheet(context);
    if (fromCamera == null || !mounted) return;
    final error = await _flow.pickSelfie(fromCamera: fromCamera);
    if (error != null && mounted) showAppSnack(context, error);
  }

  /// Full map: search or drag to the home, then fill the fields from it.
  Future<void> _pickOnMap() async {
    FocusScope.of(context).unfocus();
    final point = _flow.mapPoint;
    final picked = await MapAddressPickerScreen.open(
      context,
      title: 'Your home address',
      initial: point == null
          ? null
          : PickedAddress(
              latitude: point.latitude,
              longitude: point.longitude,
              street: _flow.street,
              city: _flow.city,
              stateCode: _flow.stateCode,
              zip: _flow.zip,
            ),
    );
    if (picked == null || !mounted) return;
    _flow.applyPickedAddress(picked);
    _street.text = _flow.street;
    _zip.text = _flow.zip;
    _city.text = _flow.city;
    _stateCode.text = _flow.stateCode;
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_flow.isProfileComplete) {
      // Mark each missing field; the summary shows above Continue (a snack
      // would cover the button).
      _flow.revealMissing();
      return;
    }
    final error = await _flow.submitProfile();
    if (!mounted) return;
    if (error != null) return showAppSnack(context, error);
    // Editing from Profile: saved, so go back there.
    if (widget.fromProfile) {
      showAppSnack(context, 'Your details are saved');
      Navigator.pop(context, true);
      return;
    }
    // Only parents who offer rides scan their driver's license; parents who
    // only need rides go straight to adding their kids.
    Navigator.pushNamed(
      context,
      _flow.role == RideRole.seeker
          ? AppRoutes.addChild
          : AppRoutes.scanPhotoId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AuthFlowProvider>();

    // Transparent Material so the overlay message gets app text styles.
    return Material(
      type: MaterialType.transparency,
      child: AppLoadingOverlay(
        isLoading: flow.isSaving || flow.isLocating || flow.isPreparingPhoto,
        message: flow.isSaving
            ? 'Saving…'
            : flow.isPreparingPhoto
            ? 'Preparing photo…'
            : 'Finding your location…',
        child: _buildForm(flow),
      ),
    );
  }

  Widget _buildForm(AuthFlowProvider flow) {
    final point = flow.mapPoint;
    return AppScreen(
      title: 'About you',
      showBack: widget.fromProfile,
      children: [
        // The photo is as tall as the two name fields beside it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: _nameFieldsHeight,
              child: ProfilePhotoButton(
                imagePath: flow.selfiePath,
                onTap: _addPhoto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  AppLabeledField(
                    label: 'First name',
                    controller: _firstName,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    onChanged: flow.setFirstName,
                    errorText: flow.errorFor(ProfileField.firstName),
                  ),
                  const SizedBox(height: 8),
                  AppLabeledField(
                    label: 'Last name',
                    controller: _lastName,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    onChanged: flow.setLastName,
                    errorText: flow.errorFor(ProfileField.lastName),
                  ),
                ],
              ),
            ),
          ],
        ),
        const AppSectionLabel('Home address'),
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
        HomeMapPreview(
          label: flow.addressLabel,
          point: point == null ? null : LatLng(point.latitude, point.longitude),
          onTap: flow.isLocating ? null : _pickOnMap,
        ),
        AppLabeledField(
          label: 'Street address',
          controller: _street,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: flow.setStreet,
          errorText: flow.errorFor(ProfileField.street),
          leading: SvgPicture.asset(
            AuthAssets.iconHomeGlyph,
            width: 19,
            height: 18.2,
          ),
        ),
        AppLabeledField(
          label: 'Apt / Unit (optional)',
          controller: _apt,
          textInputAction: TextInputAction.next,
          onChanged: flow.setApt,
        ),
        // US order: City, State, ZIP.
        AppLabeledField(
          label: 'City',
          controller: _city,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          onChanged: flow.setCity,
          errorText: flow.errorFor(ProfileField.city),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppLabeledField(
                label: 'State',
                controller: _stateCode,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                onChanged: flow.setStateCode,
                errorText: flow.errorFor(ProfileField.state),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppLabeledField(
                label: 'ZIP code',
                controller: _zip,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: flow.setZip,
                errorText: flow.errorFor(ProfileField.zip),
              ),
            ),
          ],
        ),
        Text(
          'We use your home to find families near you. You can add more '
          'addresses later in Profile.',
          style: AppTextStyles.caption,
        ),
        // Read-only: the number verified by OTP (or from the profile).
        if (flow.internationalPhone.isNotEmpty)
          VerifiedPhoneTile(phone: flow.internationalPhone),
        const AppSectionLabel('I want to'),
        AppSelectCard(
          title: RideMode.seeker.title,
          subtitle: RideMode.seeker.description,
          icon: const AppIcon(AppAssets.iconKid, size: 22),
          selected: flow.role == RideRole.seeker,
          onTap: () => flow.selectRole(RideRole.seeker),
        ),
        AppSelectCard(
          title: RideMode.both.title,
          subtitle: RideMode.both.description,
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
        if (flow.errorFor(ProfileField.role) case final error?)
          _FieldError(error),
        _Outlined(
          error: flow.errorFor(ProfileField.guardian) != null,
          child: AppCheckboxRow(
            value: flow.isGuardian,
            label: 'I’m a parent or legal guardian, 18 or older',
            onChanged: flow.setGuardian,
          ),
        ),
        if (flow.errorFor(ProfileField.guardian) case final error?)
          _FieldError(error),
        _Outlined(
          error: flow.errorFor(ProfileField.terms) != null,
          child: AppCheckboxRow(
            value: flow.agreedToTerms,
            label: 'I agree to the Terms and Privacy Policy',
            links: {
              'Terms': () => _openWebPage('Terms', AppConstants.termsUrl),
              'Privacy Policy': () =>
                  _openWebPage('Privacy Policy', AppConstants.privacyUrl),
            },
            onChanged: flow.setAgreedToTerms,
          ),
        ),
        if (flow.errorFor(ProfileField.terms) case final error?)
          _FieldError(error),
        const SizedBox(height: 10),
        if (flow.missingSummary case final summary?) _FieldError(summary),
        AppButton(
          label: widget.fromProfile ? 'Save' : 'Continue',
          isLoading: flow.isSaving,
          // Stays tappable: with fields missing it points them out.
          onPressed: _continue,
        ),
      ],
    );
  }
}

/// A required choice that's still missing (red, under it).
class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(color: AppColors.danger),
      ),
    );
  }
}

/// Red outline around a required checkbox row that is still unticked.
class _Outlined extends StatelessWidget {
  const _Outlined({required this.error, required this.child});

  final bool error;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error ? AppColors.danger : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
