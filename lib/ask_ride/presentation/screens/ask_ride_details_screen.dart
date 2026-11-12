import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../add_kids/presentation/screens/where_kids_go_screen.dart'
    show WhereKidsGoArgs;
import '../../../add_kids/presentation/providers/kids_provider.dart';
import '../../../home/presentation/screens/families_near_you_screen.dart';
import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/widgets/app_toggle.dart';
import '../../domain/entities/ride_schedule.dart';
import '../providers/ask_ride_provider.dart';
import '../providers/drop_off_search_provider.dart';
import '../widgets/ask_ride_common.dart';
import '../widgets/ask_ride_sheet.dart';
import '../widgets/drop_off_picker_sheet.dart';
import '../widgets/frequency_option_card.dart';
import '../widgets/kid_chip.dart';
import '../widgets/place_picker_sheet.dart';
import '../widgets/return_trip_details.dart';
import '../widgets/ride_note_field.dart';
import '../widgets/route_card.dart';
import '../widgets/schedule_sheets.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/screens/map_address_picker_screen.dart';
import '../../domain/entities/saved_place.dart';

/// G1 · Ask for a ride · details.
///
/// One form covering the five Figma states: kids, route, "Just once"
/// (Select day? sheet) or "Custom" (Which days? sheet), return trip, booster
/// seat and a note. The draft lives in the singleton [AskRideProvider].
/// Route arguments for Ask for a ride.
class AskRideArgs {
  const AskRideArgs({this.fromChat = false, this.groupId});

  /// Opened from a group chat: Next posts the ride there as a card (the
  /// request is created when a driver taps "I can help") and pops `true`.
  final String? groupId;

  /// Opened with "+ Ride" from a chat: once the ride is created the screen
  /// pops back to the chat with the ride as a message ([String]) instead of
  /// going on to Families near you.
  final bool fromChat;
}

class AskRideDetailsScreen extends StatelessWidget {
  const AskRideDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AskRideProvider>.value(
      value: sl<AskRideProvider>(),
      child: const _AskRideDetailsView(),
    );
  }
}

class _AskRideDetailsView extends StatefulWidget {
  const _AskRideDetailsView();

  @override
  State<_AskRideDetailsView> createState() => _AskRideDetailsViewState();
}

