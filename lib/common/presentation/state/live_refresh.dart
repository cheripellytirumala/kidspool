import 'dart:async';

import 'package:flutter/widgets.dart';

import 'nav_badges.dart';

/// Keeps open screens current without the user switching tabs: while the
/// app is in the foreground it ticks every [interval] (and right away when
/// the app comes back). Each tick recounts the Messages badge, and screens
/// wrapped in [LiveRefreshListener] reload their data quietly.
class LiveRefresh with WidgetsBindingObserver {
  LiveRefresh._();

  static final LiveRefresh instance = LiveRefresh._();

  static const Duration interval = Duration(seconds: 20);

  /// Bumped on every tick; listeners reload when it changes.
  final ValueNotifier<int> ticks = ValueNotifier<int>(0);

  Timer? _timer;
  bool _started = false;

  /// Starts ticking (once, from `main`).
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  /// Ticks now, e.g. after a push or a ride alert.
  void nudge() => _tick();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      _schedule();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
  }

  void _tick() {
    unawaited(NavBadges.instance.refresh(force: true));
    ticks.value++;
  }
}

/// Calls [onRefresh] on every [LiveRefresh] tick while this widget is on
/// screen (and its route is the top one), so the list reloads in place.
class LiveRefreshListener extends StatefulWidget {
  const LiveRefreshListener({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<LiveRefreshListener> createState() => _LiveRefreshListenerState();
}

class _LiveRefreshListenerState extends State<LiveRefreshListener> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    LiveRefresh.instance.ticks.addListener(_onTick);
  }

  @override
  void dispose() {
    LiveRefresh.instance.ticks.removeListener(_onTick);
    super.dispose();
  }

  Future<void> _onTick() async {
    // Only the screen the user is looking at; covered ones reload on return.
    if (_busy || !mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _busy = true;
    try {
      await widget.onRefresh();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
