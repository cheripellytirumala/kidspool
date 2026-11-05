import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/home/data/data_sources/remote/home_remote_data_source.dart';
import 'package:kidspool/messages/data/models/ride_request_model.dart';
import 'package:kidspool/ride_tracking/data/models/ride_tracking_model.dart';
import 'package:kidspool/ride_tracking/domain/entities/ride_tracking.dart';

const _dropoff = {
  'label': 'Bluewave Swim Club',
  'addressLine1': '500 Lake Ave',
  'city': 'Oakland',
  'state': 'CA',
  'zip': '94610',
  'latitude': 37.81,
  'longitude': -122.25,
};

const _school = {
  'name': 'Lincoln Elementary',
  'latitude': 37.7,
  'longitude': -122.4,
};

void main() {
  group('tracking dropoff', () {
    Map<String, dynamic> json({Object? dropoff}) => {
      'requestId': 'r1',
      'status': 'in_progress',
      'pickupAt': '2026-11-05T08:30:00Z',
      'pickedUpAt': '2026-11-05T08:35:00Z',
      'school': _school,
      'pickupAddress': {
        'label': 'Home',
        'latitude': 37.8,
        'longitude': -122.27,
      },
      'dropoff': dropoff,
    };

    test('custom drop-off is the destination', () {
      final t = RideTrackingModel.fromJson(json(dropoff: _dropoff));
      expect(t.hasCustomDropoff, isTrue);
      expect(t.destination.label, 'Bluewave Swim Club');
      expect(t.destination.point, const GeoPoint(37.81, -122.25));
      expect(t.nextStop, t.destination);
      expect(t.school.label, 'Lincoln Elementary');
    });

    test('label falls back to addressLine1', () {
      final t = RideTrackingModel.fromJson(
        json(dropoff: {..._dropoff, 'label': ' '}),
      );
      expect(t.destination.label, '500 Lake Ave');
    });

    test('null dropoff → school, as before', () {
      final t = RideTrackingModel.fromJson(json());
      expect(t.hasCustomDropoff, isFalse);
      expect(t.dropoff, isNull);
      expect(t.destination, t.school);
      expect(t.destination.label, 'Lincoln Elementary');
      expect(t.destination.point, const GeoPoint(37.7, -122.4));
    });
  });

  group('home UpcomingRide dropoff', () {
    Map<String, dynamic> row({Object? dropoff}) => {
      'id': 'r1',
      'status': 'confirmed',
      'pickupAt': '2026-11-05T08:30:00Z',
      'school': _school,
      'pickupAddress': {'label': 'Home', 'addressLine1': '24 Maple St'},
      'kids': [
        {'firstName': 'Emma'},
      ],
      'dropoff': dropoff,
    };

    test('ride title prefers the drop-off', () {
      final r = HomeRemoteDataSourceImpl.parseRide(row(dropoff: _dropoff))!;
      expect(r.destinationName, 'Bluewave Swim Club');
      expect(r.title, 'Emma · Home → Bluewave Swim Club');
    });

    test('drive uses the drop-off too', () {
      final r = HomeRemoteDataSourceImpl.parseDrive(row(dropoff: _dropoff))!;
      expect(r.title, 'Emma · 24 Maple St → Bluewave Swim Club');
    });

    test('null dropoff → school name', () {
      final r = HomeRemoteDataSourceImpl.parseRide(row())!;
      expect(r.dropoffLabel, isNull);
      expect(r.title, 'Emma · Home → Lincoln Elementary');
    });
  });

  group('messages RideRequest dropoff', () {
    Map<String, dynamic> row({Object? dropoff}) => {
      'id': 'r1',
      'status': 'open',
      'pickupAt': '2026-11-05T08:30:00Z',
      'school': _school,
      'parent': {'firstName': 'Sarah'},
      'dropoff': dropoff,
    };

    test('incoming request prefers the drop-off', () {
      final r = RideRequestModel.incoming(row(dropoff: _dropoff))!;
      expect(r.destinationName, 'Bluewave Swim Club');
    });

    test('null dropoff → school name', () {
      expect(
        RideRequestModel.incoming(row())!.destinationName,
        'Lincoln Elementary',
      );
      expect(
        RideRequestModel.mine(row())!.destinationName,
        'Lincoln Elementary',
      );
    });
  });
}
