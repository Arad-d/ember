import 'package:flutter/services.dart';

/// Groups toman digits without rounding or changing the numeric value. The
/// currency callback follows the account/currency selected in the open form.
class TomanAmountFormatter extends TextInputFormatter {
  TomanAmountFormatter(this.currency, {this.allowNegative = false});
  final String Function() currency;
  final bool allowNegative;
  static final _separator = RegExp(',');
  static final _asciiDigits = RegExp(r'^[0-9]*$');
  static final _signedAsciiDigits = RegExp(r'^-?[0-9]*$');
  static final _decimalAmount = RegExp(r'^[0-9]*(\.[0-9]{0,2})?$');
  static final _signedDecimalAmount = RegExp(r'^-?[0-9]*(\.[0-9]{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (currency() != 'IRT') {
      final valid = allowNegative ? _signedDecimalAmount : _decimalAmount;
      return valid.hasMatch(newValue.text) ? newValue : oldValue;
    }
    // Commas are display-only. Reject pasted separators and non-English digits.
    if (!RegExp(r'^[-0-9,]*$').hasMatch(newValue.text) ||
        (!oldValue.text.contains(',') && newValue.text.contains(','))) {
      return oldValue;
    }
    final ungrouped = newValue.text.replaceAll(_separator, '');
    final valid = allowNegative ? _signedAsciiDigits : _asciiDigits;
    if (!valid.hasMatch(ungrouped)) return oldValue;
    if (!newValue.composing.isCollapsed) return newValue;
    var text = newValue.text;
    var base = newValue.selection.baseOffset;
    var extent = newValue.selection.extentOffset;
    // Backspace/delete beside a separator should remove the adjacent digit,
    // rather than reinsert the separator and trap the caret in place.
    if (oldValue.selection.isCollapsed &&
        newValue.selection.isCollapsed &&
        oldValue.text.length == newValue.text.length + 1 &&
        base >= 0 &&
        oldValue.text.replaceAll(_separator, '') ==
            text.replaceAll(_separator, '')) {
      final backwards = oldValue.selection.extentOffset > extent;
      final index = backwards ? extent - 1 : extent;
      if (index >= 0 &&
          index < text.length &&
          RegExp(r'[0-9]').hasMatch(text[index])) {
        text = text.replaceRange(index, index + 1, '');
        if (base > index) base--;
        if (extent > index) extent--;
      }
    }
    final raw = text.replaceAll(_separator, '');
    // In particular, never turn a pasted decimal into a different whole amount.
    if (!valid.hasMatch(raw)) return oldValue;
    final output = StringBuffer();
    final positions = <int>[0];
    for (var i = 0; i < raw.length; i++) {
      output.write(raw[i]);
      positions.add(output.length);
      final remaining = raw.length - i - 1;
      if (raw[i] != '-' && remaining > 0 && remaining % 3 == 0) {
        output.write(',');
      }
    }
    int caret(int offset) {
      if (offset < 0) return output.length;
      final count = text
          .substring(0, offset.clamp(0, text.length))
          .replaceAll(_separator, '')
          .length;
      return positions[count.clamp(0, positions.length - 1)];
    }

    return TextEditingValue(
      text: output.toString(),
      selection: TextSelection(
        baseOffset: caret(base),
        extentOffset: caret(extent),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
