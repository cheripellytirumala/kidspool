import '../../../common/core/usecase/usecase.dart';
import '../../../common/presentation/state/nav_badges.dart';
import '../../domain/usecases/get_my_chats.dart';
import '../../domain/usecases/get_my_ride_groups.dart';
import '../../domain/usecases/get_requests_inbox.dart';

/// Recounts the Messages tab badge from any screen: requests that need an
/// answer (as on the Requests tab) plus chats and ride groups with unread
/// messages.
class MessagesBadgeCounter {
  MessagesBadgeCounter({
    required GetRequestsInbox getRequestsInbox,
    required GetMyChats getMyChats,
    GetMyRideGroups? getMyRideGroups,
    NavBadges? badges,
  }) : _getInbox = getRequestsInbox,
       _getChats = getMyChats,
       _getGroups = getMyRideGroups,
       _badges = badges ?? NavBadges.instance;

  final GetRequestsInbox _getInbox;
  final GetMyChats _getChats;
  final GetMyRideGroups? _getGroups;
  final NavBadges _badges;

  Future<void> call() async {
    final groupsF = _getGroups?.call(const NoParams());
    final (inbox, chats) = await (
      _getInbox(const NoParams()),
      _getChats(const NoParams()),
    ).wait;
    final groups = groupsF == null ? null : await groupsF;
    // Keep the last count when the requests can't be loaded (offline …).
    final requests = inbox.getRight().toNullable();
    if (requests == null) return;
    // Chats missing (not deployed) or failing count as no unread chats.
    final unread = chats.match(
      (_) => 0,
      (list) => list.where((c) => c.hasUnread).length,
    );
    // Groups missing (not deployed) or failing count as 0 too.
    final unreadGroups =
        groups?.match(
          (_) => 0,
          (list) => list.where((g) => g.hasUnread).length,
        ) ??
        0;
    _badges.setMessages(requests.needsAnswerCount + unread + unreadGroups);
  }
}
