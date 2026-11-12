import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/core/di/injection_container.dart';
import '../../core/utils/ride_alert_payload.dart';
import '../../domain/entities/ride_alert.dart';
import '../providers/ride_alerts_provider.dart';
import 'ride_alert_card.dart';

/// Wraps the app and slides the S19 / S20 lime ride alerts in from the top
/// when `get_my_notifications` has new ones (in-app stand-in for push).
///
/// Use it from `MaterialApp.builder`, giving it the same [navigatorKey] as
/// `MaterialApp.navigatorKey`, since the builder's context is above the
/// Navigator:
///
/// ```dart
/// MaterialApp(
///   navigatorKey: rideNavigatorKey,
///   builder: (context, child) =>
///       RideAlertsHost(navigatorKey: rideNavigatorKey, child: child!),
/// )
/// ```
///
/// Polls every 30 s while the app is in the foreground and only when
/// someone is signed in (the splash / sign-in flow never calls the API).
class RideAlertsHost extends StatefulWidget {
  const RideAlertsHost({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.provider,
    this.autoHide = const Duration(seconds: 10),
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Defaults to a new `sl<RideAlertsProvider>()`.
  final RideAlertsProvider? provider;

  /// A banner hides itself after this long.
  final Duration autoHide;

  @override
  State<RideAlertsHost> createState() => _RideAlertsHostState();
}

class _RideAlertsHostState extends State<RideAlertsHost>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final RideAlertsProvider _alerts =
      widget.provider ?? sl<RideAlertsProvider>();
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));

  RideAlert? _shown;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alerts.addListener(_onAlerts);
    _alerts.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _alerts.removeListener(_onAlerts);
    if (widget.provider == null) _alerts.dispose();
    _slide.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _alerts.start();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _alerts.stop();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onAlerts() {
    final next = _alerts.current;
    if (next == null || next == _shown) return;
    setState(() => _shown = next);
    _slide.forward(from: 0);
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.autoHide, _hide);
  }

  Future<void> _hide() async {
    _hideTimer?.cancel();
    if (!mounted || _shown == null) return;
    await _slide.reverse();
    if (!mounted) return;
    setState(() => _shown = null);
    _alerts.dismiss();
  }

  void _open(RideAlert alert) {
    final payload = RideAlertPayload.fromAlert(alert);
    unawaited(_hide());
    if (payload == null) return;
    widget.navigatorKey.currentState?.pushNamed(
      payload.route,
      arguments: payload.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alert = _shown;
    return Stack(
      children: [
        widget.child,
        if (alert != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  kRideAlertInset,
                  8,
                  kRideAlertInset,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kRideAlertMaxWidth,
                    ),
                    child: SlideTransition(
                      position: _offset,
                      child: Dismissible(
                        key: ValueKey(alert.id),
                        direction: DismissDirection.up,
                        onDismissed: (_) {
                          _hideTimer?.cancel();
                          setState(() => _shown = null);
                          _alerts.dismiss();
                        },
                        child: RideAlertCard(
                          alert: alert,
                          onOpen: alert.requestId == null
                              ? null
                              : () => _open(alert),
                          onClose: _hide,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
