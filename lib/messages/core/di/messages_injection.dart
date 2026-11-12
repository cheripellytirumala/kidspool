import 'package:get_it/get_it.dart';

import '../../../common/presentation/state/nav_badges.dart';
import '../../presentation/providers/messages_badge_counter.dart';
import '../../data/data_sources/remote/messages_remote_data_source.dart';
import '../../data/repositories/messages_repository_impl.dart';
import '../../domain/repositories/messages_repository.dart';
import '../../domain/usecases/add_group_members.dart';
import '../../domain/usecases/cancel_ride_request.dart';
import '../../domain/usecases/create_ride_group.dart';
import '../../domain/usecases/driver_cancel_ride.dart';
import '../../domain/usecases/get_drive_request.dart';
import '../../domain/usecases/get_group_candidates.dart';
import '../../domain/usecases/get_group_messages.dart';
import '../../domain/usecases/get_my_rides.dart';
import '../../domain/usecases/get_my_chats.dart';
import '../../domain/usecases/get_my_ride_groups.dart';
import '../../domain/usecases/get_my_ride_request.dart';
import '../../domain/usecases/get_request_activity.dart';
import '../../domain/usecases/get_requests_inbox.dart';
import '../../domain/usecases/get_ride_group.dart';
import '../../domain/usecases/get_ride_messages.dart';
import '../../domain/usecases/leave_ride_group.dart';
import '../../domain/usecases/mark_group_read.dart';
import '../../domain/usecases/offer_ride.dart';
import '../../domain/usecases/pass_ride_request.dart';
import '../../domain/usecases/rename_ride_group.dart';
import '../../domain/usecases/respond_to_offer.dart';
import '../../domain/usecases/ride_asks.dart';
import '../../domain/usecases/send_group_message.dart';
import '../../domain/usecases/send_ride_message.dart';
import '../../domain/usecases/set_group_muted.dart';
import '../../domain/usecases/withdraw_offer.dart';
import '../../presentation/providers/group_chat_provider.dart';
import '../../presentation/providers/group_info_provider.dart';
import '../../presentation/providers/messages_provider.dart';
import '../../presentation/providers/ride_chat_provider.dart';
import '../../presentation/providers/ride_groups_provider.dart';
import '../../presentation/providers/ride_group_info_provider.dart';
import '../../presentation/providers/ride_request_detail_provider.dart';
import '../../data/data_sources/local/hidden_chats_store.dart';
import '../../data/data_sources/local/passed_requests_store.dart';

