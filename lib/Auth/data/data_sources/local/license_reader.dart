import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../common/core/utils/logger.dart';
import '../../../domain/entities/license_details.dart';

/// Reads a US driver's license on the device with Google ML Kit:
///   1. the PDF417 barcode on the back (AAMVA), parsed by ML Kit;
///   2. otherwise text recognition on the front (labels such as DL, EXP,
///      DOB, LN/FN).
///
/// Never throws: returns `null` when nothing useful could be read.
abstract interface class LicenseReader {
  Future<LicenseDetails?> read({required String frontPath, String? backPath});

  /// True when two photos show the same side of the card (the same file,
  /// or nearly the same printed text), e.g. the front taken again as the
  /// back. Never throws: false when it can't tell.
  Future<bool> isSameSide(String pathA, String pathB);
}

class MlKitLicenseReader implements LicenseReader {
  static const _tag = 'LicenseReader';

  @override
  Future<LicenseDetails?> read({
    required String frontPath,
    String? backPath,
  }) async {
    LicenseDetails? fromBarcode;
    if (backPath != null) fromBarcode = await _readBarcode(backPath);
    // Some states print the barcode on the front.
    fromBarcode ??= await _readBarcode(frontPath);
    if (fromBarcode != null && !fromBarcode.isEmpty) return fromBarcode;

    final fromText = await _readText(frontPath);
    return (fromText == null || fromText.isEmpty) ? null : fromText;
  }

  @override
  Future<bool> isSameSide(String pathA, String pathB) async {
    try {
      final a = await File(pathA).readAsBytes();
      final b = await File(pathB).readAsBytes();
      if (a.length == b.length && _sameBytes(a, b)) return true;
    } catch (_) {
      return false;
    }
    final wordsA = await _words(pathA);
    final wordsB = await _words(pathB);
    return looksLikeSameText(wordsA, wordsB);
  }

