/// Photo ID types accepted by `submit-identity-verification`
/// (`id_document_types`).
enum IdDocumentType {
  driversLicense('drivers_license', 'Driver’s license', 'driver’s license'),
  stateId('state_id', 'State ID', 'state ID'),
  passport('passport', 'US Passport', 'passport', requiresBack: false),
  greenCard('green_card', 'Green Card', 'green card');

  const IdDocumentType(
    this.code,
    this.label,
    this.inSentence, {
    this.requiresBack = true,
  });

  /// `id_document_types.code`.
  final String code;

  /// Chip label: "US Passport".
  final String label;

  /// Mid-sentence form: "Scan your passport".
  final String inSentence;

  /// Passports have no back side to photograph.
  final bool requiresBack;
}
