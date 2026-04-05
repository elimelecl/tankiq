import 'package:intl/intl.dart';

class NumberUtils {
  /// Formats a number with thousands separators and limited decimal places.
  /// Handles both numeric and formatted string inputs.
  static String format(dynamic value, {int decimalDigits = 2}) {
    if (value == null) return '---';
    
    num number;
    if (value is num) {
      number = value;
    } else if (value is String) {
      // Remove commas before parsing to handle formatted strings from API
      String cleaned = value.replaceAll(',', '');
      number = num.tryParse(cleaned) ?? 0;
    } else {
      return '---';
    }

    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: decimalDigits,
    );
    
    return formatter.format(number).trim();
  }

  /// Safely converts a dynamic value (String or num) to a double.
  static double toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      String cleaned = value.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
}