/// Registers everything owned by the Messages group.
/// Called from `lib/common/core/di/injection_container.dart`.
void registerMessagesDependencies(GetIt sl) {
  sl
    // Data
    ..registerLazySingleton<HiddenChatsStore>(() => HiddenChatsStore(sl()))
    ..registerLazySingleton<MessagesRemoteDataSource>(
      () => MessagesRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<MessagesRepository>(
      () => MessagesRepositoryImpl(
        remoteDataSource: sl(),
        tokenProvider: sl(),
        passedStore: PassedRequestsStore(sl()),
      ),
    )
    // Use cases
    ..registerLazySingleton<GetRequestsInbox>(() => GetRequestsInbox(sl()))
    ..registerLazySingleton<GetMyRides>(() => GetMyRides(sl()))
    ..registerLazySingleton<GetMyRideRequest>(() => GetMyRideRequest(sl()))
    ..registerLazySingleton<GetDriveRequest>(() => GetDriveRequest(sl()))
    ..registerLazySingleton<GetRequestActivity>(() => GetRequestActivity(sl()))
    ..registerLazySingleton<RespondToOffer>(() => RespondToOffer(sl()))
    ..registerLazySingleton<CancelRideRequest>(() => CancelRideRequest(sl()))
    ..registerLazySingleton<OfferRide>(() => OfferRide(sl()))
    ..registerLazySingleton<WithdrawOffer>(() => WithdrawOffer(sl()))
    ..registerLazySingleton<DriverCancelRide>(() => DriverCancelRide(sl()))
    ..registerLazySingleton<PassRideRequest>(() => PassRideRequest(sl()))
    ..registerLazySingleton<GetMyChats>(() => GetMyChats(sl()))
    ..registerLazySingleton<GetRideMessages>(() => GetRideMessages(sl()))
    ..registerLazySingleton<SendRideMessage>(() => SendRideMessage(sl()))
    // Ride groups
    ..registerLazySingleton<GetMyRideGroups>(() => GetMyRideGroups(sl()))
    ..registerLazySingleton<GetRideGroup>(() => GetRideGroup(sl()))
    ..registerLazySingleton<GetGroupMessages>(() => GetGroupMessages(sl()))
    ..registerLazySingleton<SendGroupMessage>(() => SendGroupMessage(sl()))
    ..registerLazySingleton<MarkGroupRead>(() => MarkGroupRead(sl()))
    ..registerLazySingleton<CreateRideGroup>(() => CreateRideGroup(sl()))
    ..registerLazySingleton<AddGroupMembers>(() => AddGroupMembers(sl()))
    ..registerLazySingleton<LeaveRideGroup>(() => LeaveRideGroup(sl()))
    ..registerLazySingleton<RenameRideGroup>(() => RenameRideGroup(sl()))
    ..registerLazySingleton<SetGroupMuted>(() => SetGroupMuted(sl()))
    ..registerLazySingleton<GetGroupCandidates>(() => GetGroupCandidates(sl()))
    ..registerLazySingleton<PostRideAsk>(() => PostRideAsk(sl()))
    ..registerLazySingleton<GetGroupRideAsks>(() => GetGroupRideAsks(sl()))
    ..registerLazySingleton<HelpWithRideAsk>(() => HelpWithRideAsk(sl()))
    // Providers: one per screen.
    ..registerFactory<MessagesProvider>(
      () => MessagesProvider(
        getRequestsInbox: sl(),
        getMyChats: sl(),
        offerRide: sl(),
        passRideRequest: sl(),
        withdrawOffer: sl(),
        respondToOffer: sl(),
        myUserId: () => sl<GetRideMessages>().myUserId,
        getMyRideGroups: sl(),
        onBadgeChanged: NavBadges.instance.setMessages,
        isChatHidden: sl<HiddenChatsStore>().isHidden,
      ),
    )
    ..registerLazySingleton<MessagesBadgeCounter>(
      () => MessagesBadgeCounter(
        getRequestsInbox: sl(),
        getMyChats: sl(),
        getMyRideGroups: sl(),
        isChatHidden: sl<HiddenChatsStore>().isHidden,
      ),
    )
    ..registerFactory<RideRequestDetailProvider>(
      () => RideRequestDetailProvider(
        getMyRideRequest: sl(),
        getDriveRequest: sl(),
        getRequestActivity: sl(),
        offerRide: sl(),
        passRideRequest: sl(),
        withdrawOffer: sl(),
        respondToOffer: sl(),
        cancelRideRequest: sl(),
        myUserId: () => sl<GetRideMessages>().myUserId,
      ),
    )
    ..registerFactory<RideGroupsProvider>(
      () => RideGroupsProvider(getMyRideGroups: sl()),
    )
    ..registerFactory<RideChatProvider>(
      () => RideChatProvider(
        getMyRideRequest: sl(),
        getDriveRequest: sl(),
        getRideMessages: sl(),
        sendRideMessage: sl(),
        respondToOffer: sl(),
        offerRide: sl(),
        withdrawOffer: sl(),
      ),
    )
    ..registerFactory<RideGroupInfoProvider>(
      () => RideGroupInfoProvider(
        getMyRideRequest: sl(),
        getDriveRequest: sl(),
        getRequestActivity: sl(),
        cancelRideRequest: sl(),
        withdrawOffer: sl(),
        driverCancelRide: sl(),
      ),
    )
    ..registerFactory<GroupChatProvider>(
      () => GroupChatProvider(
        getRideGroup: sl(),
        getGroupMessages: sl(),
        sendGroupMessage: sl(),
        markGroupRead: sl(),
        getRequestsInbox: sl(),
        getGroupRideAsks: sl(),
        helpWithRideAsk: sl(),
      ),
    )
    ..registerFactory<GroupInfoProvider>(
      () => GroupInfoProvider(
        getRideGroup: sl(),
        getGroupCandidates: sl(),
        addGroupMembers: sl(),
        renameRideGroup: sl(),
        setGroupMuted: sl(),
        leaveRideGroup: sl(),
      ),
    );

  // Lets the bottom nav recount the Messages badge from any tab.
  NavBadges.instance.registerMessagesCounter(
    () => sl<MessagesBadgeCounter>()(),
  );
}
