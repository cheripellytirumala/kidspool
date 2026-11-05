/// Null-safe, type-tolerant JSON readers.
///
/// Backends often send numbers as strings (`"20"`) or flags as `"0"`/`"1"`;
/// these helpers normalise them without throwing.
extension JsonMapX on Map<String, dynamic> {
  String? readString(String key) {
    final value = this[key];
    if (value == null) return null;
    return value.toString();
  }

  int? readInt(String key) {
    final value = this[key];
    return switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt(),
      _ => null,
    };
  }

  double? readDouble(String key) {
    final value = this[key];
    return switch (value) {
      num v => v.toDouble(),
      String v => double.tryParse(v.trim()),
      _ => null,
    };
  }

  bool? readBool(String key) {
    final value = this[key];
    return switch (value) {
      bool v => v,
      num v => v != 0,
      String v => switch (v.trim().toLowerCase()) {
        '1' || 'true' || 'yes' => true,
        '0' || 'false' || 'no' => false,
        _ => null,
      },
      _ => null,
    };
  }

  List<T> readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final value = this[key];
    if (value is! List) return <T>[];
    return value
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }
}
