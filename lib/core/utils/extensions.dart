extension NullableStringX on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;

  String orEmpty() => this ?? '';
}
