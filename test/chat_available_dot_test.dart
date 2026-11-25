import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/messages/data/models/ride_chat_model.dart';
import 'package:kidspool/messages/data/models/ride_request_model.dart';
import 'package:kidspool/messages/domain/entities/chat_person.dart';
import 'package:kidspool/messages/presentation/widgets/chat_widgets.dart';
import 'package:kidspool/messages/presentation/widgets/messages_list_widgets.dart';

Map<String, dynamic> _row({Object? available}) => {
  'requestId': 'r1',
  'driverId': 'd1',
  'iAmDriver': false,
  'status': 'completed',
  'other': {
    'id': 'p1',
    'firstName': 'Vivek',
    'initials': 'VL',
    'available': ?available,
  },
  'lastMessage': 'See you',
  'lastAt': '2026-11-25T08:00:00Z',
  'unread': 0,
};

Future<void> _pump(WidgetTester tester, Map<String, dynamic> row) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatListTile(
            chat: RideChatModel.chatFromJson(row)!,
            onTap: () {},
          ),
        ),
      ),
    );

void main() {
  test('chat row reads whether the other person is available', () {
    expect(
      RideChatModel.chatFromJson(_row(available: true))!.other.available,
      isTrue,
    );
    expect(
      RideChatModel.chatFromJson(_row(available: false))!.other.available,
      isFalse,
    );
    // Older server: no flag → no dot.
    expect(RideChatModel.chatFromJson(_row())!.other.available, isFalse);
  });

  testWidgets('green dot on an available driver’s avatar only', (tester) async {
    await _pump(tester, _row(available: true));
    expect(find.byKey(const ValueKey('available-dot')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Available')), findsWidgets);

    await _pump(tester, _row(available: false));
    expect(find.byKey(const ValueKey('available-dot')), findsNothing);
  });

  test('driver card in the chat reads available', () {
    expect(
      RideRequestModel.person({
        'firstName': 'Vivek',
        'available': true,
      }).available,
      isTrue,
    );
    expect(RideRequestModel.person({'firstName': 'Vivek'}).available, isFalse);
  });

  testWidgets('green dot in the chat header too', (tester) async {
    Future<void> header(bool available) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatHeader(
            person: const ChatPerson(
              firstName: 'Vivek',
              initials: 'VL',
            ).withAvailable(available),
            subtitle: null,
            onInfo: () {},
          ),
        ),
      ),
    );
    await header(true);
    expect(find.byKey(const ValueKey('available-dot')), findsOneWidget);
    await header(false);
    expect(find.byKey(const ValueKey('available-dot')), findsNothing);
  });
}
