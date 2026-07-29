import 'package:flutter/services.dart';

/// Auto-formats digits as the user types into Pakistani CNIC shape:
/// 12345-1234567-1 (5-7-1 digits). Matches the backend's exact validation
/// regex ^\d{5}-\d{7}-\d{1}$.
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '').substring(0, newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 13));
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 4 || i == 11) buffer.write('-');
    }
    final formatted = buffer.toString();
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

/// Auto-formats digits into Pakistani mobile shape: 0300-1234567 (4-7 digits).
/// Matches the backend's exact validation regex ^\d{4}-\d{7}$.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '').substring(0, newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 11));
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 3) buffer.write('-');
    }
    final formatted = buffer.toString();
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
