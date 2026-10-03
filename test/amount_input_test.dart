import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ember/amount_input.dart';
import 'package:ember/models.dart';

void main() {
  TextEditingValue value(String text, [int? caret]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );
  final f = TomanAmountFormatter(() => 'IRT');
  test('Groups English digits typed or pasted into toman fields', () {
    final result = f.formatEditUpdate(value(''), value('1500000'));
    expect(result.text, '1,500,000');
    expect(result.selection.extentOffset, 9);
    expect(parseCurrencyAmount(result.text, 'IRT'), 1500000);
    expect(f.formatEditUpdate(value(''), value('0000')).text, '0,000');
  });
  test('Rejects non-English digits, separators, and symbols in toman', () {
    for (final input in [
      '۱۲۰',
      '١٢٠',
      '12a',
      '12 0',
      '1,200',
      '۱٬۲۰۰',
      '12.50',
      '+120',
    ]) {
      expect(f.formatEditUpdate(value(''), value(input)).text, '');
      expect(f.formatEditUpdate(value('120'), value(input)).text, '120');
    }
  });
  test(
    'Caret follows insertion, selection replacement, and deletion in the middle',
    () {
      final insert = f.formatEditUpdate(
        value('12,345', 2),
        value('129,345', 3),
      );
      expect(insert.text, '129,345');
      expect(insert.selection.extentOffset, 3);
      final back = f.formatEditUpdate(value('1,234', 2), value('1234', 1));
      expect(back.text, '234');
      expect(back.selection.extentOffset, 0);
      final forward = f.formatEditUpdate(value('1,234', 1), value('1234', 1));
      expect(forward.text, '134');
      expect(forward.selection.extentOffset, 1);
      final selection = f.formatEditUpdate(
        value(''),
        const TextEditingValue(
          text: '1234567',
          selection: TextSelection(baseOffset: 1, extentOffset: 5),
        ),
      );
      expect(selection.text, '1,234,567');
      expect(
        selection.selection,
        const TextSelection(baseOffset: 1, extentOffset: 7),
      );
      expect(f.formatEditUpdate(value('1,234'), value('')).text, '');
    },
  );
  test(
    'Negative openings work; decimals are never silently converted to toman',
    () {
      final signed = TomanAmountFormatter(() => 'IRT', allowNegative: true);
      expect(
        signed.formatEditUpdate(value(''), value('-123456')).text,
        '-123,456',
      );
      expect(signed.formatEditUpdate(value(''), value('-')).text, '-');
      expect(f.formatEditUpdate(value('120'), value('120.50')).text, '120');
      expect(f.formatEditUpdate(value('120'), value('۱۲٫۵')).text, '120');
      expect(f.formatEditUpdate(value(''), value('-100')).text, '');
    },
  );
  test('Tracks changing currencies and accepts only ASCII amounts', () {
    var currency = 'USD';
    final dynamicFormatter = TomanAmountFormatter(() => currency);
    expect(
      dynamicFormatter.formatEditUpdate(value(''), value('1234.56')).text,
      '1234.56',
    );
    for (final input in [
      '۱۲',
      '١٢',
      '12a',
      '12 0',
      '1,200',
      '+12',
      '12.345',
      '12..3',
    ]) {
      expect(
        dynamicFormatter.formatEditUpdate(value(''), value(input)).text,
        '',
      );
    }
    expect(
      dynamicFormatter.formatEditUpdate(value(''), value('.50')).text,
      '.50',
    );
    expect(
      dynamicFormatter.formatEditUpdate(value(''), value('12.')).text,
      '12.',
    );
    currency = 'IRT';
    expect(
      dynamicFormatter.formatEditUpdate(value(''), value('1234')).text,
      '1,234',
    );
    const composing = TextEditingValue(
      text: '1234',
      composing: TextRange(start: 0, end: 4),
    );
    expect(f.formatEditUpdate(value(''), composing), composing);
    expect(
      f
          .formatEditUpdate(
            value(''),
            const TextEditingValue(
              text: '۱۲۳۴',
              composing: TextRange(start: 0, end: 4),
            ),
          )
          .text,
      '',
    );
  });
}
