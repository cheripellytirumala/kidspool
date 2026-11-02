import 'dart:io';

import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/auth_assets.dart';
import '../../core/constants/auth_styles.dart';
import '../../domain/entities/license_details.dart';
import '../../domain/entities/scanned_id.dart';
import '../../../common/presentation/widgets/app_loader.dart';

/// "ID summary" — dark card with the profile photo, the name, the details
/// read on the device by ML Kit and both license photos (V3).
class IdSummaryCard extends StatelessWidget {
  const IdSummaryCard({
    super.key,
    required this.id,
    this.license,
    this.isReading = false,
  });

  final ScannedId id;

  /// Details read from the photos; `null` while reading or when unreadable.
  final LicenseDetails? license;
  final bool isReading;

  @override
  Widget build(BuildContext context) {
    final selfie = id.selfiePath;
    final l = license;
    final state = l?.state;
    final name = (l != null && l.fullName.isNotEmpty)
        ? l.fullName
        : id.fullName;
    final location = [l?.city, state].whereType<String>().join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.inverse,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state == null ? 'DRIVER LICENSE' : 'DRIVER LICENSE · $state',
                  style: AuthTextStyles.captionS.copyWith(
                    color: AppColors.lime,
                  ),
                ),
              ),
              const AppIcon(
                AuthAssets.iconShieldCheck,
                size: 20,
                color: AppColors.lime,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipOval(
                child: selfie != null
                    ? Image.file(
                        File(selfie),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        AuthAssets.idPortrait,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Your name' : name,
                      style: AppTextStyles.headingH3.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                    if ((location.isNotEmpty ? location : id.location)
                        .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location.isNotEmpty ? location : id.location,
                        style: AuthTextStyles.bodyS,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (isReading) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const AppLoader.glyph(size: 18, color: AppColors.lime),
                const SizedBox(width: 10),
                Text('Reading your license…', style: AuthTextStyles.bodyS),
              ],
            ),
          ] else if (l != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Detail(label: 'License', value: l.maskedNumber ?? '—'),
                _Detail(label: 'Expires', value: _monthYear(l.expiryDate)),
                _Detail(label: 'Date of birth', value: _monthYear(l.birthDate)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AuthColors.borderDark)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Photo(label: 'Front', path: id.frontPath),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Photo(label: 'Back', path: id.backPath),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "08/2029".
String _monthYear(DateTime? date) => date == null
    ? '—'
    : '${date.month.toString().padLeft(2, '0')}/${date.year}';

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuthTextStyles.captionS.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AuthTextStyles.labelL.copyWith(color: AppColors.textOnDark),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.label, required this.path});

  final String label;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final file = path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AuthTextStyles.captionS.copyWith(
            color: AppColors.textOnDarkMuted,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 1.586, // ID-1 card
            child: file == null
                ? const ColoredBox(color: AuthColors.charcoal)
                : Image.file(File(file), fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}
