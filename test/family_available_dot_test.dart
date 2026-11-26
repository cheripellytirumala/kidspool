import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/home/data/models/family_model.dart';
import 'package:kidspool/home/presentation/widgets/family_list_card.dart';

void main() {
  Map<String, dynamic> row({bool? available}) => {
    'id': 'p1',
    'firstName': 'Vivek',
    'lastInitial': 'L',
    'initials': 'VL',
    'givesRides': true,
    'available': ?available,
    'kids': [
      {'firstName': 'Casey', 'schoolId': 's1', 'schoolName': 'Vivero'},
    ],
  };

  test('reads "available"; missing means off', () {
    expect(FamilyModel.fromJson(row(available: true))!.available, isTrue);
    expect(FamilyModel.fromJson(row())!.available, isFalse);
  });

  testWidgets('green dot only on an available family', (tester) async {
    Future<void> pump(bool available) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FamilyListCard(
            family: FamilyModel.fromJson(row(available: available))!,
            onTap: () {},
          ),
        ),
      ),
    );
    await pump(true);
    expect(find.byKey(const ValueKey('available-dot')), findsOneWidget);
    await pump(false);
    expect(find.byKey(const ValueKey('available-dot')), findsNothing);
  });
}
