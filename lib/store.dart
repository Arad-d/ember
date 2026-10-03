import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'browser_url.dart';
import 'models.dart';
import 'forecast.dart';

class LedgerStore extends ChangeNotifier {
  LedgerStore(this.prefs, {http.Client? client})
    : client = client ?? http.Client();
  final SharedPreferences prefs;
  final http.Client client;
  List<Account> accounts = [];
  List<Entry> entries = [];
  List<ExpenseReminder> reminders = [];
  List<ExpenseReminder> expectedIncome = [];
  Map<String, PlanSettings> planSettings = {};
  bool remindersAvailable = true;
  String url = '', key = '', email = '', userId = '', access = '', refresh = '';
  DateTime expires = DateTime(2000);
  DateTime? lastSync;
  bool busy = false, syncing = false, needsPasswordReset = false;
  String? syncError;
  Timer? timer;
  bool get connected => userId.isNotEmpty && !needsPasswordReset;
  String get newId => const Uuid().v4();
  Future<void> initialize() async {
    url =
        prefs.getString('url') ?? const String.fromEnvironment('SUPABASE_URL');
    key =
        prefs.getString('key') ??
        const String.fromEnvironment('SUPABASE_ANON_KEY');
    final session = prefs.getString('session');
    if (session != null) {
      try {
        _session(jsonDecode(session));
      } catch (_) {
        await prefs.remove('session');
      }
    }
    await handleRecoveryCallback(currentBrowserUri());
    if (connected) {
      await reload();
    } else {
      loadDemo();
    }
    timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (connected && !busy) reload();
    });
  }

  void loadDemo() {
    expectedIncome = [];
    planSettings = {};
    remindersAvailable = true;
    final saved = prefs.getString('demo');
    if (saved != null) {
      try {
        final j = jsonDecode(saved);
        accounts = (j['accounts'] as List)
            .map((a) => Account.fromJson(a))
            .toList();
        entries = (j['entries'] as List).map((e) => Entry.fromJson(e)).toList();
        reminders = (j['reminders'] as List? ?? [])
            .map((r) => ExpenseReminder.fromJson(r))
            .toList();
        _loadPlan(j);
        notifyListeners();
        return;
      } catch (_) {
        /* Recover only the disposable demo. */
      }
    }
    accounts = const [
      Account(
        id: 'bank',
        name: 'Everyday bank',
        kind: 'Bank',
        opening: 18500000,
      ),
      Account(
        id: 'savings',
        name: 'Savings',
        kind: 'Savings',
        opening: 62000000,
      ),
      Account(id: 'cash', name: 'Pocket cash', kind: 'Cash', opening: 1200000),
    ];
    final now = DateTime.now();
    expectedIncome = [
      ExpenseReminder(
        id: 'demo-payday',
        title: 'Next salary',
        category: 'Salary',
        accountId: 'bank',
        amount: 42000000,
        dueDate: DateTime(now.year, now.month + 1, 1),
      ),
    ];
    remindersAvailable = true;
    reminders = [
      ExpenseReminder(
        id: 'demo-loan',
        title: 'Loan payment',
        category: 'Bills',
        accountId: 'bank',
        amount: 2500000,
        dueDate: DateTime(now.year, now.month, now.day + 3),
        note: 'Monthly loan installment',
      ),
      ExpenseReminder(
        id: 'demo-internet',
        title: 'Internet bill',
        category: 'Bills',
        accountId: 'bank',
        amount: 350000,
        dueDate: DateTime(now.year, now.month, now.day - 1),
      ),
      ExpenseReminder(
        id: 'demo-rent',
        title: 'Next month’s rent',
        category: 'Home',
        accountId: 'bank',
        amount: 8000000,
        dueDate: DateTime(now.year, now.month + 1, 1),
      ),
    ];
    DateTime day(int d) => DateTime(now.year, now.month, d.clamp(1, now.day));
    entries = [
      Entry(
        id: '1',
        title: 'Monthly salary',
        type: 'income',
        category: 'Salary',
        accountId: 'bank',
        amount: 42000000,
        date: day(1),
      ),
      Entry(
        id: '2',
        title: 'Apartment rent',
        type: 'expense',
        category: 'Home',
        accountId: 'bank',
        amount: 12000000,
        date: day(2),
      ),
      Entry(
        id: '3',
        title: 'Weekly groceries',
        type: 'expense',
        category: 'Groceries',
        accountId: 'bank',
        amount: 1850000,
        date: day(4),
      ),
      Entry(
        id: '4',
        title: 'Internet & mobile',
        type: 'expense',
        category: 'Bills',
        accountId: 'bank',
        amount: 650000,
        date: day(5),
      ),
      Entry(
        id: '5',
        title: 'Design project',
        type: 'income',
        category: 'Freelance',
        accountId: 'bank',
        amount: 6500000,
        date: day(7),
      ),
      Entry(
        id: '6',
        title: 'Dinner with friends',
        type: 'expense',
        category: 'Food & drink',
        accountId: 'bank',
        amount: 780000,
        date: day(10),
      ),
      Entry(
        id: '7',
        title: 'Coffee stop',
        type: 'expense',
        category: 'Food & drink',
        accountId: 'cash',
        amount: 145000,
        date: day(now.day),
      ),
      Entry(
        id: '8',
        title: 'Ride home',
        type: 'expense',
        category: 'Transport',
        accountId: 'bank',
        amount: 92000,
        date: day(now.day),
      ),
      Entry(
        id: '9',
        title: 'Set aside for later',
        type: 'transfer',
        category: 'Transfer',
        accountId: 'bank',
        destinationId: 'savings',
        amount: 8000000,
        date: day(8),
      ),
    ];
    notifyListeners();
  }

  Future<void> _saveDemo() => prefs.setString(
    'demo',
    jsonEncode({
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'entries': entries.map((e) => e.toJson()).toList(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'expected_income': expectedIncome.map((r) => r.toJson()).toList(),
      'plan_settings': planSettings.entries
          .map((e) => {'currency': e.key, ...e.value.toJson()})
          .toList(),
    }),
  );
  void _session(Map<String, dynamic> j) {
    access = j['access_token'];
    refresh = j['refresh_token'];
    userId = j['user']['id'];
    email = j['user']['email'] ?? '';
    expires = DateTime.fromMillisecondsSinceEpoch(
      (j['expires_at'] as num).toInt() * 1000,
    );
  }

  /// Accepts Supabase's implicit-flow password-recovery callback on the web.
  /// The callback session is held only while a new password is chosen.
  Future<void> handleRecoveryCallback(Uri callback) async {
    final values = Uri.splitQueryString(callback.fragment);
    if (values['type'] != 'recovery') return;
    final recoveryAccess = values['access_token'];
    final recoveryRefresh = values['refresh_token'];
    if (recoveryAccess == null || recoveryRefresh == null) return;

    final response = await client
        .get(
          Uri.parse('$url/auth/v1/user'),
          headers: {'apikey': key, 'Authorization': 'Bearer $recoveryAccess'},
        )
        .timeout(const Duration(seconds: 20));
    final user = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || user['id'] == null) {
      throw Exception('This password-recovery link is invalid or has expired.');
    }
    final session = <String, dynamic>{
      'access_token': recoveryAccess,
      'refresh_token': recoveryRefresh,
      'expires_at':
          DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          (int.tryParse(values['expires_in'] ?? '') ?? 3600),
      'user': user,
    };
    _session(session);
    needsPasswordReset = true;
    await prefs.setString('session', jsonEncode(session));
    clearBrowserFragment();
    notifyListeners();
  }

  Future<void> updatePassword(String password) async {
    if (!needsPasswordReset || access.isEmpty) {
      throw Exception('Open a valid password-recovery link first.');
    }
    if (password.length < 8) {
      throw Exception('Use a password with at least 8 characters.');
    }
    final response = await client
        .put(
          Uri.parse('$url/auth/v1/user'),
          headers: {
            'apikey': key,
            'Authorization': 'Bearer $access',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(
        body['msg'] ?? body['error_description'] ?? 'Could not set password.',
      );
    }
    needsPasswordReset = false;
    await prefs.setString(
      'session',
      jsonEncode({
        'access_token': access,
        'refresh_token': refresh,
        'expires_at': expires.millisecondsSinceEpoch ~/ 1000,
        'user': {'id': userId, 'email': email},
      }),
    );
    await reload();
    notifyListeners();
  }

  Future<void> configure(String projectUrl, String publishableKey) async {
    final uri = Uri.tryParse(projectUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.host.endsWith('.supabase.co') ||
        uri.path.replaceAll('/', '').isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw Exception('Enter your HTTPS Supabase project URL.');
    }
    final k = publishableKey.trim();
    if (k.startsWith('sb_secret_')) {
      throw Exception('Use the publishable key, never a secret key.');
    }
    if (k.split('.').length == 3) {
      try {
        if (jsonDecode(
              utf8.decode(
                base64Url.decode(base64Url.normalize(k.split('.')[1])),
              ),
            )['role'] !=
            'anon') {
          throw const FormatException();
        }
      } catch (_) {
        throw Exception('Use a publishable key or legacy anon key.');
      }
    } else if (!k.startsWith('sb_publishable_')) {
      throw Exception('Enter a valid publishable key.');
    }
    url = 'https://${uri.host}';
    key = k;
    await prefs.setString('url', url);
    await prefs.setString('key', key);
  }

  Future<Map<String, dynamic>> _auth(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await client
        .post(
          Uri.parse('$url/auth/v1/$path'),
          headers: {'apikey': key, 'Content-Type': 'application/json'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        j['msg'] ??
            j['error_description'] ??
            'Sign-in failed. Check your email and password.',
      );
    }
    j['expires_at'] ??=
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        (j['expires_in'] as num? ?? 3600).toInt();
    return j;
  }

  Future<void> signIn(String mail, String password) async {
    final j = await _auth('token?grant_type=password', {
      'email': mail.trim(),
      'password': password,
    });
    _session(j);
    needsPasswordReset = false;
    await prefs.setString('session', jsonEncode(j));
    accounts = [];
    entries = [];
    reminders = [];
    expectedIncome = [];
    planSettings = {};
    await reload();
    notifyListeners();
  }

  Future<void> signOut() async {
    // Revoke the remote refresh token when possible; always clear this device.
    try {
      await client
          .post(
            Uri.parse('$url/auth/v1/logout'),
            headers: {'apikey': key, 'Authorization': 'Bearer $access'},
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    userId = '';
    access = '';
    refresh = '';
    email = '';
    lastSync = null;
    syncError = null;
    needsPasswordReset = false;
    await prefs.remove('session');
    loadDemo();
  }

  Future<void> _refresh() async {
    if (DateTime.now().isBefore(expires.subtract(const Duration(minutes: 1)))) {
      return;
    }
    final j = await _auth('token?grant_type=refresh_token', {
      'refresh_token': refresh,
    });
    _session(j);
    await prefs.setString('session', jsonEncode(j));
  }

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    await _refresh();
    final r = http.Request(method, Uri.parse('$url/rest/v1/$path'));
    r.headers.addAll({
      'apikey': key,
      'Authorization': 'Bearer $access',
      'Content-Type': 'application/json',
      'Prefer': method == 'POST' && (path == 'entries' || path == 'accounts')
          ? 'resolution=ignore-duplicates,return=representation'
          : 'return=representation',
    });
    if (body != null) r.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(r).timeout(const Duration(seconds: 20)),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode >= 400) {
      if (response.statusCode == 401) {
        throw Exception('Your session expired. Sign out and sign in again.');
      }
      if (response.statusCode == 404) {
        throw Exception(
          'Database setup is missing. Run the included schema.sql in Supabase.',
        );
      }
      throw Exception(
        'Could not save or load your records. Check your connection and database setup.',
      );
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<void> reload() async {
    if (!connected || syncing || busy) return;
    syncing = true;
    notifyListeners();
    final owner = userId;
    try {
      final data = await _request('POST', 'rpc/read_ledger', {});
      if (userId != owner) return;
      accounts = (data['accounts'] as List)
          .map((a) => Account.fromJson(a))
          .toList();
      entries = (data['entries'] as List)
          .map((e) => Entry.fromJson(e))
          .toList();
      lastSync = DateTime.now();
      remindersAvailable = data.containsKey('reminders');
      reminders = (data['reminders'] as List? ?? [])
          .map((r) => ExpenseReminder.fromJson(r))
          .toList();
      syncError = null;
      _loadPlan(data);
    } catch (_) {
      if (userId == owner) {
        syncError = 'Couldn’t sync. Check your connection or database setup.';
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    if (busy || syncing) {
      throw Exception('Please wait for the current sync to finish.');
    }
    busy = true;
    notifyListeners();
    try {
      await action();
      if (!connected) await _saveDemo();
    } finally {
      busy = false;
      notifyListeners();
    }
    if (connected) await reload();
  }

  Future<void> addAccount(Account a) => _mutate(() async {
    if (connected) {
      await _request('POST', 'accounts', {...a.toJson(), 'user_id': userId});
    } else {
      accounts = [...accounts, a];
    }
  });
  Future<void> addEntry(Entry e) => _mutate(() async {
    if (e.amount <= 0 || e.amount > 9000000000000) {
      throw Exception('Enter a positive amount in the account currency.');
    }
    if (!accounts.any((a) => a.id == e.accountId)) {
      throw Exception('Select an account.');
    }
    if (e.type == 'transfer' &&
        (e.accountId == e.destinationId ||
            !accounts.any((a) => a.id == e.destinationId))) {
      throw Exception('Choose two different accounts.');
    }
    if (e.type == 'transfer' &&
        accounts.firstWhere((a) => a.id == e.accountId).currency !=
            accounts.firstWhere((a) => a.id == e.destinationId).currency) {
      throw Exception('Transfers require accounts with the same currency.');
    }
    if (connected) {
      await _request('POST', 'entries', {...e.toJson(), 'user_id': userId});
    } else {
      entries = [...entries, e];
    }
  });
  Future<void> removeEntry(String id) => _mutate(() async {
    if (connected) {
      await _request('DELETE', 'entries?id=eq.$id&user_id=eq.$userId');
    } else {
      entries = entries.where((e) => e.id != id).toList();
    }
  });
  Future<void> removeAccount(String id) => _mutate(() async {
    if (expectedIncome.any((r) => r.accountId == id)) {
      throw Exception('This account has planned income. Remove it first.');
    }
    if (reminders.any((r) => r.accountId == id)) {
      throw Exception('This account has reminders. Remove those first.');
    }
    if (entries.any((e) => e.accountId == id || e.destinationId == id)) {
      throw Exception('This account has transactions. Remove those first.');
    }
    if (connected) {
      await _request('DELETE', 'accounts?id=eq.$id&user_id=eq.$userId');
    } else {
      accounts = accounts.where((a) => a.id != id).toList();
    }
  });
  @override
  void dispose() {
    timer?.cancel();
    client.close();
    super.dispose();
  }

  void _loadPlan(dynamic j) {
    expectedIncome = (j['expected_income'] as List? ?? [])
        .map((r) => ExpenseReminder.fromJson(r))
        .toList();
    planSettings = {
      for (final r in (j['plan_settings'] as List? ?? []))
        r['currency'] as String: PlanSettings.fromJson(r),
    };
  }

  Future<void> savePlanSettings(String currency, PlanSettings value) =>
      _mutate(() async {
        if (value.reserve < 0 || value.reserve > 9000000000000) {
          throw Exception('Enter a valid safety buffer.');
        }
        if (connected) {
          await _request('POST', 'rpc/save_plan_settings', {
            'payload': {'currency': currency, ...value.toJson()},
          });
        } else {
          planSettings[currency] = value;
        }
      });

  Future<void> saveExpectedIncome(ExpenseReminder r) => _mutate(() async {
    if (r.title.trim().isEmpty ||
        r.title.length > 120 ||
        r.amount <= 0 ||
        r.amount > 9000000000000 ||
        !accounts.any((a) => a.id == r.accountId)) {
      throw Exception('Enter a name, positive amount, and account.');
    }
    if (expectedIncome.any((i) => i.id == r.id && i.paid)) {
      throw Exception('Received income cannot be edited.');
    }
    if (connected) {
      await _request('POST', 'rpc/save_expected_income', {
        'payload': r.toJson(),
      });
    } else {
      expectedIncome = [...expectedIncome.where((i) => i.id != r.id), r];
    }
  });

  Future<void> removeExpectedIncome(String id) => _mutate(() async {
    if (connected) {
      await _request('DELETE', 'expected_income?id=eq.$id&user_id=eq.$userId');
    } else {
      expectedIncome = expectedIncome.where((i) => i.id != id).toList();
    }
  });

  Future<void> receiveIncome(String id, DateTime date) => _mutate(() async {
    if (calendarDay(date).isAfter(calendarDay(DateTime.now()))) {
      throw Exception('Choose today or an earlier date.');
    }
    final r = expectedIncome.firstWhere((i) => i.id == id);
    if (r.paid) return;
    if (connected) {
      await _request('POST', 'rpc/receive_expected_income', {
        'income_id': id,
        'receipt_date': date.toIso8601String().substring(0, 10),
      });
    } else {
      entries = [
        ...entries,
        Entry(
          id: r.id,
          title: r.title,
          type: 'income',
          category: r.category,
          accountId: r.accountId,
          amount: r.amount,
          date: date,
        ),
      ];
      expectedIncome = expectedIncome
          .map(
            (i) => i.id == id
                ? ExpenseReminder.fromJson({
                    ...r.toJson(),
                    'paid_date': date.toIso8601String(),
                  })
                : i,
          )
          .toList();
    }
  });

  Future<void> saveReminder(ExpenseReminder r) => _mutate(() async {
    if (!remindersAvailable) {
      throw Exception('Reminders are awaiting the workspace update.');
    }
    if (r.title.trim().isEmpty ||
        r.title.length > 120 ||
        r.note.length > 1000 ||
        r.amount <= 0 ||
        r.amount > 9000000000000 ||
        !accounts.any((a) => a.id == r.accountId)) {
      throw Exception(
        'Enter a name, positive amount, and account. Notes can contain up to 1,000 characters.',
      );
    }
    final existing = reminders.where((item) => item.id == r.id).firstOrNull;
    if (existing?.paid == true) {
      throw Exception('Paid reminders cannot be edited.');
    }
    if (connected) {
      await _request('POST', 'rpc/save_expense_reminder', {
        'payload': r.toJson(),
      });
    } else {
      reminders = [...reminders.where((item) => item.id != r.id), r];
    }
  });

  Future<void> removeReminder(String id) => _mutate(() async {
    if (connected) {
      await _request(
        'DELETE',
        'expense_reminders?id=eq.$id&user_id=eq.$userId',
      );
    } else {
      reminders = reminders.where((r) => r.id != id).toList();
    }
  });

  Future<void> payReminder(String id, DateTime date) => _mutate(() async {
    if (date.isAfter(DateTime.now())) {
      throw Exception('Choose today or an earlier payment date.');
    }
    final r = reminders.firstWhere((r) => r.id == id);
    if (r.paid) return;
    if (connected) {
      await _request('POST', 'rpc/pay_expense_reminder', {
        'reminder_id': id,
        'payment_date': date.toIso8601String().substring(0, 10),
      });
    } else {
      entries = [
        ...entries,
        Entry(
          id: r.id,
          title: r.title,
          type: 'expense',
          category: r.category,
          accountId: r.accountId,
          amount: r.amount,
          date: date,
        ),
      ];
      reminders = reminders
          .map(
            (item) => item.id == id
                ? ExpenseReminder.fromJson({
                    ...r.toJson(),
                    'paid_date': date.toIso8601String(),
                  })
                : item,
          )
          .toList();
    }
  });
}
