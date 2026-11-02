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

  static final _date = RegExp(r'(\d{2})[/\-.](\d{2})[/\-.](\d{4})');

  /// Best-effort parse of the printed front of a US license.
  static LicenseDetails parseFrontText(String text) {
    final upper = text.toUpperCase();
    final lines = upper
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    DateTime? dateAfter(List<String> labels) {
      for (var i = 0; i < lines.length; i++) {
        if (!labels.any(lines[i].contains)) continue;
        // Same line, or the next one (label above value).
        for (final line in [lines[i], if (i + 1 < lines.length) lines[i + 1]]) {
          final m = _date.firstMatch(line);
          if (m != null) {
            final date = _validDate(
              int.parse(m.group(3)!),
              int.parse(m.group(1)!),
              int.parse(m.group(2)!),
            );
            if (date != null) return date;
          }
        }
      }
      return null;
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
    // contain a digit, so the "DRIVER LICENSE" header never matches.
    final number = RegExp(
      r'\b(?:DLN|DL|LIC(?:ENSE)?)\b\s*(?:NO\.?|#|:)?\s*([A-Z0-9-]*\d[A-Z0-9-]{3,})',
    ).firstMatch(upper)?.group(1);

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

    return LicenseDetails(
      source: LicenseReadSource.text,
      lastName: _name(valueAfter(RegExp(r'^(1\s+)?LN\b[\s:]*'))),
      firstName: _name(valueAfter(RegExp(r'^(2\s+)?FN\b[\s:]*'))),
      licenseNumber: (number != null && RegExp(r'\d').hasMatch(number))
          ? number.replaceAll(RegExp(r'[^A-Z0-9]'), '')
          : null,
      expiryDate: dateAfter(const ['EXP']),
      birthDate: dateAfter(const ['DOB', 'BIRTH']),
      state: state,
    );
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
