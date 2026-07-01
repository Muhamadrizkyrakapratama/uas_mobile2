import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    // Clean all non-digits
    String cleanString = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanString.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    
    try {
      // Convert to double to format
      double value = double.parse(cleanString);
      
      // Format number with dots as thousands separators
      final formatter = NumberFormat.decimalPattern('id');
      String newText = formatter.format(value);
      
      return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } catch (e) {
      return newValue;
    }
  }
}
