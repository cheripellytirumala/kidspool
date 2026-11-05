import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/data/models/place_details_model.dart';
import 'package:kidspool/common/data/models/place_suggestion_model.dart';

void main() {
  test('parses an autocomplete suggestion', () {
    final model = PlaceSuggestionModel.fromSuggestion({
      'placePrediction': {
        'placeId': 'abc',
        'text': {'text': '24 Maple St, San Francisco, CA, USA'},
        'structuredFormat': {
          'mainText': {'text': '24 Maple St'},
          'secondaryText': {'text': 'San Francisco, CA, USA'},
        },
      },
    })!.toEntity();

    expect(model.placeId, 'abc');
    expect(model.primaryText, '24 Maple St');
    expect(model.secondaryText, 'San Francisco, CA, USA');
  });

  test('skips query predictions without a place id', () {
    expect(
      PlaceSuggestionModel.fromSuggestion({'queryPrediction': {}}),
      isNull,
    );
  });

  test('maps place details into an address', () {
    final address = const PlaceDetailsModel({
      'displayName': {'text': '24 Maple St'},
      'formattedAddress': '24 Maple St, San Francisco, CA 94110, USA',
      'location': {'latitude': 37.75, 'longitude': -122.41},
      'addressComponents': [
        {
          'longText': '24',
          'shortText': '24',
          'types': ['street_number'],
        },
        {
          'longText': 'Maple Street',
          'shortText': 'Maple St',
          'types': ['route'],
        },
        {
          'longText': 'San Francisco',
          'shortText': 'SF',
          'types': ['locality'],
        },
        {
          'longText': 'California',
          'shortText': 'CA',
          'types': ['administrative_area_level_1'],
        },
        {
          'longText': '94110',
          'shortText': '94110',
          'types': ['postal_code'],
        },
      ],
    }).toEntity();

    expect(address.street, '24 Maple Street');
    expect(address.city, 'San Francisco');
    expect(address.stateCode, 'CA');
    expect(address.zip, '94110');
    expect(address.latitude, 37.75);
    expect(address.isComplete, isTrue);
    expect(address.subtitle, 'San Francisco, CA 94110');
  });

  test('a school without a street number uses its name', () {
    final address = const PlaceDetailsModel({
      'displayName': {'text': 'Lincoln Elementary'},
      'formattedAddress': 'Lincoln Elementary, Hyderabad, Telangana, India',
      'location': {'latitude': 17.4, 'longitude': 78.5},
      'addressComponents': [
        {
          'longText': 'Hyderabad',
          'shortText': 'Hyderabad',
          'types': ['locality'],
        },
      ],
    }).toEntity();

    expect(address.street, 'Lincoln Elementary');
    expect(address.title, 'Lincoln Elementary');
    expect(address.city, 'Hyderabad');
  });
}
