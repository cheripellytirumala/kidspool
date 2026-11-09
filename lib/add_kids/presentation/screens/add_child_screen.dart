import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/child.dart';
import '../providers/add_child_form_provider.dart';
import '../providers/kids_provider.dart';
import '../widgets/dashed_add_button.dart';
import '../widgets/kid_avatar.dart';
import '../widgets/kid_field_tile.dart';
import '../widgets/kid_summary_card.dart';
import '../widgets/kids_scaffold.dart';
import '../widgets/kids_sheet.dart';
import '../../../common/presentation/widgets/app_loader.dart';

/// Route arguments for [AddChildScreen] when opened from F07: edit
/// [childId], or add a new child when it is null. Saving then returns to
/// the previous screen instead of pushing F07.
class AddChildArgs {
  const AddChildArgs({this.childId});

  final String? childId;
}

/// F06 · Add a child.
///
/// Figma Easy flow 837:13631 — new child form ("Save"); 849:14674 — editing
/// an existing child ("Update", camera badge) with the other kids collapsed.
/// Kids are loaded with `get_my_kids` and saved with `add-kid` /
/// `update-kid`.
class AddChildScreen extends StatelessWidget {
  const AddChildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final args = arguments is AddChildArgs ? arguments : null;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<KidsProvider>.value(value: sl<KidsProvider>()),
        ChangeNotifierProvider<AddChildFormProvider>(
          create: (_) => sl<AddChildFormProvider>(),
        ),
      ],
      child: _AddChildView(args: args),
    );
  }
}

class _AddChildView extends StatefulWidget {
  const _AddChildView({required this.args});

  final AddChildArgs? args;

  @override
  State<_AddChildView> createState() => _AddChildViewState();
}

class _AddChildViewState extends State<_AddChildView> {
  bool _ready = false;

