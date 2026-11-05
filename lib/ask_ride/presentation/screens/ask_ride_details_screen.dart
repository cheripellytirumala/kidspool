import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
      RouteCard(
        pickup: draft.pickup,
        dropOff: draft.dropOff,
        pickupSubtitle: [
          ?draft.pickup?.address,
          if (pickupTime != null) 'pick-up ${pickupTime.format()}',
        ].join(' · '),
        onPickupTap: () => _pickPlace(context, pickup: true),
        onDropOffTap: () => _pickPlace(context, pickup: false),
        // No "Swap": create_ride_request goes from an address to the kids'
        // school or a picked place; the way back is the return trip below.
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
        label: 'Return trip (back home)',
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
    final result = await showAskRideSheet<PlacePickerResult>(
      context,
      pickup
          ? PlacePickerSheet(
              title: title,
              places: [
                for (final place in provider.places)
                  if (place.kind == PlaceKind.home) place,
              ],
              selected: provider.draft.pickup,
            )
          // Drop-off: the kids' schools, or any place from Google search.
          : ChangeNotifierProvider<DropOffSearchProvider>(
              create: (_) =>
                  sl<DropOffSearchProvider>()..setNear(provider.searchNear),
              child: DropOffPickerSheet(
                schools: [
                  for (final place in provider.places)
                    if (place.kind == PlaceKind.school) place,
                ],
                selected: provider.draft.dropOff,
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
        provider.setDropOff(place);
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
    provider.setCustom(
      start: result.start,
      end: result.end,
      weekdays: result.weekdays,
      time: result.time,
    );
  }

  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final provider = context.read<AskRideProvider>();
    final error = await provider.submit();
    if (!context.mounted) return;
    if (error != null) return showAppSnack(context, error);
    Navigator.pushNamed(
      context,
      AppRoutes.familiesNearYou,
      arguments: FamiliesNearYouScreen.selectArgument,
    );
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
