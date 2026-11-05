import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../messages/core/utils/messages_format.dart';
import '../../../messages/domain/entities/ride_request.dart';
import '../../../messages/presentation/widgets/messages_common.dart';
import '../../core/constants/rides_styles.dart';

/// F19c "Ride · Emma → Lincoln": avatar, `Emma, Home → Lincoln`, who and
/// when, a badge, info chips and one action button.
class RideListCard extends StatelessWidget {
  const RideListCard({
    super.key,
    required this.ride,
    this.badge,
    this.badgeTone = RideBadgeTone.lime,
    this.chips = const [],
    this.actionLabel,
    this.onAction,
    this.onTap,
  });

  final RideRequest ride;
  final String? badge;
  final RideBadgeTone badgeTone;
  final List<String> chips;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Whole card tap (when there is no action button).
  final VoidCallback? onTap;

  String get _title {
    final kids = MessagesFormat.names(ride.kidNames, fallback: 'Kids');
    final from = ride.pickupLabel.trim().isEmpty ? 'Home' : ride.pickupLabel;
    return '$kids, $from → ${ride.destinationName}';
  }

  String get _subtitle {
    final when =
        '${MessagesFormat.shortWeekday(ride.pickupAt)}, '
        '${MessagesFormat.monthDay(ride.pickupAt)} · '
        '${MessagesFormat.clock(ride.pickupAt)}';
    final who = ride.isMine
        ? (ride.driver != null
              ? '${ride.driver!.shortName} drives'
              : (ride.isOpen ? 'Asking parents' : null))
        : (ride.parent?.shortName ?? 'A parent');
    return who == null ? when : '$who · $when';
  }

  Widget _avatar() {
    final kid = ride.kids.isEmpty ? null : ride.kids.first;
    if (kid?.photoUrl != null) {
      return MessagesAvatar(
        initials: kid!.firstName.isEmpty ? '?' : kid.firstName[0],
        photoUrl: kid.photoUrl,
        size: 48,
        background: AppColors.lime,
      );
    }
    final person = ride.isMine ? ride.driver : ride.parent;
    final initials =
        person?.initials ??
        (kid == null ? '?' : MessagesFormat.initials(kid.firstName));
    return Padding(
      padding: const EdgeInsets.all(2),
      child: MessagesAvatar(
        initials: initials,
        size: 44,
        background: AppColors.lime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = actionLabel;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? onAction,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title, style: RidesStyles.cardTitle),
                        const SizedBox(height: 1),
                        Text(_subtitle, style: RidesStyles.meta),
                      ],
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    _Badge(label: badge!, tone: badgeTone),
                  ],
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in chips) _Chip(c)],
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 10),
                _ActionButton(label: action, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum RideBadgeTone { lime, neutral, white }

/// Figma "Badge" without the dot: 28px pill, 12/16 Medium.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

  final String label;
  final RideBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: switch (tone) {
          RideBadgeTone.lime => AppColors.lime,
          RideBadgeTone.neutral => AppColors.surfaceStrong,
          RideBadgeTone.white => AppColors.screen,
        },
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: RidesStyles.labelS),
    );
  }
}

/// White info pill (`Same school · 0.3 mi`).
class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: RidesStyles.labelS),
    );
  }
}

/// Lime "Button · M" (48px, full width, Glow/Lime).
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: RidesStyles.buttonGlow,
      ),
      child: Material(
        color: AppColors.lime,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Center(child: Text(label, style: RidesStyles.labelM)),
          ),
        ),
      ),
    );
  }
}
