import 'package:flutter/services.dart';

import '../providers/auth_flow_provider.dart';

/// Formats a US mobile number as the user types: "+1  (415) 555-0142".
///
/// Keeps at most 10 national digits. Deleting a formatting character removes
/// the digit before it so backspace never gets stuck.
class UsPhoneNumberFormatter extends TextInputFormatter {
  const UsPhoneNumberFormatter();

  static const String countryPrefix = '+1  ';

  /// National digits contained in a formatted [text].
  static String digitsOf(String text) {
    final national = text.startsWith('+1')
        ? text.substring(2)
        : text.replaceFirst(RegExp(r'^\+'), '');
    final digits = national.replaceAll(RegExp(r'\D'), '');
    return digits.length > AuthFlowProvider.phoneLength
        ? digits.substring(0, AuthFlowProvider.phoneLength)
        : digits;
  }

  /// Formatted text for [digits]; empty when there are none.
  static String format(String digits) => digits.isEmpty
      ? ''
      : '$countryPrefix${AuthFlowProvider.formatNationalPhone(digits)}';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldDigits = digitsOf(oldValue.text);
    var digits = digitsOf(newValue.text);

    final deletedFormattingOnly =
        newValue.text.length < oldValue.text.length && digits == oldDigits;
    if (deletedFormattingOnly && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    final text = format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
