import '../../../common/core/error/exceptions.dart';
import '../../../common/core/utils/json_parser.dart';
import '../../domain/entities/saved_address.dart';

/// Parses the `get_my_addresses` RPC response.
abstract final class SavedAddressModel {
  static List<SavedAddress> listFromJson(dynamic json) {
    if (json is! List) throw const ParsingException();
    final list = json
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .where((a) => a.id.isNotEmpty)
        .toList();
    // Default first, keep server order otherwise.
    list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
    return List.unmodifiable(list);
  }

  static SavedAddress fromJson(Map<String, dynamic> json) => SavedAddress(
    id: json.readString('id') ?? '',
    label: json.readString('label') ?? 'Home',
    addressLine1: json.readString('addressLine1') ?? '',
    addressLine2: json.readString('addressLine2'),
    city: json.readString('city') ?? '',
    state: json.readString('state') ?? '',
    zip: json.readString('zip') ?? '',
    isDefault: json.readBool('isDefault') ?? false,
  );
}
