import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/store.dart';
import 'package:ember/models.dart';
import 'package:ember/savings_goal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LedgerStore s;
  SavingsGoal goal({
    String id = 'g',
    String account = 's',
    String currency = 'IRT',
    int target = 300,
    DateTime? date,
  }) => SavingsGoal(
    id: id,
    name: 'Laptop',
    target: target,
    currency: currency,
    deadline: date ?? DateTime.now().add(const Duration(days: 60)),
    accountId: account,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = LedgerStore(await SharedPreferences.getInstance());
    s.accounts = [
      const Account(id: 's', name: 'Savings', kind: 'Savings', opening: 120),
      const Account(id: 'b', name: 'Bank', kind: 'Bank', opening: 100),
    ];
  });
  tearDown(() => s.dispose());
  test('goals persist and removal preserves accounts', () async {
    await s.saveSavingsGoal(goal());
    final restored = LedgerStore(s.prefs)..loadDemo();
    expect(restored.savingsGoals.single.name, 'Laptop');
    await s.removeSavingsGoal('g');
    expect(s.savingsGoals, isEmpty);
    expect(s.accounts, hasLength(2));
    restored.dispose();
  });
  test('old local ledger loads without goals', () async {
    await s.prefs.setString(
      'demo',
      jsonEncode({
        'accounts': s.accounts.map((a) => a.toJson()).toList(),
        'entries': [],
      }),
    );
    s.loadDemo();
    expect(s.savingsGoals, isEmpty);
    expect(s.savingsGoalsAvailable, true);
  });
  test('invalid and duplicate links do not mutate state', () async {
    for (final g in [
      goal(target: 0),
      goal(account: 'b'),
      goal(currency: 'USD'),
      goal(date: DateTime.now().subtract(const Duration(days: 2))),
    ]) {
      await expectLater(s.saveSavingsGoal(g), throwsException);
    }
    expect(s.savingsGoals, isEmpty);
    await s.saveSavingsGoal(goal());
    await expectLater(s.saveSavingsGoal(goal(id: 'g2')), throwsException);
    await expectLater(s.removeAccount('s'), throwsException);
    expect(s.savingsGoals, hasLength(1));
  });
  test('overdue goal can be edited with same deadline', () async {
    final date = DateTime.now().subtract(const Duration(days: 2));
    s.savingsGoals = [goal(date: date)];
    await s.saveSavingsGoal(goal(date: date, target: 500));
    expect(s.savingsGoals.single.target, 500);
  });
  test('loading demo clears prior workspace goals', () {
    s.savingsGoals = [goal()];
    s.loadDemo();
    expect(s.savingsGoals, isEmpty);
  });
  test('cloud setup absence and failed writes preserve records', () async {
    final cloud = LedgerStore(
      s.prefs,
      client: MockClient((r) async {
        if (r.url.path.endsWith('read_ledger')) {
          return http.Response(
            jsonEncode({
              'accounts': s.accounts.map((a) => a.toJson()).toList(),
              'entries': [],
            }),
            200,
          );
        }
        return http.Response('{"message":"Unavailable"}', 503);
      }),
    );
    cloud.url = 'https://example.supabase.co';
    cloud.userId = 'owner';
    cloud.access = 'access';
    cloud.expires = DateTime.now().add(const Duration(hours: 1));
    await cloud.reload();
    expect(cloud.savingsGoalsAvailable, false);
    expect(cloud.accounts, hasLength(2));
    await expectLater(cloud.saveSavingsGoal(goal()), throwsException);
    cloud.savingsGoalsAvailable = true;
    cloud.savingsGoals = [goal()];
    await expectLater(
      cloud.saveSavingsGoal(goal(target: 500)),
      throwsException,
    );
    expect(cloud.savingsGoals.single.target, 300);
    await cloud.signOut();
    expect(cloud.savingsGoals, isEmpty);
    cloud.dispose();
  });
}
