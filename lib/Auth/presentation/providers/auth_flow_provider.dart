import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/core/constants/app_constants.dart';
import '../../../common/core/error/exceptions.dart';
import '../../../common/core/services/location_service.dart';
import '../../../common/core/services/photo_picker.dart';
import '../../../common/domain/entities/my_status.dart';
import '../../core/constants/auth_api_constants.dart';
import '../../data/data_sources/local/license_reader.dart';
import '../../domain/entities/auth_requests.dart';
import '../../domain/entities/license_details.dart';
import '../../domain/entities/id_document_type.dart';
import '../../domain/entities/ride_role.dart';
import '../../domain/entities/scanned_id.dart';
import '../../domain/repositories/auth_repository.dart';
import 'scan_id_provider.dart';

/// Sign-up state shared across the Auth screens (S03 → V3).
///
/// Registered as a lazy singleton so every screen in the flow sees the same
/// phone number, profile and photos. Talks to `set_my_role`, `add_address`
/// and `submit-identity-verification`.
class AuthFlowProvider extends ChangeNotifier {
  AuthFlowProvider({
    required AuthRepository repository,
    required LocationService location,
    required PhotoPicker photos,
    required SharedPreferences preferences,
    required LicenseReader licenseReader,
    Future<SavedProfile?> Function()? savedProfile,
  }) : _savedProfile = savedProfile,
       _repository = repository,
       _location = location,
       _photos = photos,
       _preferences = preferences,
       _licenseReader = licenseReader;

  final AuthRepository _repository;

  /// The signed-in user's verified number from their profile, for when the
  /// flow is opened without going through the OTP step (e.g. Edit details).
  final Future<SavedProfile?> Function()? _savedProfile;
  final LicenseReader _licenseReader;
  final LocationService _location;
  final PhotoPicker _photos;
  final SharedPreferences _preferences;

  static const int phoneLength = 10;

  // ── S03 · Phone number ────────────────────────────────────────────────────
  String _phoneDigits = '';

  /// National number digits only (max 10, US).
  String get phoneDigits => _phoneDigits;
  bool get isPhoneValid => _phoneDigits.length == phoneLength;

  /// "+14155550142" — the format the OTP functions expect.
  String get e164Phone => '${AuthApiConstants.countryCode}$_phoneDigits';

  /// "(415) 555-0142".
  String get nationalPhone => formatNationalPhone(_phoneDigits);

  /// "+1 (415) 555-0142".
  String get internationalPhone =>
      _phoneDigits.isEmpty ? '' : '+1 ${formatNationalPhone(_phoneDigits)}';

