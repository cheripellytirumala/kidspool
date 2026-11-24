import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/error/exceptions.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/core/services/photo_picker.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_pill_input.dart';
import '../../../common/presentation/widgets/app_screen.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/widgets/app_toggle.dart';
import '../../../profile/data/repositories/my_car_repository.dart';
import '../../../profile/domain/entities/my_car.dart';

/// "Your vehicle": sign-up step after the driver's license (then Add a
/// child). The car other parents look for (photo, model, year, color,
/// plate), how many seats it has and how many are free for kids.
/// Route arguments: opened from Profile › My car, Submit returns there.
class VehicleDetailsArgs {
  const VehicleDetailsArgs({this.fromProfile = false});

  final bool fromProfile;
}

/// Plate characters: letters, digits, spaces and dashes, typed in capitals.
class PlateFormatter extends TextInputFormatter {
  const PlateFormatter();

  static const int maxLength = 12;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9 -]'),
      '',
    );
    if (text.length > maxLength) text = text.substring(0, maxLength);
    final offset =
        (newValue.selection.end - (newValue.text.length - text.length)).clamp(
          0,
          text.length,
        );
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  /// Earliest model year offered.
  static const int firstYear = 1980;

  /// "Enter a year like 2021" when [text] isn't a model year; null if fine
  /// or empty.
  static String? yearError(String text, [DateTime? now]) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final y = int.tryParse(t);
    final max = (now ?? DateTime.now()).year + 1;
    return (y == null || y < firstYear || y > max)
        ? 'Enter a year like 2021'
        : null;
  }

  /// Error for a plate, null when it's fine.
  static String? plateError(String text) {
    final t = text.trim();
    if (t.isEmpty) return 'Enter your license plate';
    if (!RegExp(r'^[A-Z0-9 -]{2,12}$').hasMatch(t) ||
        !RegExp(r'[A-Z0-9]').hasMatch(t)) {
      return 'Use letters and numbers, like TS09 AB 1234';
    }
    return null;
  }

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final MyCarRepository _repo = sl<MyCarRepository>();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();

  /// Shows [_color] in its (read-only) field.
  final _colorText = TextEditingController();

  String _color = '';
  int _carSeats = 5;
  int _kidSeats = 3;
  bool _booster = false;

  /// A photo picked on this screen (not uploaded yet).
  String? _photoPath;

  /// Link to the photo already saved on the server.
  String? _savedPhotoUrl;
  bool _hasSavedPhoto = false;
  bool _removeSavedPhoto = false;

  bool _saving = false;
  bool _showErrors = false;

  /// What was on screen after loading; leaving with anything else asks
  /// first.
  String _initial = '';

  @override
  void initState() {
    super.initState();
    _initial = _snapshot;
    // Coming back to this step: show what was saved.
    _repo.get().then((result) {
      final car = result.toNullable();
      if (!mounted || car == null) return;
      setState(() {
        if (MyCar.sizes.contains(car.carSeats)) _carSeats = car.carSeats;
        _kidSeats = car.kidSeats.clamp(1, _maxKidSeats);
        _booster = car.hasBooster;
        _model.text = car.model ?? '';
        _color = car.color ?? '';
        _colorText.text = _color;
        _year.text = car.year?.toString() ?? '';
        _plate.text = car.plateNumber ?? '';
        _hasSavedPhoto = car.hasPhoto;
        _initial = _snapshot;
      });
      if (car.hasPhoto) {
        _repo.photoUrl().then((url) {
          if (mounted) setState(() => _savedPhotoUrl = url);
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_model, _year, _plate, _colorText]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _snapshot => [
    _model.text.trim(),
    _year.text.trim(),
    _color,
    _plate.text.trim(),
    _carSeats,
    _kidSeats,
    _booster,
    _photoPath,
    _removeSavedPhoto,
  ].join('|');

  bool get _dirty => _snapshot != _initial;

  bool get _hasPhoto =>
      _photoPath != null || (_hasSavedPhoto && !_removeSavedPhoto);

  /// Every seat but the driver's can be a kid seat.
  int get _maxKidSeats => (_carSeats - 1).clamp(1, 7);

  String? get _yearError => VehicleDetailsScreen.yearError(_year.text);
  String? get _plateError => VehicleDetailsScreen.plateError(_plate.text);
  bool get _modelMissing => _model.text.trim().isEmpty;
  bool get _colorMissing => _color.trim().isEmpty;

  bool get _complete =>
      !_modelMissing &&
      !_colorMissing &&
      _yearError == null &&
      _plateError == null;

  void _setCarSeats(int seats) => setState(() {
    _carSeats = seats;
    _kidSeats = _kidSeats.clamp(1, _maxKidSeats);
  });

  Future<void> _pickPhoto() async {
    FocusScope.of(context).unfocus();
    final fromCamera = await showPhotoSourceSheet(
      context,
      title: 'Photo of your car',
    );
    if (fromCamera == null || !mounted) return;
    try {
      final path = await sl<PhotoPicker>().pick(fromCamera: fromCamera);
      if (path != null && mounted) setState(() => _photoPath = path);
    } on DeviceException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  void _removePhoto() => setState(() {
    _photoPath = null;
    if (_hasSavedPhoto) _removeSavedPhoto = true;
  });

  Future<void> _pickYear() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now().year;
    final years = [
      for (var y = now + 1; y >= VehicleDetailsScreen.firstYear; y--) y,
    ];
    final picked = await _showChoiceSheet<int>(
      title: 'Model year',
      children: (pop) => [
        for (final y in years)
          ListTile(
            title: Text('$y', style: AppTextStyles.bodyL),
            trailing: _year.text == '$y'
                ? const Icon(Icons.check_rounded, color: AppColors.ink)
                : null,
            onTap: () => pop(y),
          ),
      ],
    );
    if (picked != null && mounted) setState(() => _year.text = '$picked');
  }

  Future<void> _pickColor() async {
    FocusScope.of(context).unfocus();
    final picked = await _showChoiceSheet<String>(
      title: 'Car colour',
      children: (pop) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final (name, argb) in MyCar.colors)
                _ColorChoice(
                  name: name,
                  color: Color(argb),
                  selected: name == _color,
                  onTap: () => pop(name),
                ),
            ],
          ),
        ),
      ],
    );
    if (picked != null && mounted) {
      setState(() => _colorText.text = _color = picked);
    }
  }

  Future<T?> _showChoiceSheet<T>({
    required String title,
    required List<Widget> Function(void Function(T) pop) children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.screen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.6,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTextStyles.headingH3),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheet),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: children((v) => Navigator.pop(sheet, v)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Back with unsaved changes: ask before throwing them away.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Discard your vehicle details?'),
        content: const Text(
          'You haven’t submitted them yet. If you go back now, what you '
          'entered is lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _initial = _snapshot;
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_complete) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    final result = await _repo.saveVehicle(
      model: _model.text.trim(),
      plateNumber: _plate.text.trim(),
      carSeats: _carSeats,
      kidSeats: _kidSeats,
      hasBooster: _booster,
      color: _color.trim(),
      year: int.tryParse(_year.text.trim()),
      photoPath: _photoPath,
      removePhoto: _removeSavedPhoto,
    );
    if (!mounted) return;
    final error = result.getLeft().toNullable();
    if (error != null) {
      setState(() => _saving = false);
      return showAppSnack(context, error.message);
    }
    _initial = _snapshot;
    final args = ModalRoute.settingsOf(context)?.arguments;
    if (args is VehicleDetailsArgs && args.fromProfile) {
      showAppSnack(context, 'Your vehicle is saved');
      Navigator.pop(context, true);
      return;
    }
    // On to Add a child; a parent who already has kids (a rider who just
    // added a license from Profile) goes Home. No way back into the
    // license steps.
    final status = await sl<AccountRepository>().getMyStatus();
    if (!mounted) return;
    final hasKids = (status.toNullable()?.kidsCount ?? 0) > 0;
    Navigator.pushNamedAndRemoveUntil(
      context,
      hasKids ? AppRoutes.home : AppRoutes.addChild,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = [
      _color.trim(),
      _model.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final yearError = _yearError;
    final plateError = _plateError;
    final swatch = MyCar.colors
        .where((c) => c.$1 == _color)
        .map((c) => Color(c.$2))
        .firstOrNull;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Material(
        type: MaterialType.transparency,
        child: AppLoadingOverlay(
          isLoading: _saving,
          message: 'Saving…',
          child: AppScreen(
            title: 'Your vehicle',
            showBack: true,
            gap: 14,
            // With the keyboard up the button would cover the fields; it
            // comes back as soon as the keyboard closes.
            bottom: keyboardOpen
                ? null
                : AppButton(
                    label: 'Submit',
                    onPressed: _complete ? _submit : null,
                  ),
            children: [
              _PhotoCard(
                title: title.isEmpty ? 'Your car' : title,
                localPath: _photoPath,
                networkUrl: _removeSavedPhoto ? null : _savedPhotoUrl,
                hasPhoto: _hasPhoto,
                onTap: _pickPhoto,
                onRemove: _hasPhoto ? _removePhoto : null,
              ),
              AppPillInput(
                controller: _model,
                hint: 'Make and model',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                error: _showErrors && _modelMissing,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                onChanged: (_) => setState(() {}),
                leading: const Icon(
                  Icons.directions_car_filled,
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
              if (_showErrors && _modelMissing)
                const _FieldError('Enter your car’s make and model'),
              Row(
                children: [
                  Expanded(
                    child: AppPillInput(
                      controller: _year,
                      hint: 'Year',
                      readOnly: true,
                      onTap: _pickYear,
                      error: _showErrors && yearError != null,
                      leading: const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: AppColors.ink,
                      ),
                      trailing: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPillInput(
                      controller: _colorText,
                      hint: 'Colour',
                      readOnly: true,
                      onTap: _pickColor,
                      error: _showErrors && _colorMissing,
                      leading: swatch == null
                          ? const Icon(
                              Icons.palette_outlined,
                              size: 20,
                              color: AppColors.ink,
                            )
                          : _Swatch(color: swatch, size: 20),
                      trailing: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (_showErrors && yearError != null) _FieldError(yearError),
              if (_showErrors && _colorMissing)
                const _FieldError(
                  'Pick your car’s colour so parents can spot it',
                ),
              AppPillInput(
                controller: _plate,
                hint: 'License plate, e.g. TS09 AB 1234',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                error: _showErrors && plateError != null,
                inputFormatters: const [PlateFormatter()],
                onChanged: (_) => setState(() {}),
                leading: const Icon(
                  Icons.pin_outlined,
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
              if (_showErrors && plateError != null) _FieldError(plateError),
              _SeatPicker(
                label: 'Car seats',
                options: MyCar.sizes,
                selected: _carSeats,
                onSelected: _setCarSeats,
              ),
              _KidSeatStepper(
                value: _kidSeats,
                max: _maxKidSeats,
                onChanged: (n) => setState(() => _kidSeats = n),
              ),
              Text(
                'A $_carSeats-seater with $_kidSeats '
                '${_kidSeats == 1 ? 'seat' : 'seats'} free for kids. You only '
                'get ride requests that fit.',
                style: AppTextStyles.caption,
              ),
              _BoosterRow(
                value: _booster,
                onChanged: (v) => setState(() => _booster = v),
              ),
              if (!_complete && !keyboardOpen)
                Text(
                  'Add the make and model, colour and plate to submit.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark card at the top: the car photo (or a car icon), photo state, the
/// car's name and a remove button.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.hasPhoto,
    required this.onTap,
    this.localPath,
    this.networkUrl,
    this.onRemove,
  });

  final String title;
  final bool hasPhoto;
  final String? localPath;
  final String? networkUrl;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(
      Icons.directions_car_filled,
      size: 64,
      color: AppColors.lime,
    );
    final Widget thumb = localPath != null
        ? Image.file(File(localPath!), fit: BoxFit.cover)
        : networkUrl != null
        ? Image.network(
            networkUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(child: icon),
          )
        : const Center(child: icon);
    return Semantics(
      button: true,
      label: hasPhoto
          ? 'Retake the photo of your car'
          : 'Add a photo of your car',
      child: Material(
        color: AppColors.inverse,
        borderRadius: BorderRadius.circular(36),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(width: 96, height: 96, child: thumb),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: hasPhoto ? AppColors.lime : null,
                          border: hasPhoto
                              ? null
                              : Border.all(color: AppColors.lime),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasPhoto ? Icons.circle : Icons.add_a_photo,
                              size: hasPhoto ? 8 : 14,
                              color: hasPhoto ? AppColors.ink : AppColors.lime,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasPhoto ? 'Photo added' : 'Add a photo',
                              style: AppTextStyles.caption.copyWith(
                                color: hasPhoto
                                    ? AppColors.ink
                                    : AppColors.lime,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(
                          color: AppColors.textOnDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPhoto ? 'Tap to retake' : 'Tap to add (optional)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textOnDarkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textOnDark,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 36});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.4)),
    ),
  );
}

/// One colour in the colour sheet: swatch with its name under it.
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _Swatch(color: color, size: 40),
                ),
                const SizedBox(height: 6),
                Text(name, style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Car seats  4 5 6 7 8": equal pills, the chosen one dark.
class _SeatPicker extends StatelessWidget {
  const _SeatPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 76, child: Text(label, style: AppTextStyles.label)),
        for (final (i, n) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: n == selected,
              label: '$label $n',
              child: Material(
                color: n == selected ? AppColors.ink : AppColors.surface,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onSelected(n),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        '$n',
                        style: AppTextStyles.title.copyWith(
                          color: n == selected
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Kid seats  –  6 of 7  +": any number up to every seat but the
/// driver's, so a 7- or 8-seater isn't capped.
class _KidSeatStepper extends StatelessWidget {
  const _KidSeatStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String label, int? next) => Semantics(
      button: true,
      label: label,
      child: Material(
        color: next == null ? AppColors.surface : AppColors.ink,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: next == null ? null : () => onChanged(next),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: next == null
                  ? AppColors.textSecondary
                  : AppColors.textOnDark,
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text('Kid seats', style: AppTextStyles.label),
        ),
        button(
          Icons.remove_rounded,
          'Fewer kid seats',
          value > 1 ? value - 1 : null,
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            label: '$value of $max kid seats',
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$value', style: AppTextStyles.title),
                  TextSpan(
                    text: '  of $max',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        button(
          Icons.add_rounded,
          'More kid seats',
          value < max ? value + 1 : null,
        ),
      ],
    );
  }
}

class _BoosterRow extends StatelessWidget {
  const _BoosterRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        children: [
          const AppIcon(AppAssets.iconKid, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Booster seat available', style: AppTextStyles.label),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(color: AppColors.danger),
      ),
    );
  }
}
