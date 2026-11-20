import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/data/models/my_status_model.dart';
import 'package:kidspool/common/domain/entities/my_status.dart';
import 'package:kidspool/messages/data/models/ride_request_model.dart';
import 'package:kidspool/notifications/domain/entities/app_notification.dart';

void main() {
  group('Gender (QA #14)', () {
    test('parses the server values, null and unknown as not set', () {
      expect(Gender.parse('female'), Gender.female);
      expect(Gender.parse('male'), Gender.male);
      expect(Gender.parse('non_binary'), Gender.nonBinary);
      expect(Gender.parse('prefer_not_to_say'), Gender.preferNotToSay);
      expect(Gender.parse(null), isNull);
      expect(Gender.parse('something_else'), isNull);
    });

    test('labels', () {
      expect(Gender.labelOf(Gender.nonBinary), 'Non-binary');
      expect(Gender.labelOf(Gender.preferNotToSay), 'Prefer not to say');
      expect(Gender.labelOf(null), 'Not set');
    });

    test('get_my_status reads gender', () {
      final base = {
        'role': 'parent',
        'firstName': 'Ana',
        'onboardingStatus': 'approved',
      };
      expect(MyStatusModel.fromJson(base).gender, isNull);
      expect(
        MyStatusModel.fromJson({...base, 'gender': 'female'}).gender,
        Gender.female,
      );
      final status = MyStatusModel.fromJson(base).withGender(Gender.male);
      expect(status.gender, Gender.male);
      expect(status.firstName, 'Ana');
    });
  });

  test('new notification kinds (QA #3/#4/#12)', () {
    expect(
      NotificationKind.fromValue('offer_received'),
      NotificationKind.offerReceived,
    );
    expect(
      NotificationKind.fromValue('ride_cancelled'),
      NotificationKind.rideCancelled,
    );
    expect(
      NotificationKind.fromValue('ride_overdue'),
      NotificationKind.rideOverdue,
    );
    expect(
      NotificationKind.fromValue('ride_auto_ended'),
      NotificationKind.rideAutoEnded,
    );
  });

  test('offer_ride waiting_for_parent is not confirmed (QA #4)', () {
    final outcome = RideRequestModel.offerOutcome({
      'status': 'waiting_for_parent',
      'offers': [
        {'offerId': 'o1', 'requestId': 'r1'},
      ],
    }, 'r1');
    expect(outcome.confirmed, isFalse);
    expect(outcome.offerId, 'o1');
  });
}
