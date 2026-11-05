import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/messages/data/models/ride_chat_model.dart';
import 'package:kidspool/messages/data/models/ride_request_model.dart';
import 'package:kidspool/messages/domain/entities/ride_chat.dart';
import 'package:kidspool/messages/domain/entities/ride_request.dart';

void main() {
  group('RideChatModel.chatsFromJson (get_my_ride_chats)', () {
    test('maps a chat row', () {
      final chats = RideChatModel.chatsFromJson([
        {
          'requestId': 'r1',
          'driverId': 'd1',
          'iAmDriver': true,
          'status': 'confirmed',
          'other': {'id': 'p1', 'firstName': 'Sarah', 'initials': 'SM'},
          'lastMessage': 'Done! I’ll pick them up at 8:30',
          'lastAt': '2026-11-03T08:32:00Z',
          'unread': 2,
        },
      ]);
      expect(chats, hasLength(1));
      final c = chats.single;
      expect(c.requestId, 'r1');
      expect(c.driverId, 'd1');
      expect(c.iAmDriver, isTrue);
      expect(c.status, RideRequestStatus.confirmed);
      expect(c.other.id, 'p1');
      expect(c.other.firstName, 'Sarah');
      expect(c.other.initials, 'SM');
      expect(c.lastMessage, startsWith('Done!'));
      expect(c.lastAt, DateTime.utc(2026, 11, 3, 8, 32).toLocal());
      expect(c.unread, 2);
      expect(c.hasUnread, isTrue);
    });

    test('defaults and derived initials; skips rows without ids', () {
      final chats = RideChatModel.chatsFromJson([
        {'requestId': 'r1'},
        'junk',
        {
          'requestId': 'r2',
          'driverId': 'd2',
          'other': {'firstName': ' Jen ', 'lastName': 'Park'},
        },
      ]);
      expect(chats, hasLength(1));
      final c = chats.single;
      expect(c.iAmDriver, isFalse);
      expect(c.status, RideRequestStatus.open);
      expect(c.other.firstName, 'Jen');
      expect(c.other.initials, 'JP');
      expect(c.lastMessage, isNull);
      expect(c.lastAt, isNull);
      expect(c.unread, 0);
    });

    test('non-list → empty', () {
      expect(RideChatModel.chatsFromJson({'a': 1}), isEmpty);
      expect(RideChatModel.chatsFromJson(null), isEmpty);
    });
  });

  group('RideChatModel messages (get_ride_messages / send_ride_message)', () {
    test('sorts oldest first and skips incomplete rows', () {
      final list = RideChatModel.messagesFromJson([
        {
          'id': 'm2',
          'senderId': 'u2',
          'body': 'Second',
          'createdAt': '2026-11-03T09:20:00Z',
          'readAt': '2026-11-03T09:21:00Z',
        },
        {'id': 'm3', 'senderId': 'u1'},
        {
          'id': 'm1',
          'senderId': 'u1',
          'body': 'First',
          'createdAt': '2026-11-03T09:12:00Z',
        },
      ]);
      expect(list.map((m) => m.id), ['m1', 'm2']);
      expect(list.first.readAt, isNull);
      expect(list.last.readAt, isNotNull);
    });

    test('send result (no readAt) maps', () {
      final m = RideChatModel.messageFromJson({
        'id': 'm9',
        'senderId': 'me',
        'body': 'Hi!',
        'createdAt': '2026-11-03T10:00:00Z',
      });
      expect(m, isNotNull);
      expect(m!.body, 'Hi!');
      expect(m.readAt, isNull);
    });
  });

  group('ChatMessage.isMine', () {
    final message = ChatMessage(
      id: 'm1',
      senderId: 'user-1',
      body: 'Hello',
      createdAt: DateTime(2026, 11, 3),
    );

    test('own message when the sender is the signed-in user', () {
      expect(message.isMine('user-1'), isTrue);
    });

    test('other parent’s message', () {
      expect(message.isMine('user-2'), isFalse);
    });

    test('unknown user → never mine', () {
      expect(message.isMine(null), isFalse);
      expect(message.isMine(''), isFalse);
    });
  });

  group('RideRequestModel.mine (get_ride_request)', () {
    test('maps request, kids, pending offers and driver', () {
      final r = RideRequestModel.mine({
        'id': 'r1',
        'status': 'open',
        'pickupAt': '2026-11-05T08:30:00Z',
        'pickupAddress': {'label': 'Home', 'addressLine1': '24 Maple St'},
        'school': {'name': 'Lincoln Elementary'},
        'seriesId': 's1',
        'kids': [
          {'firstName': 'Emma', 'photoPath': 'k/emma.jpg'},
          {'firstName': ''},
        ],
        'offers': [
          {
            'offerId': 'o1',
            'status': 'pending',
            'createdAt': '2026-11-03T09:00:00Z',
            'daysInOffer': 2,
            'driver': {
              'id': 'd1',
              'firstName': 'Jen',
              'lastName': 'Park',
              'distanceMiles': 1.1,
              'ridesGiven': 4,
              'kidsAtSchool': ['Mia', ' '],
            },
          },
          {
            'offerId': 'o2',
            'status': 'declined',
            'driver': {'id': 'd2', 'firstName': 'David'},
          },
          {'offerId': 'o3'},
        ],
        'note': '  ',
        'needsBooster': true,
      })!;
      expect(r.isMine, isTrue);
      expect(r.isOpen, isTrue);
      expect(r.pickupLabel, 'Home');
      expect(r.destinationName, 'Lincoln Elementary');
      expect(r.kidNames, ['Emma']);
      expect(r.kids.single.photoPath, 'k/emma.jpg');
      expect(r.note, isNull);
      expect(r.needsBooster, isTrue);
      expect(r.offers, hasLength(1));
      final o = r.offers.single;
      expect(o.offerId, 'o1');
      expect(o.daysInOffer, 2);
      expect(o.partner.shortName, 'Jen P.');
      expect(o.partner.initials, 'JP');
      expect(o.partner.distanceMiles, 1.1);
      expect(o.partner.ridesGiven, 4);
      expect(o.partner.kidsAtSchool, ['Mia']);
      expect(r.offerFrom('d1'), o);
      expect(r.offerFrom('d2'), isNull);
      expect(r.driver, isNull);
    });

    test('drop-off label wins over school; missing id → null', () {
      final r = RideRequestModel.mine({
        'id': 'r2',
        'status': 'confirmed',
        'pickupAt': '2026-11-05T08:30:00Z',
        'dropoff': {'label': 'Bluewave Swim'},
        'school': {'name': 'Lincoln'},
        'driver': {'id': 'd1', 'firstName': 'Jen', 'phone': '+1555'},
      })!;
      expect(r.destinationName, 'Bluewave Swim');
      expect(r.status.isBooked, isTrue);
      expect(r.driver?.phone, '+1555');
      expect(RideRequestModel.mine({'pickupAt': '2026-11-05'}), isNull);
    });
  });

  group('RideRequestModel.incoming (get_open_requests / get_my_drives)', () {
    test('maps parent, distance and a pending offer', () {
      final r = RideRequestModel.incoming({
        'id': 'r1',
        'status': 'open',
        'pickupAt': '2026-11-05T08:30:00Z',
        'pickupAddress': {'city': 'Oakland'},
        'school': {'name': 'Lincoln'},
        'parent': {'firstName': 'Sarah', 'lastName': 'Miller'},
        'kids': [
          {'firstName': 'Emma'},
        ],
        'myOffer': {'offerId': 'o1', 'status': 'pending'},
        'distanceFromYouMiles': 0.4,
        'openDaysInSeries': 2,
        'youAreBusy': true,
      })!;
      expect(r.isMine, isFalse);
      expect(r.pickupLabel, 'Oakland');
      expect(r.parent?.firstName, 'Sarah');
      expect(r.parent?.initials, 'SM');
      expect(r.parent?.id, isNull);
      expect(r.myOfferId, 'o1');
      expect(r.offered, isTrue);
      expect(r.distanceMiles, 0.4);
      expect(r.repeats, isTrue);
      expect(r.youAreBusy, isTrue);
    });

    test('a non-pending offer is not the user’s open offer', () {
      final r = RideRequestModel.incoming({
        'id': 'r1',
        'pickupAt': '2026-11-05T08:30:00Z',
        'myOffer': {'offerId': 'o1', 'status': 'withdrawn'},
      })!;
      expect(r.offered, isFalse);
      expect(r.parent?.firstName, 'A parent');
    });
  });

  group('offer_ride / get_request_activity', () {
    test('offerOutcome picks this request’s offer id', () {
      final out = RideRequestModel.offerOutcome({
        'groupId': 'g1',
        'status': 'waiting_for_parent',
        'offers': [
          {'offerId': 'o0', 'requestId': 'other'},
          {'offerId': 'o1', 'requestId': 'r1'},
        ],
      }, 'r1');
      expect(out.offerId, 'o1');
      expect(out.confirmed, isFalse);
    });

    test('offerOutcome confirmed without a matching request', () {
      final out = RideRequestModel.offerOutcome({
        'status': 'confirmed',
        'offers': [
          {'offerId': 'o5', 'requestId': 'x'},
        ],
      }, 'r1');
      expect(out.offerId, 'o5');
      expect(out.confirmed, isTrue);
    });

    test('activity counts', () {
      final a = RideRequestModel.activity({
        'notifiedCount': 6,
        'seenCount': 3,
        'offersCount': 1,
      });
      expect(a.notifiedCount, 6);
      expect(a.seenCount, 3);
      expect(a.offersCount, 1);
    });
  });

  test('RequestsInbox.needsAnswerCount = offers + unanswered requests', () {
    RideRequest req(String id, {String? myOffer, int offers = 0}) =>
        RideRequest(
          id: id,
          isMine: offers > 0,
          status: RideRequestStatus.open,
          pickupAt: DateTime(2026, 11, 5),
          pickupLabel: 'Home',
          destinationName: 'Lincoln',
          myOfferId: myOffer,
          offers: [
            for (var i = 0; i < offers; i++)
              RideOffer(
                offerId: '$id-$i',
                partner: RideRequestModel.person({'firstName': 'P$i'}),
              ),
          ],
        );
    final inbox = RequestsInbox(
      mine: [req('m', offers: 2)],
      incoming: [
        req('a'),
        req('b', myOffer: 'o'),
      ],
    );
    expect(inbox.needsAnswerCount, 3);
  });
}
