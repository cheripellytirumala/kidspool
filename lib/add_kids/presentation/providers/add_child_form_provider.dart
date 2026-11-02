import 'package:flutter/widgets.dart';

import '../../../common/core/error/exceptions.dart';
import '../../../common/core/services/photo_picker.dart';
import '../../domain/entities/child.dart';
import '../../domain/entities/place.dart';
import 'kids_provider.dart';

/// Form state of F06 · Add a child. One instance per screen.
///
/// The form card is either closed, adding a new child ([editingId] == null)
/// or editing an existing one. Saving calls `add-kid` / `update-kid`, which
/// require a date of birth, a school and (for a new kid) a school ID card.
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
  Place? _school;
  bool _needsBooster = false;

  /// Current photo source (signed URL or new local file).
  String? _photo;
  String? _newPhotoPath;
  String? _newSchoolIdCardPath;
  bool _hasSchoolIdCard = false;
  bool _dirty = false;
  bool _filling = false;

  static const List<String> grades = [
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
  Place? get school => _school;
  bool get needsBooster => _needsBooster;
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
      _dateOfBirth != null &&
      _grade != null &&
      _school != null &&
      hasSchoolIdCard;

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

  void setDateOfBirth(DateTime value) => _change(() => _dateOfBirth = value);
  void setGrade(String value) => _change(() => _grade = value);
  void setSchool(Place value) => _change(() => _school = value);
  void setNeedsBooster(bool value) => _change(() => _needsBooster = value);

  /// Picks the kid's photo. Returns an error message or `null`.
  Future<String?> pickPhoto({required bool fromCamera}) async {
    try {
      final path = await _photos.pick(fromCamera: fromCamera);
      if (path != null) {
        _change(() {
          _newPhotoPath = path;
          _photo = path;
        });
      }
      return null;
    } on DeviceException catch (e) {
      return e.message;
    }
  }

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
        schoolId: _school!.id,
        medicalNotes: medicalNotes.text,
        needsBooster: _needsBooster,
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
  /// message when saving failed (and [next] did not run).
  Future<String?> _saveThen(VoidCallback next) async {
    if (_isOpen && _dirty && canSave) {
      final error = await save();
      if (error != null) return error;
    }
    next();
    return null;
  }

  Future<String?> addAnother() => _saveThen(openNew);

  Future<String?> switchTo(String childId) => _saveThen(() => edit(childId));

  void _fill(Child? child) {
    _filling = true;
    firstName.text = child?.firstName ?? '';
    lastName.text = child?.lastName ?? '';
    medicalNotes.text = child?.medicalNotes ?? '';
    _filling = false;
    _dateOfBirth = child?.dateOfBirth;
    _grade = child?.grade;
    final schoolId = child?.schoolId;
    _school = schoolId == null ? null : _kids.placeById(schoolId);
    _needsBooster = child?.needsBooster ?? false;
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
    firstName.dispose();
    lastName.dispose();
    medicalNotes.dispose();
    super.dispose();
  }
}
