import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/data/data_sources/local/kid_activities_store.dart';
import 'package:kidspool/add_kids/domain/entities/place.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _swim = Place(
  id: 'g-swim',
  name: 'Bluewave Swim Club',
  category: PlaceCategory.swim,
  details: '500 Lake Ave, Coimbatore',
  latitude: 11.02,
  longitude: 76.96,
  addressLine: '500 Lake Ave',
  city: 'Coimbatore',
);

void main() {
  test('activities survive a restart, per parent', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? user = 'ashley';
    final store = KidActivitiesStore(prefs, () => user);
    await store.write([
      (place: _swim, childIds: {'james'}),
    ]);

    final again = KidActivitiesStore(prefs, () => user).read();
    expect(again.single.place.name, 'Bluewave Swim Club');
    expect(again.single.place.category, PlaceCategory.swim);
    expect(again.single.place.latitude, 11.02);
    expect(again.single.childIds, {'james'});

    user = 'jessica';
    expect(store.read(), isEmpty);
    user = null;
    expect(store.read(), isEmpty);
  });
}
