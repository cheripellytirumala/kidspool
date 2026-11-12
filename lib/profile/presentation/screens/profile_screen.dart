import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/screens/about_you_screen.dart'
    show AboutYouArgs;
import '../../../add_kids/presentation/screens/add_child_screen.dart'
    show AddChildArgs;
import '../../../common/core/constants/app_constants.dart';
import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/domain/entities/my_status.dart';
import '../../../common/presentation/screens/map_address_picker_screen.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_bottom_nav.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../messages/domain/entities/ride_group.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/constants/profile_styles.dart';
import '../../domain/entities/profile_overview.dart';
import '../../domain/entities/ride_mode.dart';
import '../../domain/entities/saved_address.dart';
import '../providers/profile_provider.dart';
import '../widgets/kid_profile_card.dart';
import '../widgets/profile_add_row.dart';
import '../widgets/profile_error_view.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_row.dart';
import '../widgets/profile_section_label.dart';
import '../widgets/profile_sheets.dart';

/// S18 · Profile.
///
/// Figma 960:8073 ("S18 · Profile1") is the base layout: header, how you use
/// KidPool, kids, driving, addresses, safety & log out. Tapping a kid opens
/// it into the detailed card of Figma 961:7601 ("S18 · Profile") with its
/// places; tapping the header again collapses it.
///
/// Data: `get_my_status`, `profiles` (phone, legal name), `get_my_kids`
/// (+ signed photo URLs), `get_my_addresses`.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProfileProvider>(
      create: (_) => sl<ProfileProvider>()..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final overview = provider.overview;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: AppLoadingOverlay(
          isLoading: provider.isLoading || provider.isSaving,
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  onRefresh: provider.load,
                  color: AppColors.ink,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      AppBottomNav.height + bottomInset + 28,
                    ),
                    children: [
                      if (overview != null)
                        ..._withGaps(_sections(context, provider, overview))
                      else if (provider.showError)
                        ProfileErrorView(
                          message: provider.errorMessage ?? '',
                          onRetry: provider.load,
                        ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(current: AppTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> children) => [
    for (final (i, child) in children.indexed) ...[
      if (i > 0) const SizedBox(height: 12),
      child,
    ],
  ];

  List<Widget> _sections(
    BuildContext context,
    ProfileProvider provider,
    ProfileOverview overview,
  ) {
    final actions = _ProfileActions(context, provider);
    return [
      ProfileHeader(
        name: overview.fullName,
        initials: overview.initials,
        contactLine: overview.contactLine,
        licenseVerified: overview.isLicenseVerified,
        rideModeLabel: overview.rideMode.title,
        onEdit: actions.editDetails,
      ),

      // How you use KidPool
      const ProfileSectionLabel('How you use KidPool'),
      ProfileRow(
        background: AppColors.limeTint,
        icon: const AppIcon(ProfileAssets.swap22, size: 22),
        title: overview.rideMode.title,
        subtitle: overview.rideMode == RideMode.both
            ? 'Tap to change: get rides only'
            : 'Tap to change: get & give rides',
        onTap: () => actions.changeRideMode(overview.rideMode),
      ),

      // Kids
      const ProfileSectionLabel('Your kids'),
      for (final kid in overview.kids)
        KidProfileCard(
          kid: kid,
          expanded: provider.isExpanded(kid.id),
          onToggle: () => provider.toggleKid(kid.id),
          onEdit: () => actions.editKid(kid.id),
          onAddPlace: actions.addPlace,
        ),
      if (overview.kidsError != null)
        ProfileSectionError(
          message: overview.kidsError!,
          onRetry: provider.load,
        ),
      ProfileAddRow(
        label: overview.kids.isEmpty ? 'Add your child' : 'Add a child',
        onTap: actions.addKid,
      ),

      // Driving
      const ProfileSectionLabel('Driving'),
      _LicenseRow(status: overview.status, onScan: actions.scanLicense),

      // Addresses
      const ProfileSectionLabel('Addresses'),
      for (final address in overview.addresses)
        ProfileRow(
          icon: const AppIcon(ProfileAssets.home, size: 22),
          title: address.title,
          subtitle: address.isDefault
              ? (address.city.isEmpty
                    ? 'Home point · used for every distance'
                    : 'Other parents only see “${address.city}”')
              : address.region,
          trailing: address.isDefault
              ? const ProfilePill(label: 'Default')
              : null,
          onTap: () => actions.addressActions(address),
        ),
      if (overview.addressesError != null)
        ProfileSectionError(
          message: overview.addressesError!,
          onRetry: provider.load,
        ),
      ProfileAddRow(
        label: 'Add address',
        onTap: () => actions.addAddress(overview.addresses.isEmpty),
      ),

      // Ride groups
      if (overview.rideGroups.isNotEmpty) ...[
        const ProfileSectionLabel('Ride groups'),
        for (final group in overview.rideGroups.take(3))
          ProfileRow(
            icon: const _MaterialIcon(Icons.groups_outlined),
            title: group.name,
            subtitle: group.hasUnread
                ? '${group.membersLabel} · ${group.unread} new'
                : group.membersLabel,
            onTap: () => actions.openGroup(group),
          ),
        if (overview.rideGroups.length > 3)
          ProfileRow(
            icon: const AppIcon(AppAssets.iconChat, size: 22),
            title: 'See all ride groups',
            subtitle: '${overview.rideGroups.length} ride groups',
            onTap: actions.openRideGroups,
          ),
      ],

      // Safety & help
      const ProfileSectionLabel('Safety & help'),
      ProfileRow(
        icon: const AppIcon(ProfileAssets.lock, size: 22),
        title: 'Privacy',
        subtitle: 'We never show your phone or address',
        onTap: () => actions.openWeb('Privacy', AppConstants.privacyUrl),
      ),
      ProfileRow(
        icon: const _MaterialIcon(Icons.help_outline_rounded),
        title: 'Help & support',
        subtitle: 'Questions, safety, report a problem',
        onTap: () => actions.openWeb('Help & support', AppConstants.supportUrl),
      ),
      ProfileRow(
        icon: const AppIcon(ProfileAssets.logout, size: 22),
        iconBackground: ProfileStyles.sosTint,
        title: 'Log out',
        titleColor: ProfileStyles.sos,
        showChevron: false,
        onTap: actions.signOut,
      ),
    ];
  }
}

/// Navigation and confirmations triggered from the profile.
class _ProfileActions {
  const _ProfileActions(this.context, this.provider);

  final BuildContext context;
  final ProfileProvider provider;

  Future<void> _push(String route, {Object? arguments}) async {
    await Navigator.pushNamed(context, route, arguments: arguments);
    await provider.load();
  }

  void _report(String? error) {
    if (error != null && context.mounted) showAppSnack(context, error);
  }

  void editDetails() => _push(
    AppRoutes.aboutYou,
    arguments: const AboutYouArgs(fromProfile: true),
  );

  void scanLicense() => _push(AppRoutes.scanPhotoId);

  void editKid(String id) =>
      _push(AppRoutes.addChild, arguments: AddChildArgs(childId: id));

  void addKid() =>
      _push(AppRoutes.addChild, arguments: const AddChildArgs(askSchool: true));

  void addPlace() => _push(AppRoutes.whereKidsGo);

  Future<void> changeRideMode(RideMode current) async {
    final mode = await showRideModeSheet(context, current);
    if (mode == null) return;
    _report(await provider.setRideMode(mode));
  }

  Future<void> addAddress(bool isFirst) async {
    final picked = await MapAddressPickerScreen.open(
      context,
      title: 'Add an address',
      confirmLabel: 'Save this address',
    );
    if (picked == null || !context.mounted) return;
    final label = await showAddressLabelDialog(
      context,
      initial: isFirst ? 'Home' : '',
    );
    if (label == null) return;
    _report(await provider.addAddress(picked, label));
  }

  Future<void> addressActions(SavedAddress address) async {
    final action = await showAddressActionsSheet(context, address);
    if (action == null || !context.mounted) return;
    switch (action) {
      case AddressAction.makeDefault:
        _report(await provider.makeDefault(address));
      case AddressAction.delete:
        final ok = await showProfileConfirm(
          context,
          title: 'Delete this address?',
          message: address.isDefault
              ? 'Your newest other address becomes the default.'
              : 'You can add it again any time.',
          confirmLabel: 'Delete',
        );
        if (ok) _report(await provider.deleteAddress(address));
    }
  }

  void openGroup(RideGroup group) => _push(
    AppRoutes.groupChat,
    arguments: GroupChatArgs(groupId: group.id, name: group.name),
  );

  void openRideGroups() => _push(AppRoutes.rideGroups);

  void openWeb(String title, String url) => Navigator.pushNamed(
    context,
    AppRoutes.webPage,
    arguments: WebPageArgs(title: title, url: url),
  );

  Future<void> signOut() async {
    final ok = await showProfileConfirm(
      context,
      title: 'Log out?',
      message: 'You’ll need your phone number to sign in again.',
      confirmLabel: 'Log out',
    );
    if (!ok) return;
    final error = await provider.signOut();
    if (!context.mounted) return;
    if (error != null) return _report(error);
    resetSessionState();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.phoneNumber, (_) => false);
  }
}

/// Figma "Row · License": ID review state from `get_my_status`.
class _LicenseRow extends StatelessWidget {
  const _LicenseRow({required this.status, required this.onScan});

  final MyStatus status;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final (subtitle, pill, canScan) = switch (status.onboardingStatus) {
      OnboardingStatus.approved => ('Verified', 'Verified', false),
      OnboardingStatus.pendingReview => (
        'We’re checking your license',
        'In review',
        false,
      ),
      OnboardingStatus.rejected => (
        status.rejectionReason ?? 'Not accepted · scan it again',
        null,
        true,
      ),
      OnboardingStatus.notStarted => ('Scan it to offer rides', null, true),
    };
    return ProfileRow(
      icon: const AppIcon(ProfileAssets.license, size: 22),
      title: 'Driver’s license',
      subtitle: subtitle,
      trailing: pill == null
          ? null
          : ProfilePill(
              label: pill,
              background: status.isApproved
                  ? AppColors.lime
                  : AppColors.surfaceStrong,
            ),
      onTap: canScan ? onScan : null,
    );
  }
}

/// 22px Material icon in the row tile (for rows without a Figma SVG here).
class _MaterialIcon extends StatelessWidget {
  const _MaterialIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: 22, color: AppColors.ink);
}
