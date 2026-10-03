import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ember/models.dart';
import 'package:ember/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Fresh install opens demo without cloud configuration',
    () async {
      final requests = <http.Request>[];
      final store = LedgerStore(
        await SharedPreferences.getInstance(),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 500);
        }),
      );
      addTearDown(store.dispose);
      await store.initialize();
      expect(store.url, isEmpty);
      expect(store.key, isEmpty);
      expect(store.connected, isFalse);
      expect(store.accounts, isNotEmpty);
      expect(store.entries, isNotEmpty);
      expect(requests, isEmpty);
    },
  );
  test(
    'Cloud sign-in isolates demo records and sends owned, idempotent writes',
    () async {
      final requests = <http.Request>[];
      final store = LedgerStore(
        await SharedPreferences.getInstance(),
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path.contains('/auth/')) {
            return http.Response(
              jsonEncode({
                'access_token': 'access',
                'refresh_token': 'refresh',
                'expires_in': 3600,
                'user': {'id': 'owner', 'email': 'person@example.com'},
              }),
              200,
            );
          }
          if (r.url.path.endsWith('read_ledger')) {
            return http.Response('{"accounts":[],"entries":[]}', 200);
          }
          return http.Response('[]', 201);
        }),
      );
      store.loadDemo();
      expect(store.entries, isNotEmpty);
      await store.configure(
        'https://example.supabase.co',
        'sb_publishable_example',
      );
      await store.signIn('person@example.com', 'not-a-real-password');
      expect(store.entries, isEmpty);
      expect(store.accounts, isEmpty);
      await store.addAccount(
        const Account(id: 'a', name: 'Bank', kind: 'Bank', opening: 0),
      );
      final write = requests.firstWhere(
        (r) => r.url.path.endsWith('/accounts'),
      );
      expect(jsonDecode(write.body)['user_id'], 'owner');
      expect(write.headers['Authorization'], 'Bearer access');
      expect(write.headers['Prefer'], contains('resolution=ignore-duplicates'));
      expect(requests.where((r) => r.url.path.endsWith('/entries')), isEmpty);
      store.dispose();
    },
  );
  test(
    'Cloud failure retains displayed records and exposes sync error',
    () async {
      final store = LedgerStore(
        await SharedPreferences.getInstance(),
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      store.loadDemo();
      final count = store.entries.length;
      store.url = 'https://example.supabase.co';
      store.key = 'public';
      store.userId = 'owner';
      store.access = 'access';
      store.expires = DateTime.now().add(const Duration(hours: 1));
      await store.reload();
      expect(store.entries.length, count);
      expect(store.syncError, isNotNull);
      expect(store.syncing, isFalse);
      store.dispose();
    },
  );
  test(
    'Cannot transfer to the same account or delete an account with entries',
    () async {
      final store = LedgerStore(await SharedPreferences.getInstance());
      store.loadDemo();
      await expectLater(
        store.addEntry(
          Entry(
            id: 'x',
            title: 'Transfer',
            type: 'transfer',
            category: 'Transfer',
            accountId: 'bank',
            destinationId: 'bank',
            amount: 10,
            date: DateTime.now(),
          ),
        ),
        throwsException,
      );
      await expectLater(store.removeAccount('bank'), throwsException);
      expect(store.busy, isFalse);
      store.dispose();
    },
  );
  test(
    'Demo accounts retain currency and reject cross-currency transfers',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = LedgerStore(prefs);
      await store.addAccount(
        const Account(
          id: 'usd',
          name: 'Dollars',
          kind: 'Bank',
          opening: 10000,
          currency: 'USD',
        ),
      );
      await store.addAccount(
        const Account(
          id: 'eur',
          name: 'Euros',
          kind: 'Bank',
          opening: 20000,
          currency: 'EUR',
        ),
      );
      await store.addEntry(
        Entry(
          id: 'expense',
          title: 'Coffee',
          type: 'expense',
          category: 'Food',
          accountId: 'usd',
          amount: 425,
          date: DateTime(2026),
        ),
      );
      await expectLater(
        store.addEntry(
          Entry(
            id: 'transfer',
            title: 'Invalid transfer',
            type: 'transfer',
            category: 'Transfer',
            accountId: 'usd',
            destinationId: 'eur',
            amount: 500,
            date: DateTime(2026),
          ),
        ),
        throwsException,
      );
      final restored = LedgerStore(prefs);
      restored.loadDemo();
      expect(restored.accounts.first.currency, 'USD');
      expect(balance(restored.accounts.first, restored.entries), 9575);
      expect(balance(restored.accounts.last, restored.entries), 20000);
      store.dispose();
      restored.dispose();
    },
  );
  test('Refuses secret keys and non-project URLs', () async {
    final store = LedgerStore(await SharedPreferences.getInstance());
    await expectLater(
      store.configure('https://example.supabase.co', 'sb_secret_private'),
      throwsException,
    );
    await expectLater(
      store.configure('http://example.supabase.co', 'sb_publishable_example'),
      throwsException,
    );
    await expectLater(
      store.configure(
        'https://example.supabase.co.evil.invalid',
        'sb_publishable_example',
      ),
      throwsException,
    );
    store.dispose();
  });
  test(
    'Recovery callback requires a new password before opening the ledger',
    () async {
      final requests = <http.Request>[];
      final store = LedgerStore(
        await SharedPreferences.getInstance(),
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' &&
              request.url.path.endsWith('/auth/v1/user')) {
            return http.Response(
              jsonEncode({'id': 'owner', 'email': 'person@example.com'}),
              200,
            );
          }
          if (request.method == 'PUT' &&
              request.url.path.endsWith('/auth/v1/user')) {
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('read_ledger')) {
            return http.Response('{"accounts":[],"entries":[]}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      await store.configure(
        'https://example.supabase.co',
        'sb_publishable_example',
      );
      await store.handleRecoveryCallback(
        Uri.parse(
          'https://app.example/#type=recovery&access_token=recovery-access&refresh_token=recovery-refresh&expires_in=3600',
        ),
      );
      expect(store.needsPasswordReset, isTrue);
      expect(store.connected, isFalse);
      await store.updatePassword('a-safe-new-password');
      expect(store.needsPasswordReset, isFalse);
      expect(store.connected, isTrue);
      final update = requests.firstWhere((r) => r.method == 'PUT');
      expect(update.headers['Authorization'], 'Bearer recovery-access');
      expect(jsonDecode(update.body)['password'], 'a-safe-new-password');
      store.dispose();
    },
  );
}
