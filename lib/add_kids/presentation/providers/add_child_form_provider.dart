import 'package:flutter/widgets.dart';

import '../../../common/core/error/exceptions.dart';
import '../../../common/core/services/photo_picker.dart';
import '../../domain/entities/child.dart';
import '../../domain/entities/place.dart';
import '../../../ask_ride/domain/entities/ask_ride_kid.dart';
import 'kids_provider.dart';

/// Form state of F06 · Add a child. One instance per screen.
///
/// The form card is either closed, adding a new child ([editingId] == null)
/// or editing an existing one. Saving calls `add-kid` / `update-kid` with the
/// fields first name, last name, age, gender and notes. The seat a member
/// needs follows their age; the place is chosen later (Locations).
class AddChildFormProvider extends ChangeNotifier {
  AddChildFormProvider(this._kids, this._photos) {
    for (final controller in [firstName, lastName, medicalNotes]) {
      controller.addListener(_onTextChanged);
    }
  }

  final KidsProvider _kids;
  final PhotoPicker _photos;

  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController medicalNotes = TextEditingController();

  bool _isOpen = false;
  String? _editingId;
  DateTime? _dateOfBirth;
  String? _grade;
  String? _gender;
  Place? _school;
  bool _needsBooster = false;
  bool _needsCarSeat = false;

  /// The parent switched the booster seat themselves (or is editing a kid
  /// with a saved value): the age no longer sets it.
  bool _boosterTouched = false;

  /// Current photo source (signed URL or new local file).
  String? _photo;
  String? _newPhotoPath;
  String? _newSchoolIdCardPath;
  bool _hasSchoolIdCard = false;
  bool _dirty = false;
  bool _filling = false;

  static const List<String> grades = [
    'Daycare',
    'Preschool',
    'Pre-K',
    'Kindergarten',
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  bool get isOpen => _isOpen;
  bool get isEditing => _isOpen && _editingId != null;
  String? get editingId => _isOpen ? _editingId : null;
  DateTime? get dateOfBirth => _dateOfBirth;
  String? get grade => _grade;

  /// `male` / `female` / `other`, or null.
  String? get gender => _gender;

  static const Map<String, String> genders = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
  };
  Place? get school => _school;
  bool get needsBooster => _needsBooster;
  bool get needsCarSeat => _needsCarSeat;

  /// The seat chosen for this child.
  SeatNeed get seatNeed => _needsCarSeat
      ? SeatNeed.carSeat
      : _needsBooster
      ? SeatNeed.booster
      : SeatNeed.none;

  /// What the age suggests, when the date of birth is known.
  SeatNeed? get recommendedSeat =>
      _dateOfBirth == null ? null : seatFor(Child.ageOn(_dateOfBirth!));

  /// Car seat with a harness until about 4, then a booster until the adult
  /// belt fits (about 8+), then the seat belt.
  static SeatNeed seatFor(int age) => age < carSeatUntilAge
      ? SeatNeed.carSeat
      : age < AskRideKid.boosterUntilAge
      ? SeatNeed.booster
      : SeatNeed.none;

  static const int carSeatUntilAge = 4;
  String? get photo => _photo;
  bool get hasSchoolIdCard => _hasSchoolIdCard || _newSchoolIdCardPath != null;
  bool get isSaving => _kids.isSaving;

  /// Kids shown as collapsed cards under/instead of the form.
  List<Child> get otherChildren => [
    for (final child in _kids.children)
      if (!_isOpen || child.id != _editingId) child,
  ];

  bool get canSave =>
      _isOpen &&
      !isSaving &&
      firstName.text.trim().isNotEmpty &&
      _dateOfBirth != null;

  /// Continue is available once there is at least one kid and no open form.
  bool get canContinue => !_isOpen && _kids.hasChildren;

  /// Sets the initial state from the route arguments: edit [childId], add a
  /// new child, or — on a first visit — edit the first kid (or start a new
  /// one when there are none yet).
  void start({String? childId, bool newChild = false}) {
    final first = _kids.children.firstOrNull;
    if (childId != null && _kids.childById(childId) != null) {
      edit(childId);
    } else if (newChild || first == null) {
      openNew();
    } else {
      edit(first.id);
    }
  }

  void openNew() {
    _isOpen = true;
    _editingId = null;
    _fill(null);
  }

  void edit(String childId) {
    _isOpen = true;
    _editingId = childId;
    _fill(_kids.childById(childId));
  }

  void close() {
    _isOpen = false;
    _editingId = null;
    notifyListeners();
  }

  /// Sets the date of birth. On a new kid whose booster seat the parent
  /// hasn't switched, kids under [AskRideKid.boosterUntilAge] get it on
  /// (and older kids off).
  void setDateOfBirth(DateTime value) => _change(() {
    _dateOfBirth = value;
    if (!_boosterTouched) _applySeat(seatFor(Child.ageOn(value)));
  });

  void _applySeat(SeatNeed seat) {
    _needsCarSeat = seat == SeatNeed.carSeat;
    _needsBooster = seat == SeatNeed.booster;
  }

  void setSeatNeed(SeatNeed seat) => _change(() {
    _applySeat(seat);
    _boosterTouched = true;
  });

