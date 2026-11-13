import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/core/services/phone_dialer.dart';

void main() {
  tearDown(() => PhoneDialer.launcher = (_) async => false);

  test('formats numbers as tel: links', () {
    expect(
      PhoneDialer.telUri('+1 (233) 221-1322').toString(),
      'tel:+12332211322',
    );
    expect(PhoneDialer.telUri('98765 43210').toString(), 'tel:9876543210');
    expect(PhoneDialer.telUri('911').toString(), 'tel:911');
    expect(PhoneDialer.telUri('  '), isNull);
  });

  test('dial opens the dialer with the number', () async {
    Uri? opened;
    PhoneDialer.launcher = (uri) async {
      opened = uri;
      return true;
    };
    expect(await PhoneDialer.dial('+1 233 221 1322'), isTrue);
    expect(opened.toString(), 'tel:+12332211322');
  });

  test('dial reports failure when the device cannot dial', () async {
    PhoneDialer.launcher = (_) async => throw Exception('no phone app');
    expect(await PhoneDialer.dial('+12332211322'), isFalse);
    expect(await PhoneDialer.dial(''), isFalse);
  });
}
