import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';

/// Activity indicator built from the app icon: the lime kidpool mark gently
/// pulses (scale + glow) while work is in progress.
///
/// Use [AppLoader.glyph] inside small surfaces such as buttons, where only the
/// route glyph is shown in the given [color].
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.size = 72, this.semanticsLabel = 'Loading'})
    : color = null,
      _glyphOnly = false;

  const AppLoader.glyph({
    super.key,
    this.size = 26,
    this.color = AppColors.ink,
    this.semanticsLabel = 'Loading',
  }) : _glyphOnly = true;

  /// Edge length of the mark (or of the glyph in [AppLoader.glyph]).
  final double size;
  final Color? color;
  final String semanticsLabel;
  final bool _glyphOnly;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: widget._glyphOnly ? _buildGlyph() : _buildMark(),
      ),
    );
  }

  Widget _buildGlyph() {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(_t),
      child: AppIcon(
        AppAssets.logoGlyph,
        size: widget.size,
        color: widget.color,
      ),
    );
  }

  Widget _buildMark() {
    // Proportions of the Figma "Mark": 104px square, 36px radius, 56px glyph.
    final size = widget.size;
    final radius = size * 36 / 104;
    final glyph = size * 56 / 104;

    return SizedBox.square(
      dimension: size * 1.3, // room for the glow
      child: Center(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, child) {
            final t = _t.value;
            return Transform.scale(
              scale: 1 - 0.08 * t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.45 - 0.25 * t),
                      offset: Offset(0, size * 8 / 104),
                      blurRadius: size * 24 / 104,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: SizedBox.square(
            dimension: size,
            child: Center(child: AppIcon(AppAssets.logoGlyph, size: glyph)),
          ),
        ),
      ),
    );
  }
}

/// Shows a centered [AppLoader] over [child] on a transparent background
/// while [isLoading] is true. The page stays visible underneath, but touches
/// are blocked so actions can't be repeated.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.dark = false,
  });

  final bool isLoading;
  final Widget child;

  /// Optional line shown under the loader, e.g. "Saving…".
  final String? message;

  /// Use on dark screens (camera, splash) so the message pill matches.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !isLoading,
            child: AnimatedOpacity(
              opacity: isLoading ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? ColoredBox(
                      // Transparent, but still hit-testable to block taps.
                      color: Colors.transparent,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppLoader(),
                            if (message != null) ...[
                              const SizedBox(height: 8),
                              _MessagePill(message: message!, dark: dark),
                            ],
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Keeps the loading message readable on any background without a scrim.
class _MessagePill extends StatelessWidget {
  const _MessagePill({required this.message, required this.dark});

  final String message;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : AppColors.screen,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: dark ? AppColors.textOnDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