  /// Fills the verified phone and the name from the saved profile when
  /// they're empty — the flow lives in memory, so after an app restart (or
  /// when opened from Profile) they would otherwise be blank, and the ID
  /// check would compare the license with an empty name.
  Future<void> restoreFromProfile() async {
    if (_phoneDigits.isNotEmpty &&
        _firstName.trim().isNotEmpty &&
        _lastName.trim().isNotEmpty) {
      return;
    }
    final saved = await _savedProfile?.call();
    if (saved == null) return;
    var changed = false;
    if (_phoneDigits.isEmpty && saved.phone != null) {
      var digits = saved.phone!.replaceAll(RegExp(r'\D'), '');
      // Stored as E.164 (+1XXXXXXXXXX): keep the national number.
      if (digits.length == phoneLength + 1 && digits.startsWith('1')) {
        digits = digits.substring(1);
      }
      if (digits.length == phoneLength) {
        _phoneDigits = digits;
        changed = true;
      }
    }
    if (_firstName.trim().isEmpty && saved.firstName.trim().isNotEmpty) {
      _firstName = saved.firstName.trim();
      changed = true;
    }
    if (_lastName.trim().isEmpty && saved.lastName.trim().isNotEmpty) {
      _lastName = saved.lastName.trim();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void setPhoneDigits(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    final value = clean.length > phoneLength
        ? clean.substring(0, phoneLength)
        : clean;
    if (value == _phoneDigits) return;
    _phoneDigits = value;
    notifyListeners();
  }

  /// Formats up to 10 digits progressively: "(415) 555-0142".
  static String formatNationalPhone(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer('(');
    for (var i = 0; i < digits.length; i++) {
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    if (digits.length == 3) buffer.write(')');
    return buffer.toString();
  }

  /// Pre-fills the flow from `get_my_status` after signing in.
  void applyStatus(MyStatus status) {
    if (_firstName.isEmpty) _firstName = status.firstName;
    if (_lastName.isEmpty) _lastName = status.lastName;
    _addressSaved = status.hasDefaultAddress;
    notifyListeners();
  }

  // ── S04 · About you ───────────────────────────────────────────────────────
  String _firstName = '';
  String _lastName = '';
  String _street = '';
  String _apt = '';
  String _zip = '';
  String _city = '';
  String _stateCode = '';
  bool _isDefaultAddress = true;
  // The choice saved on About you / Profile, so the ID step (e.g. opened
  // from Profile) knows whether this parent drives.
  late RideRole? _role =
      _preferences.getString(AppConstants.cacheKeyRideRole) ==
          RideRole.seeker.name
      ? RideRole.seeker
      : RideRole.both;
  bool _isGuardian = false;
  bool _agreedToTerms = false;
  String? _selfiePath;

  /// Coordinates of the typed address; reset whenever the address changes.
  ResolvedAddress? _coordinates;
  bool _addressSaved = false;
  bool _isLocating = false;
  bool _isSaving = false;

  String get firstName => _firstName;
  String get lastName => _lastName;
  String get street => _street;
  String get apt => _apt;
  String get zip => _zip;
  String get city => _city;
  String get stateCode => _stateCode;
  bool get isDefaultAddress => _isDefaultAddress;
  RideRole? get role => _role;
  bool get isGuardian => _isGuardian;
  bool get agreedToTerms => _agreedToTerms;

  /// Optional profile photo, sent as the selfie when the parent adds one.
  String? get selfiePath => _selfiePath;
  bool get isLocating => _isLocating;
  bool get isSaving => _isSaving;

  /// Label of the pin on the home map preview, e.g. "24 Maple St, Apt 3".
  String get addressLabel =>
      [_street.trim(), _apt.trim()].where((part) => part.isNotEmpty).join(', ');

  bool get isProfileComplete =>
      _firstName.trim().isNotEmpty &&
      _lastName.trim().isNotEmpty &&
      (_addressSaved ||
          (_street.trim().isNotEmpty &&
              _zip.trim().isNotEmpty &&
              _city.trim().isNotEmpty &&
              _stateCode.trim().isNotEmpty)) &&
      _role != null &&
      _isGuardian &&
      _agreedToTerms;

  void setFirstName(String value) => _update(() => _firstName = value);
  void setLastName(String value) => _update(() => _lastName = value);
  void setStreet(String value) => _updateAddress(() => _street = value);
  void setApt(String value) => _update(() => _apt = value);
  void setZip(String value) => _updateAddress(() => _zip = value);
  void setCity(String value) => _updateAddress(() => _city = value);
  void setStateCode(String value) => _updateAddress(() => _stateCode = value);
  void setDefaultAddress(bool value) =>
      _update(() => _isDefaultAddress = value);
  void selectRole(RideRole value) => _update(() => _role = value);
  void setGuardian(bool value) => _update(() => _isGuardian = value);
  void setAgreedToTerms(bool value) => _update(() => _agreedToTerms = value);

  /// Fills the address from the device location. Returns an error message,
  /// or `null` on success.
  Future<String?> useCurrentLocation() async {
    if (_isLocating) return null;
    _update(() => _isLocating = true);
    try {
      final address = await _location.currentAddress();
      _coordinates = address;
      if (address.street.isNotEmpty) _street = address.street;
      if (address.zip.isNotEmpty) _zip = address.zip;
      if (address.city.isNotEmpty) _city = address.city;
      if (address.stateCode.isNotEmpty) _stateCode = address.stateCode;
      return null;
    } on DeviceException catch (e) {
      return e.message;
    } finally {
      _update(() => _isLocating = false);
    }
  }

  /// Takes the profile photo (front camera) or picks one.
  Future<String?> pickSelfie({required bool fromCamera}) async {
    if (_isPreparingPhoto) return null;
    // The picker resizes/converts the photo before it returns: show a loader
    // meanwhile so the screen doesn't look frozen.
    _update(() => _isPreparingPhoto = true);
    try {
      final path = await _photos.pick(
        fromCamera: fromCamera,
        frontCamera: true,
      );
      if (path != null) _selfiePath = path;
      return null;
    } on DeviceException catch (e) {
      return e.message;
    } finally {
      _update(() => _isPreparingPhoto = false);
    }
  }

  bool _isPreparingPhoto = false;

  /// A profile photo is being taken / prepared.
  bool get isPreparingPhoto => _isPreparingPhoto;

  /// Saves the role and home address (S04 "Continue"). Returns an error
  /// message, or `null` on success.
  Future<String?> submitProfile() async {
    if (!isProfileComplete || _isSaving) return null;
    _update(() => _isSaving = true);
    try {
      final roleResult = await _repository.setParentRole();
      final roleError = roleResult.getLeft().toNullable();
      if (roleError != null) return roleError.message;

      // Save the name; "I need rides" parents are approved right away (no
      // ID review for now) so they can add their kids.
      final basics = await _repository.saveProfileBasics(
        firstName: _firstName,
        lastName: _lastName,
        startNow: _role == RideRole.seeker,
      );
      final basicsError = basics.getLeft().toNullable();
      if (basicsError != null) return basicsError.message;

      if (!_addressSaved) {
        final coordinates =
            _coordinates ??
            await _location.geocode(
              street: _street.trim(),
              city: _city.trim(),
              stateCode: _stateCode.trim(),
              zip: _zip.trim(),
            );
        _coordinates = coordinates;
        final saved = await _repository.addHomeAddress(
          HomeAddress(
            street: _street,
            apt: _apt,
            city: _city,
            stateCode: _stateCode,
            zip: _zip,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            isDefault: _isDefaultAddress,
          ),
        );
        final addressError = saved.getLeft().toNullable();
        if (addressError != null) return addressError.message;
        _addressSaved = true;
      }

      await _preferences.setString(
        AppConstants.cacheKeyRideRole,
        (_role ?? RideRole.both).name,
      );
      return null;
    } on DeviceException catch (e) {
      return e.message;
    } finally {
      _update(() => _isSaving = false);
    }
  }

  // ── V1 / V3 · Photo ID ────────────────────────────────────────────────────
  String? _idFrontPath;
  String? _idBackPath;
  IdSource _idSource = IdSource.camera;
  bool _isSubmittingId = false;

  IdDocumentType _idType = IdDocumentType.driversLicense;

  String? get idFrontPath => _idFrontPath;
  String? get idBackPath => _idBackPath;

  /// Parents who offer rides need a driver's license; parents who only need
  /// rides may use any accepted photo ID.
  List<IdDocumentType> get allowedIdTypes => _role == RideRole.seeker
      ? IdDocumentType.values
      : const [IdDocumentType.driversLicense];

  /// The ID being scanned (always a driver's license for drivers).
  IdDocumentType get idType =>
      allowedIdTypes.contains(_idType) ? _idType : allowedIdTypes.first;

  bool get idNeedsBack => idType.requiresBack;

  bool get hasIdPhotos =>
      _idFrontPath != null && (!idNeedsBack || _idBackPath != null);

  /// Picks another ID type; photos of the previous one are dropped.
  void setIdType(IdDocumentType type) {
    if (type == idType || !allowedIdTypes.contains(type)) return;
    _update(() {
      _idType = type;
      _idFrontPath = null;
      _idBackPath = null;
      _license = null;
      _licenseReadFor = null;
    });
  }

  bool get isSubmittingId => _isSubmittingId;

  /// Takes or picks the photo of one side of the license. Returns an error
  /// message, or `null` (also when the user cancels).
  Future<String?> captureIdSide(IdSide side, {required bool fromCamera}) async {
    try {
      final path = await _photos.pick(fromCamera: fromCamera);
      if (path == null) return null;
      _update(() {
        if (side == IdSide.front) {
          _idFrontPath = path;
        } else {
          _idBackPath = path;
        }
        _idSource = fromCamera ? IdSource.camera : IdSource.gallery;
        // New photo: read the license again.
        _license = null;
        _licenseReadFor = null;
      });
      return null;
    } on DeviceException catch (e) {
      return e.message;
    }
  }

  /// What V3 shows for review, or `null` before the photos are taken.
  ScannedId? get scannedId {
    final front = _idFrontPath;
    if (front == null) return null;
    final name = [
      _firstName.trim(),
      _lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final location = [
      _city.trim(),
      _stateCode.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
    return ScannedId(
      source: _idSource,
      fullName: name,
      location: location,
      frontPath: front,
      backPath: idNeedsBack ? _idBackPath : null,
      selfiePath: _selfiePath,
    );
  }

  /// Sends the selfie and license to `submit-identity-verification`.
  /// Returns an error message, or `null` on success.
  Future<String?> submitIdentity() async {
    final front = _idFrontPath;
    final selfie = _selfiePath;
    if (front == null || (idNeedsBack && _idBackPath == null)) {
      return idNeedsBack
          ? 'Take a photo of both sides of your ${idType.inSentence}.'
          : 'Take a photo of your ${idType.inSentence}.';
    }
    if (_firstName.trim().isEmpty || _lastName.trim().isEmpty) {
      return 'Add your first and last name on the previous step.';
    }
    if (_isSubmittingId) return null;

    _update(() => _isSubmittingId = true);
    final result = await _repository.submitIdentity(
      IdentitySubmission(
        firstName: _firstName,
        lastName: _lastName,
        idType: idType.code,
        selfiePath: selfie,
        idFrontPath: front,
        idBackPath: idNeedsBack ? _idBackPath : null,
      ),
    );
    _update(() => _isSubmittingId = false);
    return result.match((failure) {
      // Already sent before: treat as done, the status screen takes over.
      if (failure.code == 'already_submitted' ||
          failure.code == 'already_approved') {
        return null;
      }
      return failure.message;
    }, (_) => null);
  }

  // ── V3 · On-device license reading (Google ML Kit) ───────────────────────
  LicenseDetails? _license;
  String? _licenseReadFor;
  bool _isReadingLicense = false;

  /// Details read from the photos, or `null` (not read yet / unreadable).
  LicenseDetails? get license => _license;
  bool get isReadingLicense => _isReadingLicense;

  /// True once the current photos were processed (even if nothing was read).
  bool get licenseChecked =>
      _licenseReadFor != null && _licenseReadFor == _photosKey;

  String? get _photosKey =>
      _idFrontPath == null ? null : '$_idFrontPath|$_idBackPath';

  /// Runs ML Kit barcode scanning (back) and text recognition (front) on
  /// the captured photos. Safe to call repeatedly: reads once per photo set.
  Future<void> readLicense() async {
    final front = _idFrontPath;
    final key = _photosKey;
    if (front == null || _isReadingLicense || _licenseReadFor == key) return;
    _update(() => _isReadingLicense = true);
    final details = await _licenseReader.read(
      frontPath: front,
      backPath: _idBackPath,
    );
    // Ignore a stale result if the photos changed meanwhile.
    if (key != _photosKey) {
      _update(() => _isReadingLicense = false);
      return;
    }
    _update(() {
      _license = details;
      _licenseReadFor = key;
      _isReadingLicense = false;
    });
  }

  /// Whether the name typed on About you matches the license photo.
  LicenseNameCheck get licenseNameCheck =>
      checkLicenseName(_license, firstName: _firstName, lastName: _lastName);

  /// True when the license name clearly differs from the typed name.
  bool get licenseNameMismatch => licenseNameCheck == LicenseNameCheck.mismatch;

  /// The identity can be sent once the first **or** last name typed on
  /// About you appears on the license.
  static LicenseNameCheck checkLicenseName(
    LicenseDetails? license, {
    required String firstName,
    required String lastName,
  }) {
    final read = license?.fullName ?? '';
    if (read.trim().isEmpty) return LicenseNameCheck.unreadable;
    Set<String> words(String v) => v
        .toLowerCase()
        .split(RegExp(r'[\s-]+'))
        .map((w) => w.replaceAll(RegExp(r'[^a-z]'), ''))
        .where((w) => w.length > 1)
        .toSet();
    final onLicense = words(read);
    final typed = {...words(firstName), ...words(lastName)};
    return typed.any(onLicense.contains)
        ? LicenseNameCheck.matches
        : LicenseNameCheck.mismatch;
  }

  /// Uses the name read from the license for the identity submission.
  void useLicenseName() {
    final l = _license;
    if (l == null || l.firstName == null || l.lastName == null) return;
    _update(() {
      _firstName = l.firstName!;
      _lastName = l.lastName!;
    });
  }

  /// Forgets the license photos (retake after a rejection).
  void clearIdPhotos() => _update(() {
    _idFrontPath = null;
    _idBackPath = null;
    _license = null;
    _licenseReadFor = null;
  });

  void _updateAddress(VoidCallback change) {
    _coordinates = null;
    _update(change);
  }

  void _update(VoidCallback change) {
    change();
    notifyListeners();
  }
}

/// Result of comparing the typed name with the name read from the license.
enum LicenseNameCheck {
  /// First or last name appears on the license.
  matches,

  /// A name was read, but neither the first nor the last name is on it.
  mismatch,

  /// No name could be read from the photos.
  unreadable,
}

/// Name and phone saved on the user's profile (`profiles`).
typedef SavedProfile = ({String firstName, String lastName, String? phone});
