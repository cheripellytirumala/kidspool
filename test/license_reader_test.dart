import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/auth/data/data_sources/local/license_reader.dart';
import 'package:kidspool/auth/domain/entities/license_details.dart';
import 'package:kidspool/auth/presentation/providers/auth_flow_provider.dart';

void main() {
  group('parseFrontText', () {
    // OCR of the California sample: the name column runs into the expiry
    // column and the "DL" label is misread as "UN".
    const caSample = '''
USA STATE OF CALIFORNIA
DRIVER LICENSE
UN: C1234567 CLASS C
ISSUED 01/15/2024
FN: DRIVER EXPIRY DATE 01/15/2030
LN: SAMPLE
DOB: 10/12/1988
SEX: M HT: 5-10 WT: 175 lbs
123 TEST ST,
SACRAMENTO, CA 95814
''';

    test('reads first and last name without the next column', () {
      final d = MlKitLicenseReader.parseFrontText(caSample);
      expect(d.firstName, 'Driver');
      expect(d.lastName, 'Sample');
      expect(d.fullName, 'Driver Sample');
    });

    test('reads number, dates and state', () {
      final d = MlKitLicenseReader.parseFrontText(caSample);
      expect(d.licenseNumber, 'C1234567');
      expect(d.expiryDate, DateTime(2030, 1, 15));
      expect(d.birthDate, DateTime(1988, 10, 12));
      expect(d.state, 'CA');
    });

    test('AAMVA numbered labels and label on its own line', () {
      final d = MlKitLicenseReader.parseFrontText('''
DL D1234567
1 MITCHELL
2 SARAH JANE
EXP 03/04/2031
''');
      // "1"/"2" without LN/FN aren't labels; LN/FN on separate lines are.
      final e = MlKitLicenseReader.parseFrontText('''
LN
MITCHELL
FN
SARAH JANE 4D DLN
''');
      expect(d.licenseNumber, 'D1234567');
      expect(e.lastName, 'Mitchell');
      expect(e.firstName, 'Sarah Jane');
    });
  });

  group('checkLicenseName', () {
    const license = LicenseDetails(
      source: LicenseReadSource.text,
      firstName: 'Driver',
      lastName: 'Sample',
    );

    LicenseNameCheck check(String first, String last, [LicenseDetails? l]) =>
        AuthFlowProvider.checkLicenseName(
          l ?? license,
          firstName: first,
          lastName: last,
        );

    test('first name alone is enough', () {
      expect(check('driver', 'Smith'), LicenseNameCheck.matches);
    });

    test('last name alone is enough', () {
      expect(check('Dave', 'SAMPLE'), LicenseNameCheck.matches);
    });

    test('neither matches → mismatch', () {
      expect(check('James', 'Bond'), LicenseNameCheck.mismatch);
    });

    test('no name read → unreadable', () {
      expect(
        check(
          'James',
          'Bond',
          const LicenseDetails(source: LicenseReadSource.text),
        ),
        LicenseNameCheck.unreadable,
      );
      expect(
        AuthFlowProvider.checkLicenseName(null, firstName: 'a', lastName: 'b'),
        LicenseNameCheck.unreadable,
      );
    });

    test('ignores case, accents-free punctuation and middle names', () {
      const l = LicenseDetails(
        source: LicenseReadSource.barcode,
        firstName: 'Mary-Ann',
        lastName: "O'Neil",
      );
      expect(check('Mary', 'Smith', l), LicenseNameCheck.matches);
      expect(check('Kate', 'oneil', l), LicenseNameCheck.matches);
    });
  });

  group('Indian license', () {
    test('reads the DL number with spaces, name and dates', () {
      final d = MlKitLicenseReader.parseFrontText('''
INDIAN UNION DRIVING LICENCE
Issued by Government of Telangana
DL No. TS09 20190001234
Name: KIRAN KUMAR REDDY
S/D/W of RAMESH REDDY
Date of Birth: 14-05-1990
Valid Till: 13-05-2040
''');
      expect(d.licenseNumber, 'TS0920190001234');
      expect(d.firstName, 'Kiran Kumar');
      expect(d.lastName, 'Reddy');
      expect(d.birthDate, DateTime(1990, 5, 14));
      expect(d.expiryDate, DateTime(2040, 5, 13));
    });

    test('older 3-digit RTO numbers', () {
      final d = MlKitLicenseReader.parseFrontText(
        'DRIVING LICENCE\nDL NO AP028 2015 0012345\nName: SITA DEVI\n',
      );
      expect(
        d.licenseNumber,
        'AP028201500123'
        '45',
      );
    });
  });

  test('two sides sharing their header are not "the same side"', () {
    final front = {
      'INDIAN',
      'UNION',
      'DRIVING',
      'LICENCE',
      'TELANGANA',
      'TS0920190001234',
      'NAME',
      'KIRAN',
      'KUMAR',
      'REDDY',
      'BIRTH',
      'VALID',
      'TILL',
    };
    final back = {
      'INDIAN',
      'UNION',
      'DRIVING',
      'LICENCE',
      'TELANGANA',
      'TS0920190001234',
      'ADDRESS',
      'BLOOD',
      'GROUP',
      'EMERGENCY',
      'CONTACT',
      'CLASS',
      'LMV',
    };
    expect(MlKitLicenseReader.looksLikeSameText(front, back), isFalse);
    expect(MlKitLicenseReader.looksLikeSameText(front, {...front}), isTrue);
  });
}
