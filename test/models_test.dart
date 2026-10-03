import 'package:flutter_test/flutter_test.dart';
import 'package:ember/models.dart';

void main() {
  test('Parses Persian and Arabic digits, rejects fractional money', () {
    expect(parseAmount('۱٬۲۵۰٬۰۰۰'), 1250000);
    expect(parseAmount('١٢٣'), 123);
    expect(parseAmount('1,200'), 1200);
    expect(parseAmount('1.5'), isNull);
    expect(parseAmount('NaN'), isNull);
    expect(parseAmount('9000000000001'), isNull);
  });
  test('Foreign amounts use exact minor units and preserve legacy toman', () {
    for (final code in ['USD', 'EUR', 'GBP']) {
      expect(parseCurrencyAmount('1,234.56', code), 123456);
      expect(parseCurrencyAmount('۰٫۲۹', code), 29);
      expect(parseCurrencyAmount('-12.5', code), -1250);
      expect(parseCurrencyAmount('1.234', code), isNull);
      expect(currencyMoney(123456, code), '1,234.56');
      final account = Account(
        id: 'usd',
        name: 'Savings',
        kind: 'Bank',
        opening: 10000,
        currency: code,
      );
      expect(Account.fromJson(account.toJson()).currency, code);
      final entries = [
        Entry(
          id: 'in',
          title: 'Pay',
          type: 'income',
          category: 'Salary',
          accountId: 'usd',
          amount: 1050,
          date: DateTime(2026),
        ),
        Entry(
          id: 'out',
          title: 'Coffee',
          type: 'expense',
          category: 'Food',
          accountId: 'usd',
          amount: 425,
          date: DateTime(2026),
        ),
      ];
      expect(currencyMoney(balance(account, entries), code), '106.25');
    }
    expect(
      Account.fromJson({
        'id': 'old',
        'name': 'Bank',
        'kind': 'Bank',
        'opening': 123,
      }).currency,
      'IRT',
    );
    expect(parseCurrencyAmount('123', 'IRT'), 123);
    expect(parseCurrencyAmount('1.25', 'IRT'), isNull);
  });
  test(
    'Transfers preserve combined balance and do not count as income or spending',
    () {
      const bank = Account(id: 'a', name: 'Bank', kind: 'Bank', opening: 1000);
      const cash = Account(id: 'b', name: 'Cash', kind: 'Cash', opening: 100);
      final entries = [
        Entry(
          id: '1',
          title: 'Cash',
          type: 'transfer',
          category: 'Transfer',
          accountId: 'a',
          destinationId: 'b',
          amount: 300,
          date: DateTime(2026),
        ),
        Entry(
          id: '2',
          title: 'Pay',
          type: 'income',
          category: 'Salary',
          accountId: 'a',
          amount: 500,
          date: DateTime(2026),
        ),
        Entry(
          id: '3',
          title: 'Coffee',
          type: 'expense',
          category: 'Food & drink',
          accountId: 'b',
          amount: 50,
          date: DateTime(2026),
        ),
      ];
      expect(balance(bank, entries), 1200);
      expect(balance(cash, entries), 350);
      expect(totalOf(entries, 'income'), 500);
      expect(totalOf(entries, 'expense'), 50);
      expect(balance(bank, entries) + balance(cash, entries), 1550);
    },
  );
}