class _AskRideDetailsViewState extends State<_AskRideDetailsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AskRideProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AskRideProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        // The initial load shows a centered AppLoader in place of the form.
        body: AppLoadingOverlay(
          isLoading: provider.isSending || provider.isSavingAddress,
          message: provider.isSavingAddress ? 'Saving address…' : 'Sending…',
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AskRideBackButton(),
                    ),
                  ),
                  Expanded(
                    child: provider.status.isFailure
                        ? _ErrorState(message: provider.errorMessage)
                        : provider.status.isSuccess
                        ? const _Form()
                        : const Center(child: AppLoader()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form();

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AskRideProvider>();
    final draft = provider.draft;
    final schedule = draft.schedule;
    final pickupTime = draft.pickupTime;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Semantics(
          header: true,
          child: Text('Ask for a ride', style: AppTextStyles.displayL),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final kid in provider.kids)
            KidChip(
              kid: kid,
              selected: provider.isKidSelected(kid.id),
              onTap: () => provider.toggleKid(kid.id),
            ),
        ],
      ),
      // A kid added without a school (e.g. from Profile).
      for (final kid in provider.selectedKidsWithoutSchool)
        _NoSchoolCard(
          kidName: kid.name,
          school: provider.siblingSchool,
          busy: provider.isSettingSchool,
          onSameSchool: (school) async {
            final error = await provider.giveKidSchool(kid, school);
            if (error != null && context.mounted) {
              showAppSnack(context, error);
            }
          },
          onOtherSchool: () {
            // Open the school step on this kid; Save comes back here.
            sl<KidsProvider>().selectChild(kid.id);
            Navigator.pushNamed(
              context,
              AppRoutes.whereKidsGo,
              arguments: const WhereKidsGoArgs(returnOnSave: true),
            ).then((_) => provider.load());
          },
        ),
      RouteCard(
        pickup: draft.pickup,
        dropOff: draft.dropOff,
        pickupSubtitle: [
          ?draft.pickup?.address,
          if (pickupTime != null) 'pick-up ${pickupTime.format()}',
        ].join(' · '),
        onPickupTap: () => _pickPlace(context, pickup: true),
        onDropOffTap: () => _pickPlace(context, pickup: false),
        // Home → school, or school → home.
        onSwap: provider.swapRoute,
      ),
      FrequencyOptionCard(
        title: 'Just once',
        subtitle: provider.onceSummary,
        selected: schedule is OnceSchedule,
        onTap: () => _pickOnce(context),
      ),
      FrequencyOptionCard(
        title: 'Custom',
        subtitle: provider.customSummary,
        selected: schedule is CustomSchedule,
        onTap: () => _pickCustom(context),
      ),
      ToggleRow(
        label: 'Return trip',
        value: draft.returnTrip,
        onChanged: provider.setReturnTrip,
        toggle: AppToggle(
          value: draft.returnTrip,
          onChanged: provider.setReturnTrip,
        ),
      ),
      if (draft.returnTrip)
        ReturnTripDetails(
          from: draft.dropOff,
          to: draft.pickup,
          time: draft.returnTime,
          onTimeChanged: provider.setReturnTime,
        ),
      ToggleRow(
        label: 'One booster seat needed',
        value: draft.boosterSeat,
        onChanged: provider.setBoosterSeat,
        toggle: AppToggle(
          value: draft.boosterSeat,
          onChanged: provider.setBoosterSeat,
        ),
      ),
      RideNoteField(initialValue: draft.note, onChanged: provider.setNote),
      AppButton(
        label: 'Next: choose who to ask',
        isLoading: provider.isSending,
        onPressed: () => _submit(context),
      ),
    ];

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: _gap),
      itemBuilder: (_, i) => children[i],
    );
  }

  Future<void> _pickPlace(BuildContext context, {required bool pickup}) async {
    final provider = context.read<AskRideProvider>();
    final title = pickup ? 'Pick up from' : 'Drop off at';
    // The home end lists saved addresses; the other end lists the kids'
    // schools or any place from Google search (swapped on a ride home).
    final homeEnd = pickup != provider.isRideHome;
    final selected = pickup ? provider.draft.pickup : provider.draft.dropOff;
    final result = await showAskRideSheet<PlacePickerResult>(
      context,
      homeEnd
          ? PlacePickerSheet(
              title: title,
              places: [
                for (final place in provider.places)
                  if (place.kind == PlaceKind.home) place,
              ],
              selected: selected,
            )
          : ChangeNotifierProvider<DropOffSearchProvider>(
              create: (_) =>
                  sl<DropOffSearchProvider>()..setNear(provider.searchNear),
              child: DropOffPickerSheet(
                schools: [
                  for (final place in provider.places)
                    if (place.kind == PlaceKind.school) place,
                ],
                selected: selected,
                title: title,
                activities: provider.activityPlaces,
                emptyMessage:
                    'Add your child’s school first: Profile → your kid → '
                    'Add school or activity.',
              ),
            ),
    );
    if (!context.mounted) return;
    switch (result) {
      case null:
        return;
      case PlacePicked(:final place):
        pickup ? provider.setPickup(place) : provider.setDropOff(place);
      case CustomPlacePicked(:final place):
        pickup ? provider.setPickup(place) : provider.setDropOff(place);
      case AddNewPlace():
        final picked = await MapAddressPickerScreen.open(
          context,
          title: title,
          confirmLabel: pickup ? 'Pick up here' : 'Drop off here',
        );
        if (picked == null) return;
        final error = await provider.addPickedAddress(picked, pickup: pickup);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
        }
    }
  }

  Future<void> _pickOnce(BuildContext context) async {
    final provider = context.read<AskRideProvider>();
    final current = provider.draft.schedule;
    final result = await showAskRideSheet<OnceSelection>(
      context,
      SelectDaySheet(
        initial: current is OnceSchedule ? current : null,
        initialTime: provider.draft.pickupTime,
      ),
    );
    if (result == null) return;
    provider.setOnce(date: result.date, time: result.time);
  }

  Future<void> _pickCustom(BuildContext context) async {
    final provider = context.read<AskRideProvider>();
    final current = provider.draft.schedule;
    final result = await showAskRideSheet<CustomSelection>(
      context,
      WhichDaysSheet(
        initial: current is CustomSchedule ? current : null,
        initialTime: provider.draft.pickupTime,
      ),
    );
    if (result == null) return;
    provider.setCustom(dates: result.dates, time: result.time);
  }

  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final provider = context.read<AskRideProvider>();
    final args = ModalRoute.settingsOf(context)?.arguments;
    final fromChat = args is AskRideArgs && args.fromChat;
    final groupId = args is AskRideArgs ? args.groupId : null;
    if (groupId != null) {
      final error = await provider.askInGroup(groupId);
      if (!context.mounted) return;
      if (error != null) return showAppSnack(context, error);
      provider.reset();
      Navigator.of(context).pop(true);
      return;
    }
    if (!fromChat) {
      // Check the form, then choose who to ask: existing chats or
      // families (Say Hi / Start a group). Nothing is created here.
      final problem = provider.checkDraft();
      if (problem != null) return showAppSnack(context, problem);
      Navigator.pushNamed(
        context,
        AppRoutes.familiesNearYou,
        arguments: FamiliesNearYouScreen.selectArgument,
      );
      return;
    }
    // "+ Ride" from a chat: create it now and post it there.
    final error = await provider.submit();
    if (!context.mounted) return;
    if (error != null) return showAppSnack(context, error);
    // Back to the chat, which posts the ride; start fresh next time.
    final message = provider.chatMessage;
    provider.reset();
    Navigator.of(context).pop(message);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

/// "Jessie has no school yet": one tap gives them a sibling's school, or
/// opens "Where your kids go" to pick another.
class _NoSchoolCard extends StatelessWidget {
  const _NoSchoolCard({
    required this.kidName,
    required this.school,
    required this.busy,
    required this.onSameSchool,
    required this.onOtherSchool,
  });

  final String kidName;
  final SavedPlace? school;
  final bool busy;
  final ValueChanged<SavedPlace> onSameSchool;
  final VoidCallback onOtherSchool;

  @override
  Widget build(BuildContext context) {
    final same = school;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.limeTint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            same == null
                ? '$kidName has no school yet. Add it to ask for a ride.'
                : 'Does $kidName go to ${same.name} too?',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 12),
          if (same != null) ...[
            AppButton(
              label: 'Yes, ${same.name}',
              isLoading: busy,
              onPressed: busy ? null : () => onSameSchool(same),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: busy ? null : onOtherSchool,
            child: Text(
              same == null ? 'Add $kidName’s school' : 'No, another school',
              style: AppTextStyles.label,
            ),
          ),
        ],
      ),
    );
  }
}
