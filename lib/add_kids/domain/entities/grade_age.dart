/// Checks that a child's age fits the US grade picked on Add a child.
///
/// Typical ages: Pre-K 4, Kindergarten 5, Grade n is n + 5. Kids start
/// early, are held back or skip a year, so one year younger and two years
/// older than typical are still accepted.
abstract final class GradeAge {
  static int? typicalAge(String grade) {
    if (grade == 'Daycare') return 2;
    if (grade == 'Preschool') return 3;
    if (grade == 'Pre-K') return 4;
    if (grade == 'Kindergarten') return 5;
    final match = RegExp(r'^Grade (\d{1,2})$').firstMatch(grade);
    if (match == null) return null;
    return int.parse(match.group(1)!) + 5;
  }

  /// A message when [age] (years) doesn't fit [grade], otherwise null.
  static String? mismatch({required int age, required String grade}) {
    final typical = typicalAge(grade);
    if (typical == null) return null;
    // Daycare takes babies and toddlers.
    final youngest = grade == 'Daycare' ? 0 : typical - 1;
    if (age >= youngest && age <= typical + 2) return null;
    final years = age == 1 ? 'year' : 'years';
    return 'A child who is $age $years old usually isn’t in $grade. '
        'Check the age or the grade.';
  }
}