  /// The same side photographed twice shares nearly all its text. Two
  /// sides can share a lot too (Indian cards print "Union of India",
  /// "Driving Licence", the state and the number on both), so only a very
  /// close match counts.
  static bool looksLikeSameText(Set<String> a, Set<String> b) {
    if (a.length < 5 || b.length < 5) return false;
    final shared = a.intersection(b).length;
    final smaller = a.length < b.length ? a.length : b.length;
    return shared / smaller >= 0.85;
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<Set<String>> _words(String path) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return result.text
          .toUpperCase()
          .split(RegExp(r'[^A-Z0-9]+'))
          .where((w) => w.length >= 3)
          .toSet();
    } catch (e) {
      AppLogger.warning('Text recognition failed: $e', tag: _tag);
      return const {};
    } finally {
      await recognizer.close();
    }
  }

  // ── Barcode (AAMVA PDF417) ───────────────────────────────────────────────

  Future<LicenseDetails?> _readBarcode(String path) async {
    final scanner = BarcodeScanner(formats: const [BarcodeFormat.pdf417]);
    try {
      final barcodes = await scanner.processImage(
        InputImage.fromFilePath(path),
      );
      for (final barcode in barcodes) {
        final value = barcode.value;
        if (value is BarcodeDriverLicense) {
          return LicenseDetails(
            source: LicenseReadSource.barcode,
            firstName: _name(value.firstName),
            lastName: _name(value.lastName),
            licenseNumber: _clean(value.licenseNumber),
            expiryDate: _aamvaDate(value.expiryDate),
            birthDate: _aamvaDate(value.birthDate),
            state: _clean(value.addressState),
            city: _name(value.addressCity),
          );
        }
        final raw = barcode.rawValue;
        if (raw != null && raw.contains('ANSI')) return _parseAamva(raw);
      }
    } catch (e) {
      AppLogger.warning('Barcode scan failed: $e', tag: _tag);
    } finally {
      await scanner.close();
    }
    return null;
  }

  /// Fallback when ML Kit doesn't classify the barcode as a license:
  /// AAMVA element ids (DAC first name, DCS last name, DAQ number, ...).
  LicenseDetails _parseAamva(String raw) {
    String? field(String id) {
      final match = RegExp('$id([^\\n\\r]*)').firstMatch(raw);
      return _clean(match?.group(1));
    }

    return LicenseDetails(
      source: LicenseReadSource.barcode,
      firstName: _name(field('DAC') ?? field('DCT')),
      lastName: _name(field('DCS') ?? field('DAB')),
      licenseNumber: field('DAQ'),
      expiryDate: _aamvaDate(field('DBA')),
      birthDate: _aamvaDate(field('DBB')),
      state: field('DAJ'),
      city: _name(field('DAI')),
    );
  }

  /// AAMVA dates are MMDDYYYY (US) or YYYYMMDD (Canada).
  static DateTime? _aamvaDate(String? value) {
    final v = value?.replaceAll(RegExp(r'\D'), '');
    if (v == null || v.length != 8) return null;
    final first4 = int.parse(v.substring(0, 4));
    final (y, m, d) = first4 > 1900
        ? (first4, int.parse(v.substring(4, 6)), int.parse(v.substring(6, 8)))
        : (
            int.parse(v.substring(4, 8)),
            int.parse(v.substring(0, 2)),
            int.parse(v.substring(2, 4)),
          );
    return _validDate(y, m, d);
  }

  // ── Text recognition (front) ─────────────────────────────────────────────

  Future<LicenseDetails?> _readText(String path) async {
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return parseFrontText(result.text);
    } catch (e) {
      AppLogger.warning('Text recognition failed: $e', tag: _tag);
      return null;
    } finally {
      await recognizer.close();
    }
  }

  static final _date = RegExp(
    r'\b(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{4})\b',
  );

  /// Labels before the expiry date: US ("EXP", "4b EXP") and Indian
  /// ("Valid Till", "Validity (NT)") licenses.
  static const _expiryLabels = [
    'EXP',
    'VALID TILL',
    'VALID UPTO',
    'VALID UP TO',
    'VALID UNTIL',
    'VALIDITY',
  ];
  static const _birthLabels = ['DOB', 'D.O.B', 'DATE OF BIRTH', 'BIRTH'];

  /// Every label that is followed by a date, so one field's search never
  /// borrows the date of the next one.
  static const _anyDateLabel = [
    ..._expiryLabels,
    ..._birthLabels,
    'ISS',
    'ISSUE',
    'DATE OF',
  ];

  /// Best-effort parse of the printed front of a license (US, or Indian
  /// with day-first dates).
  static LicenseDetails parseFrontText(String text) {
    final upper = text.toUpperCase();
    final lines = upper
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // Indian (and most non-US) licenses print day/month/year.
    final dayFirst = RegExp(
      r'\bINDIA\b|UNION OF INDIA|TRANSPORT|VALID TILL|VALIDITY|DATE OF BIRTH',
    ).hasMatch(upper);

    DateTime? toDate(Match m) {
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      // A first part over 12 can only be the day.
      if (dayFirst || a > 12) return _validDate(y, b, a);
      return _validDate(y, a, b);
    }

    DateTime? dateAfter(List<String> labels) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final at = labels
            .map((l) => line.indexOf(l))
            .where((p) => p >= 0)
            .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
        if (at == null) continue;
        // On the same line, after the label (not a date before it).
        for (final m in _date.allMatches(line.substring(at))) {
          final date = toDate(m);
          if (date != null) return date;
        }
        // Or on the next line, unless that line is another field's.
        if (i + 1 < lines.length) {
          final next = lines[i + 1];
          if (_anyDateLabel.any(next.contains)) continue;
          for (final m in _date.allMatches(next)) {
            final date = toDate(m);
            if (date != null) return date;
          }
        }
      }
      return null;
    }

    var expiry = dateAfter(_expiryLabels);
    var birth = dateAfter(_birthLabels);
    // One date can't be both; a birth date is in the past and an expiry
    // comes after it.
    final today = DateTime.now();
    if (birth != null && (birth == expiry || birth.isAfter(today))) {
      birth = null;
    }
    if (expiry != null && birth != null && !expiry.isAfter(birth)) {
      expiry = null;
    }
    // No labels read: the earliest date at least 15 years ago is the birth
    // date, the latest date is the expiry.
    if (birth == null || expiry == null) {
      final all = [for (final m in _date.allMatches(upper)) ?toDate(m)]..sort();
      if (birth == null) {
        final cutoff = DateTime(today.year - 15, today.month, today.day);
        birth = all.where((d) => d.isBefore(cutoff)).firstOrNull;
      }
      if (expiry == null && all.isNotEmpty && all.last != birth) {
        final last = all.last;
        if (birth == null || last.isAfter(DateTime(birth.year + 16))) {
          expiry = last;
        }
      }
    }

    String? valueAfter(RegExp label) {
      for (var i = 0; i < lines.length; i++) {
        final m = label.firstMatch(lines[i]);
        if (m == null) continue;
        final rest = lines[i].substring(m.end).trim();
        if (rest.isNotEmpty) return rest;
        if (i + 1 < lines.length) return lines[i + 1];
      }
      return null;
    }

    // "DL D1234567", "LIC# 12345678", "DLN: A123-456-789". The number must
    // contain a digit, so the "DRIVER LICENSE" header never matches. When the
    // label is misread (e.g. "DL" → "UN"), fall back to the common
    // letter + 7–8 digits format (CA, FL, IL, …).
    // Indian: state code, RTO, year, serial, often with spaces or dashes
    // ("TS09 20190001234", "AP028 2015 0012345", "KA01 2015 0001234").
    final indian = RegExp(
      r'\b([A-Z]{2})[\s-]?(\d{2,3})[\s-]?((?:19|20)\d{2})[\s-]?(\d{7})\b',
    ).firstMatch(upper);
    final number = indian != null
        ? indian.groups([1, 2, 3, 4]).join()
        : RegExp(
                r'\b(?:DLN|DL|LIC(?:ENSE)?)\b\s*(?:NO\.?\s*[:.]?|#|:)?\s*([A-Z0-9-]*\d[A-Z0-9-]{3,})',
              ).firstMatch(upper)?.group(1) ??
              RegExp(r'\b([A-Z]\d{7,8})\b').firstMatch(upper)?.group(1);

    // Longest names first: "WEST VIRGINIA" before "VIRGINIA",
    // "ARKANSAS" before "KANSAS".
    String? state;
    final names = _states.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      if (RegExp('\\b$name\\b').hasMatch(upper)) {
        state = _states[name];
        break;
      }
    }

    var lastName = nameIn(valueAfter(RegExp(r'(?:^|\s)(?:1\s+)?LN\b[\s:.]*')));
    var firstName = nameIn(valueAfter(RegExp(r'(?:^|\s)(?:2\s+)?FN\b[\s:.]*')));
    // Indian licenses: one "Name: KIRAN KUMAR" field; the last word is the
    // last name. (Not "Son/Daughter/Wife of", which comes after it.)
    if (firstName == null && lastName == null) {
      final full = nameIn(valueAfter(RegExp(r'(?:^|\s)NAME\b[\s:.]*')));
      final words = full?.split(' ') ?? const <String>[];
      if (words.length >= 2) {
        firstName = words.sublist(0, words.length - 1).join(' ');
        lastName = words.last;
      } else if (words.length == 1) {
        firstName = words.single;
      }
    }

    return LicenseDetails(
      source: LicenseReadSource.text,
      lastName: _name(lastName),
      firstName: _name(firstName),
      licenseNumber: (number != null && RegExp(r'\d').hasMatch(number))
          ? number.replaceAll(RegExp(r'[^A-Z0-9]'), '')
          : null,
      expiryDate: expiry,
      birthDate: birth,
      state: state,
    );
  }

  /// Words printed next to the name on US licenses. OCR often joins the
  /// name with the next column ("FN: DRIVER EXPIRY DATE 01/15/2030"), so the
  /// name stops at the first of these or at any number.
  static const Set<String> _labelWords = {
    'LN',
    'FN',
    'DL',
    'DLN',
    'LIC',
    'LICENSE',
    'DRIVER\'S',
    'CLASS',
    'EXP',
    'EXPIRES',
    'EXPIRY',
    'DATE',
    'ISS',
    'ISSUED',
    'DOB',
    'SEX',
    'HGT',
    'HT',
    'WGT',
    'WT',
    'EYES',
    'HAIR',
    'RSTR',
    'REST',
    'END',
    'DD',
    'DONOR',
    'VETERAN',
    'SAMPLE\'S',
    'USA',
    'ADDRESS',
    'SON',
    'DAUGHTER',
    'WIFE',
    'S/O',
    'D/O',
    'W/O',
    'S/D/W',
    'OF',
  };

  /// The leading name part of a label value, or `null` if there is none.
  static String? nameIn(String? value) {
    if (value == null) return null;
    final words = <String>[];
    for (final raw in value.split(RegExp(r'\s+'))) {
      final word = raw.replaceAll(RegExp(r'[,;:]+$'), '');
      if (word.isEmpty) continue;
      if (_labelWords.contains(word) || RegExp(r'\d').hasMatch(word)) break;
      if (!RegExp(r"^[A-Z][A-Z'.-]*$").hasMatch(word)) break;
      words.add(word);
    }
    return words.isEmpty ? null : words.join(' ');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static DateTime? _validDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2100) {
      return null;
    }
    final date = DateTime(y, m, d);
    return date.month == m ? date : null;
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty || t == 'NONE') ? null : t;
  }

  /// "MITCHELL" → "Mitchell", "MARY ANN" → "Mary Ann".
  static String? _name(String? v) {
    final t = _clean(v);
    if (t == null) return null;
    return t
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static const Map<String, String> _states = {
    'CALIFORNIA': 'CA',
    'NEW YORK': 'NY',
    'TEXAS': 'TX',
    'FLORIDA': 'FL',
    'WASHINGTON': 'WA',
    'ILLINOIS': 'IL',
    'PENNSYLVANIA': 'PA',
    'OHIO': 'OH',
    'GEORGIA': 'GA',
    'NORTH CAROLINA': 'NC',
    'MICHIGAN': 'MI',
    'NEW JERSEY': 'NJ',
    'VIRGINIA': 'VA',
    'ARIZONA': 'AZ',
    'MASSACHUSETTS': 'MA',
    'TENNESSEE': 'TN',
    'INDIANA': 'IN',
    'MISSOURI': 'MO',
    'MARYLAND': 'MD',
    'WISCONSIN': 'WI',
    'COLORADO': 'CO',
    'MINNESOTA': 'MN',
    'OREGON': 'OR',
    'NEVADA': 'NV',
    'UTAH': 'UT',
    'IOWA': 'IA',
    'KANSAS': 'KS',
    'ARKANSAS': 'AR',
    'KENTUCKY': 'KY',
    'LOUISIANA': 'LA',
    'ALABAMA': 'AL',
    'SOUTH CAROLINA': 'SC',
    'OKLAHOMA': 'OK',
    'CONNECTICUT': 'CT',
    'MISSISSIPPI': 'MS',
    'NEW MEXICO': 'NM',
    'NEBRASKA': 'NE',
    'IDAHO': 'ID',
    'HAWAII': 'HI',
    'NEW HAMPSHIRE': 'NH',
    'MAINE': 'ME',
    'MONTANA': 'MT',
    'RHODE ISLAND': 'RI',
    'DELAWARE': 'DE',
    'SOUTH DAKOTA': 'SD',
    'NORTH DAKOTA': 'ND',
    'ALASKA': 'AK',
    'VERMONT': 'VT',
    'WYOMING': 'WY',
    'WEST VIRGINIA': 'WV',
  };
}