  /// Booster seat recommended at this date of birth (under 8).
  static bool boosterRecommendedFor(DateTime dateOfBirth, [DateTime? today]) =>
      Child.ageOn(dateOfBirth, today) < AskRideKid.boosterUntilAge;

  void setGrade(String value) => _change(() => _grade = value);
  void setGender(String value) => _change(() => _gender = value);
  void setSchool(Place value) => _change(() => _school = value);
  void setNeedsBooster(bool value) => _change(() {
    _needsBooster = value;
    _boosterTouched = true;
  });

  /// Picks the kid's photo. Returns an error message or `null`.
  Future<String?> pickPhoto({required bool fromCamera}) async {
    if (_isPreparingPhoto) return null;
    _isPreparingPhoto = true;
    notifyListeners();
    try {
      final path = await _photos.pick(fromCamera: fromCamera);
      if (path != null) {
        _newPhotoPath = path;
        _photo = path;
        _dirty = true;
      }
      return null;
    } on DeviceException catch (e) {
      return e.message;
    } finally {
      _isPreparingPhoto = false;
      notifyListeners();
    }
  }

  bool _isPreparingPhoto = false;

  /// The kid's photo is being taken / prepared (shows a loader).
  bool get isPreparingPhoto => _isPreparingPhoto;

  /// Picks the school ID card photo. Returns an error message or `null`.
  Future<String?> pickSchoolIdCard({required bool fromCamera}) async {
    try {
      final path = await _photos.pick(fromCamera: fromCamera);
      if (path != null) _change(() => _newSchoolIdCardPath = path);
      return null;
    } on DeviceException catch (e) {
      return e.message;
    }
  }

  /// Saves the open form on the server. Returns an error message, or `null`
  /// on success.
  Future<String?> save() async {
    if (!canSave) return 'Please fill in the required fields.';
    final id = await _kids.saveChild(
      ChildDraft(
        id: _editingId,
        firstName: firstName.text,
        lastName: lastName.text,
        dateOfBirth: _dateOfBirth!,
        grade: _grade,
        // Editing keeps the school set on F09; a new kid has none yet.
        schoolId: _school?.id,
        medicalNotes: medicalNotes.text,
        gender: _gender,
        needsBooster: _needsBooster,
        needsCarSeat: _needsCarSeat,
        newPhotoPath: _newPhotoPath,
        newSchoolIdCardPath: _newSchoolIdCardPath,
      ),
    );
    if (id == null) {
      notifyListeners();
      return _kids.errorMessage ?? 'We couldn’t save. Please try again.';
    }
    _editingId = id;
    _isOpen = false;
    _dirty = false;
    notifyListeners();
    return null;
  }

  /// Saves pending changes (if any), then runs [next]. Returns an error
  /// message when saving failed (and [next] did not run) — incomplete edits
  /// are never discarded silently.
  Future<String?> _saveThen(VoidCallback next) async {
    if (_isOpen && _dirty) {
      final error = await save();
      if (error != null) return error;
    }
    next();
    return null;
  }

  /// First name field of the open form; focused when a new form opens so
  /// it scrolls into view.
  final FocusNode firstNameFocus = FocusNode();

  /// Saves the open form, then opens a blank one. With an untouched new-child
  /// form already open there is nothing to save, so ask for its details.
  Future<String?> addAnother() async {
    if (_isOpen && _editingId == null && !_dirty) {
      return 'Fill in this member’s details first, then add another.';
    }
    return _saveThen(openNew);
  }

  Future<String?> switchTo(String childId) => _saveThen(() => edit(childId));

  void _fill(Child? child) {
    _filling = true;
    firstName.text = child?.firstName ?? '';
    lastName.text = child?.lastName ?? '';
    medicalNotes.text = child?.medicalNotes ?? '';
    _filling = false;
    _dateOfBirth = child?.dateOfBirth;
    // Grade is no longer asked; an existing member keeps theirs.
    _grade = child?.grade;
    _gender = child?.gender;
    final schoolId = child?.schoolId;
    _school = schoolId == null ? null : _kids.placeById(schoolId);
    _needsBooster = child?.needsBooster ?? false;
    _needsCarSeat = child?.needsCarSeat ?? false;
    // An existing kid keeps their saved value; a new one follows the age
    // until the parent switches it.
    _boosterTouched = child != null;
    _photo = child?.photo;
    _newPhotoPath = null;
    _newSchoolIdCardPath = null;
    _hasSchoolIdCard = child?.hasSchoolIdCard ?? false;
    _dirty = false;
    notifyListeners();
  }

  void _onTextChanged() {
    if (!_filling) _dirty = true;
    notifyListeners();
  }

  void _change(VoidCallback change) {
    change();
    _dirty = true;
    notifyListeners();
  }

  @override
  void dispose() {
    firstNameFocus.dispose();
    firstName.dispose();
    lastName.dispose();
    medicalNotes.dispose();
    super.dispose();
  }
}

/// Which seat a child rides in.
enum SeatNeed {
  carSeat('Car seat', 'Harness car seat — babies and toddlers, until about 4.'),
  booster(
    'Booster',
    'Booster seat — until the adult belt fits, about age 8–12 or 145 cm.',
  ),
  none(
    'Seat belt',
    'Adult seat belt — fits across the shoulder and low on the hips.',
  );

  const SeatNeed(this.label, this.helper);

  final String label;
  final String helper;
}