  bool get _returnOnSave => widget.args != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final kids = context.read<KidsProvider>();
    final form = context.read<AddChildFormProvider>();
    await kids.load();
    if (!mounted) return;
    form.start(childId: widget.args?.childId, newChild: _returnOnSave);
    setState(() => _ready = true);
  }

  void _goNext() {
    if (_returnOnSave) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushNamed(AppRoutes.yourKids);
    }
  }

  Future<void> _run(
    Future<String?> Function() action, {
    bool next = false,
  }) async {
    FocusScope.of(context).unfocus();
    final error = await action();
    if (!mounted) return;
    if (error != null) return showAppSnack(context, error);
    if (next) _goNext();
  }

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();
    final form = context.watch<AddChildFormProvider>();

    if (!_ready) {
      return KidsScaffold(
        title: 'Add a child',
        subtitle: 'Add each child who needs rides.',
        children: [
          if (kids.status.isFailure)
            Text(kids.errorMessage ?? '', style: KidsTextStyles.bodyM)
          else
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: AppLoader()),
            ),
        ],
      );
    }

    final cards = <Widget>[
      for (final child in kids.children)
        if (form.editingId == child.id)
          _ChildFormCard(form: form, onSave: () => _run(form.save, next: true))
        else
          KidSummaryCard(
            child: child,
            onEdit: () => _run(() => form.switchTo(child.id)),
          ),
      if (form.isOpen && form.editingId == null)
        _ChildFormCard(form: form, onSave: () => _run(form.save, next: true)),
    ];

    // Transparent Material so the overlay gets app text styles. Covers the
    // save and the reload of the kids that follows it.
    return Material(
      type: MaterialType.transparency,
      child: AppLoadingOverlay(
        isLoading: form.isSaving || kids.isLoading,
        message: 'Saving…',
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: KidsScaffold(
            title: 'Add a child',
            subtitle: 'Add each child who needs rides.',
            gap: 12,
            bottom: AppButton(
              label: 'Continue',
              onPressed: form.canContinue ? _goNext : null,
            ),
            children: [
              ...cards,
              DashedAddButton(
                label: 'Add another child',
                onTap: () => _run(form.addAnother),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Kid · Emma" expanded card with the form fields.
class _ChildFormCard extends StatelessWidget {
  const _ChildFormCard({required this.form, required this.onSave});

  final AddChildFormProvider form;
  final VoidCallback onSave;

  Future<void> _pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Date of birth',
      initialDate: form.dateOfBirth ?? DateTime(now.year - 8, now.month, 1),
      // add-kid accepts kids under 19, not born in the future.
      firstDate: DateTime(now.year - 19, now.month, now.day + 1),
      lastDate: now,
      // Start on the year grid (no paging back month by month), then the
      // month; the pencil switches to typing the date.
      initialDatePickerMode: DatePickerMode.year,
      initialEntryMode: DatePickerEntryMode.calendar,
      fieldHintText: 'MM/DD/YYYY',
      fieldLabelText: 'Date of birth',
      errorFormatText: 'Enter a date like 05/14/2017',
      errorInvalidText: 'Kids must be under 19',
    );
    if (picked != null) form.setDateOfBirth(picked);
  }

  Future<void> _pickGrade(BuildContext context) async {
    final grade = await showKidsOptionPicker<String>(
      context,
      title: 'Grade',
      options: AddChildFormProvider.grades,
      selected: form.grade,
      labelOf: (grade) => grade,
    );
    if (grade != null) form.setGrade(grade);
  }

  /// "8 years" — the Figma "Age" value; the picker still asks for the date
  /// of birth (add-kid stores the date).
  static String _ageLabel(DateTime date) {
    final age = Child.ageOn(date);
    return '$age ${age == 1 ? 'year' : 'years'}';
  }

  @override
  Widget build(BuildContext context) {
    final name = form.firstName.text.trim();
    final dob = form.dateOfBirth;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _PhotoRow(
            preview: Child(
              id: form.editingId ?? 'new',
              firstName: name,
              lastName: form.lastName.text,
              photo: form.photo,
            ),
            showBadge: form.isEditing,
            onPick: (fromCamera) => form.pickPhoto(fromCamera: fromCamera),
          ),
          KidFieldTile(
            icon: KidsAssets.person,
            label: 'First Name',
            hint: 'Add first name',
            controller: form.firstName,
            textCapitalization: TextCapitalization.words,
          ),
          KidFieldTile(
            icon: KidsAssets.person,
            label: 'Last Name (optional)',
            hint: 'Add last name',
            controller: form.lastName,
            textCapitalization: TextCapitalization.words,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final dobTile = KidFieldTile(
                icon: KidsAssets.cake,
                label: 'Age',
                hint: 'Select',
                value: dob == null ? null : _ageLabel(dob),
                onTap: () => _pickDateOfBirth(context),
              );
              final gradeTile = KidFieldTile(
                icon: KidsAssets.grad20,
                label: 'Grade',
                hint: 'Select',
                value: form.grade,
                onTap: () => _pickGrade(context),
              );
              // Side by side as in Figma (each tile keeps ≥64px for the
              // value); stacked on 320pt phones.
              if (constraints.maxWidth < 318) {
                return Column(spacing: 10, children: [dobTile, gradeTile]);
              }
              return Row(
                spacing: 10,
                children: [
                  Expanded(child: dobTile),
                  Expanded(child: gradeTile),
                ],
              );
            },
          ),
          KidFieldTile(
            icon: KidsAssets.heart,
            label: 'Medical notes (optional)',
            hint: 'Allergies, medication…',
            controller: form.medicalNotes,
            textInputAction: TextInputAction.done,
          ),
          AppButton(
            label: form.isEditing ? 'Update' : 'Save',
            isLoading: form.isSaving,
            onPressed: form.canSave ? onSave : null,
          ),
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.preview,
    required this.showBadge,
    required this.onPick,
  });

  final Child preview;
  final bool showBadge;
  final Future<String?> Function(bool fromCamera) onPick;

  Future<void> _onTap(BuildContext context) async {
    final fromCamera = await showPhotoSourceSheet(context);
    if (fromCamera == null) return;
    final error = await onPick(fromCamera);
    if (error != null && context.mounted) showAppSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = preview.photo != null;
    final name = preview.firstName.isEmpty ? 'your child' : preview.firstName;

    return Semantics(
      button: true,
      label: 'Add a photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(context),
        child: Row(
          spacing: 14,
          children: [
            SizedBox.square(
              dimension: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (hasPhoto)
                    KidAvatar(child: preview, size: 72)
                  else
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.screen,
                        shape: BoxShape.circle,
                      ),
                      child: const AppIcon(AppAssets.iconCamera),
                    ),
                  if (showBadge && hasPhoto)
                    Positioned(
                      left: 50,
                      top: 46,
                      child: Container(
                        width: 21,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.screen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const AppIcon(KidsAssets.camera18, size: 18),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text('Add a photo', style: KidsTextStyles.labelL),
                  Text(
                    'Optional · helps the Ride Partner recognise $name',
                    style: KidsTextStyles.captionM,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
