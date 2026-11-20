import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/add_kids/domain/entities/child.dart';
import 'package:kidspool/add_kids/domain/entities/place.dart';
import 'package:kidspool/add_kids/presentation/providers/add_child_form_provider.dart';
import 'package:kidspool/add_kids/presentation/providers/kids_provider.dart';
import 'package:kidspool/common/core/services/photo_picker.dart';

/// Just the KidsProvider members the form uses; saves go into [saved].
class _FakeKids extends ChangeNotifier implements KidsProvider {
  final List<Child> _children = [
    const Child(id: 'annie', firstName: 'Annie', grade: 'Kindergarten'),
  ];
  final List<ChildDraft> saved = [];

  @override
  List<Child> get children => List.unmodifiable(_children);
  @override
  bool get hasChildren => _children.isNotEmpty;
  @override
  bool get isSaving => false;
  @override
  String? get errorMessage => null;
  @override
  Child? childById(String? id) =>
      _children.where((c) => c.id == id).firstOrNull;
  @override
  Place? placeById(String id) => null;
  @override
  Future<String?> saveChild(ChildDraft draft) async {
    saved.add(draft);
    final id = draft.id ?? 'kid${saved.length}';
    _children.add(Child(id: id, firstName: draft.firstName));
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeKids kids;
  late AddChildFormProvider form;

  setUp(() {
    kids = _FakeKids();
    form = AddChildFormProvider(kids, PhotoPicker());
  });
  tearDown(() => form.dispose());

  void fillIn(String name) {
    form.firstName.text = name;
    form.setDateOfBirth(DateTime(2019, 5, 1));
    form.setGrade('Grade 1');
  }

  test('a filled-in child is saved, then a blank form opens', () async {
    form.openNew();
    fillIn('Ben');
    expect(await form.addAnother(), isNull);
    expect(kids.saved.single.firstName, 'Ben');
    expect(form.isOpen, isTrue);
    expect(form.editingId, isNull);
    expect(form.firstName.text, isEmpty);
  });

  test('a half-filled child is kept and the parent is told', () async {
    form.openNew();
    form.firstName.text = 'Ben'; // no age or grade yet
    final error = await form.addAnother();
    expect(error, isNotNull);
    expect(kids.saved, isEmpty);
    expect(form.firstName.text, 'Ben');
  });

  test('an untouched blank form asks for details, without clearing', () async {
    form.openNew();
    final error = await form.addAnother();
    expect(error, contains('Fill in this child'));
    expect(form.isOpen, isTrue);
    expect(kids.saved, isEmpty);
  });

  test('editing an existing child, unchanged: opens a new form', () async {
    form.edit('annie');
    expect(await form.addAnother(), isNull);
    expect(form.editingId, isNull);
    expect(form.isOpen, isTrue);
  });

  group('booster seat', () {
    final now = DateTime.now();
    DateTime yearsAgo(int years) => DateTime(now.year - years, 1, 1);

    test('turns on for a new kid under 8, off for an older one', () {
      form.openNew();
      expect(form.needsBooster, isFalse);
      form.setDateOfBirth(yearsAgo(5));
      expect(form.needsBooster, isTrue);
      form.setDateOfBirth(yearsAgo(10));
      expect(form.needsBooster, isFalse);
    });

    test('the parent\'s own choice wins over the age', () {
      form.openNew();
      form.setNeedsBooster(false);
      form.setDateOfBirth(yearsAgo(5));
      expect(form.needsBooster, isFalse);
    });

    test('a new form follows the age again', () {
      form.openNew();
      form.setNeedsBooster(false);
      form.openNew();
      form.setDateOfBirth(yearsAgo(5));
      expect(form.needsBooster, isTrue);
    });

    test('editing a kid keeps their saved value', () {
      form.edit('annie'); // saved without a booster
      form.setDateOfBirth(yearsAgo(5));
      expect(form.needsBooster, isFalse);
    });

    test('under-8 threshold matches Ask for a ride', () {
      final today = DateTime(2026, 11, 20);
      expect(
        AddChildFormProvider.boosterRecommendedFor(
          DateTime(2018, 11, 21),
          today,
        ),
        isTrue, // 7
      );
      expect(
        AddChildFormProvider.boosterRecommendedFor(
          DateTime(2018, 11, 20),
          today,
        ),
        isFalse, // 8 today
      );
    });
  });
}
