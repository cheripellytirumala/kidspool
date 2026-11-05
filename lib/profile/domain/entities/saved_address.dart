import 'package:equatable/equatable.dart';

/// A saved address of the parent (`get_my_addresses`).
class SavedAddress extends Equatable {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine1,
    this.addressLine2,
    this.city = '',
    this.state = '',
    this.zip = '',
    this.isDefault = false,
  });

  final String id;

  /// "Home", "Dad’s home", …
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String zip;

  /// The home point used for every distance.
  final bool isDefault;

  /// "Home · 24 Maple St".
  String get title => addressLine1.isEmpty ? label : '$label · $addressLine1';

  /// "San Francisco, CA 94110".
  String get region {
    final stateZip = [state, zip].where((p) => p.isNotEmpty).join(' ');
    return [city, stateZip].where((p) => p.isNotEmpty).join(', ');
  }

  @override
  List<Object?> get props => [
    id,
    label,
    addressLine1,
    addressLine2,
    city,
    state,
    zip,
    isDefault,
  ];
}
