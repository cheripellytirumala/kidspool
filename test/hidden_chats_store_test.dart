import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/messages/data/data_sources/local/hidden_chats_store.dart';
import 'package:kidspool/messages/domain/entities/chat_person.dart';
import 'package:kidspool/messages/domain/entities/ride_chat.dart';
import 'package:kidspool/messages/domain/entities/ride_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

RideChat _chat({DateTime? lastAt, String request = 'r1'}) => RideChat(
  requestId: request,
  driverId: 'd1',
  iAmDriver: false,
  status: RideRequestStatus.open,
  other: const ChatPerson(firstName: 'Olivia', initials: 'OB'),
  lastMessage: 'Hi',
  lastAt: lastAt,
);

void main() {
  late HiddenChatsStore store;
  final deletedAt = DateTime.utc(2026, 11, 10, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = HiddenChatsStore(await SharedPreferences.getInstance());
  });

  test('a deleted chat is hidden', () async {
    await store.hide('r1', 'd1', at: deletedAt);
    expect(store.isHidden(_chat(lastAt: deletedAt)), isTrue);
    expect(store.isHidden(_chat()), isTrue);
  });

  test('a new message after deleting brings the chat back', () async {
    await store.hide('r1', 'd1', at: deletedAt);
    final newer = deletedAt.add(const Duration(minutes: 1));
    expect(store.isHidden(_chat(lastAt: newer)), isFalse);
  });

  test('other chats are untouched and it survives a restart', () async {
    await store.hide('r1', 'd1', at: deletedAt);
    expect(store.isHidden(_chat(request: 'r2')), isFalse);
    final again = HiddenChatsStore(await SharedPreferences.getInstance());
    expect(again.isHidden(_chat(lastAt: deletedAt)), isTrue);
  });
}
