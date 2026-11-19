import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/core/di/injection_container.dart';
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
import '../../../common/core/error/exceptions.dart';

/// "Your vehicle": sign-up step after the driver's license (then Add a
/// child). The car other parents look for (photo, model, year, color,
/// plate), how many seats it has and how many are free for kids.
/// Route arguments: opened from Profile › My car, Submit returns there.
class VehicleDetailsArgs {
  const VehicleDetailsArgs({this.fromProfile = false});

  final bool fromProfile;
}

class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  final MyCarRepository _repo = sl<MyCarRepository>();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();

  int _carSeats = 5;
  int _kidSeats = 3;
  bool _booster = false;
  String? _photoPath;
  bool _hasSavedPhoto = false;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    // Coming back to this step: show what was saved.
    _repo.get().then((result) {
      final car = result.toNullable();
      if (!mounted || car == null) return;
      setState(() {
        if (MyCar.sizes.contains(car.carSeats)) _carSeats = car.carSeats;
        _kidSeats = car.kidSeats.clamp(1, _carSeats - 1);
        _booster = car.hasBooster;
        _model.text = car.model ?? '';
        _color.text = car.color ?? '';
        _year.text = car.year?.toString() ?? '';
        _plate.text = car.plateNumber ?? '';
        _hasSavedPhoto = car.hasPhoto;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_model, _year, _color, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasPhoto => _photoPath != null || _hasSavedPhoto;

  int get _maxKidSeats => (_carSeats - 1).clamp(1, 7);

  String? get _yearError {
    final t = _year.text.trim();
    if (t.isEmpty) return null;
    final y = int.tryParse(t);
    final max = DateTime.now().year + 1;
    return (y == null || y < 1980 || y > max) ? 'Enter a year like 2021' : null;
  }

  bool get _modelMissing => _model.text.trim().isEmpty;
  bool get _plateMissing => _plate.text.trim().length < 2;

  void _setCarSeats(int seats) => setState(() {
    _carSeats = seats;
    if (_kidSeats > _maxKidSeats) _kidSeats = _maxKidSeats;
  });

  Future<void> _pickPhoto() async {
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_modelMissing || _plateMissing || _yearError != null) {
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
      color: _color.text.trim().isEmpty ? null : _color.text.trim(),
      year: int.tryParse(_year.text.trim()),
      photoPath: _photoPath,
    );
    if (!mounted) return;
    final error = result.getLeft().toNullable();
    if (error != null) {
      setState(() => _saving = false);
      return showAppSnack(context, error.message);
    }
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
      _color.text.trim(),
      _model.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    return Material(
      type: MaterialType.transparency,
      child: AppLoadingOverlay(
        isLoading: _saving,
        message: 'Saving…',
        child: AppScreen(
          title: 'Your vehicle',
          showBack: true,
          gap: 14,
          bottom: AppButton(label: 'Submit', onPressed: _submit),
          children: [
            _PhotoCard(
              title: title.isEmpty ? 'Your car' : title,
              hasPhoto: _hasPhoto,
              onTap: _pickPhoto,
            ),
            AppPillInput(
              controller: _model,
              hint: 'Make and model, e.g. Honda Odyssey',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              error: _showErrors && _modelMissing,
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
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    error: _showErrors && _yearError != null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: (_) => setState(() {}),
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppPillInput(
                    controller: _color,
                    hint: 'Color',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    leading: const AppIcon(AppAssets.iconHeart, size: 20),
                  ),
                ),
              ],
            ),
            if (_showErrors && _yearError != null) _FieldError(_yearError!),
            AppPillInput(
              controller: _plate,
              hint: 'e.g. 7KDP 392',
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              error: _showErrors && _plateMissing,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              onChanged: (_) => setState(() {}),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 22,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 12),
                  Text('Plate ·', style: AppTextStyles.bodyL),
                ],
              ),
            ),
            if (_showErrors && _plateMissing)
              const _FieldError('Enter your license plate'),
            _SeatPicker(
              label: 'Car seats',
              options: MyCar.sizes,
              selected: _carSeats,
              onSelected: _setCarSeats,
            ),
            _SeatPicker(
              label: 'Kid seats',
              options: [for (var i = 1; i <= _maxKidSeats; i++) i],
              selected: _kidSeats,
              onSelected: (n) => setState(() => _kidSeats = n),
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
          ],
        ),
      ),
    );
  }
}

/// Dark card at the top: car icon, photo state and the car's name.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.hasPhoto,
    required this.onTap,
  });

  final String title;
  final bool hasPhoto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(28, 28, 20, 28),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car_filled,
                  size: 76,
                  color: AppColors.lime,
                ),
                const SizedBox(width: 20),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Car seats  4 5 6 7 8" / "Kid seats  1 2 3 4": equal pills, the chosen
/// one dark.
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
