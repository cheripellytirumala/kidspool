import 'package:flutter/widgets.dart';

import 'app_routes.dart';

/// Opens a chat ([route] + [arguments]) at the end of the ask-for-a-ride
/// flow, with the Messages tab underneath it: Back from the chat lands on
/// Messages instead of walking back through Ask for a ride / Families.
void openChatOverMessages(
  NavigatorState navigator,
  String route, {
  Object? arguments,
}) {
  navigator
    ..pushNamedAndRemoveUntil(AppRoutes.messages, (_) => false)
    ..pushNamed(route, arguments: arguments);
}

/// Clears the flow and shows the Messages tab.
void goToMessages(NavigatorState navigator) =>
    navigator.pushNamedAndRemoveUntil(AppRoutes.messages, (_) => false);
